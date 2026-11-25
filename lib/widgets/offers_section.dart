import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import '../services/offers_change_notifier.dart';
import '../utils/permissions.dart';
import 'product_image_widget.dart';
import '../screens/new_order_screen.dart';
import '../screens/product_detail_screen.dart';

class OffersSection extends StatefulWidget {
  const OffersSection(
      {super.key, required this.session, required this.role, this.loadOffers});

  final Map<String, dynamic> session;
  final AppRole role;
  final Future<Map<String, dynamic>> Function()? loadOffers;

  @override
  State<OffersSection> createState() => _OffersSectionState();
}

class _OffersSectionState extends State<OffersSection>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  bool _stale = false;
  String? _error;
  Future<void>? _request;
  Timer? _timer;
  Timer? _expiryTimer;
  bool _refreshPending = false;
  DateTime? _serverTime;
  final Stopwatch _elapsed = Stopwatch();

  String? get _cacheKey {
    final id = (widget.session['user_id'] ??
            widget.session['id'] ??
            widget.session['customer_id'])
        ?.toString()
        .trim();
    if (id == null || id.isEmpty) return null;
    final scope = jsonEncode(
        [AppConfig.environmentName, AppConfig.apiUrl, id, widget.role.name]);
    return 'offers.v1.${sha256.convert(utf8.encode(scope))}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_canView) {
      offersRevision.addListener(_offerChanged);
      _refresh();
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
    }
  }

  bool get _canView => PermissionHelper.hasAnyPermission(widget.role, {
        AppPermission.viewProductPrices,
        AppPermission.viewSellingPriceOnly,
      });

  bool get _canOrder =>
      PermissionHelper.hasPermission(widget.role, AppPermission.createOrder);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_canView) offersRevision.removeListener(_offerChanged);
    _timer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_canView && state == AppLifecycleState.resumed) _refresh();
  }

  void _offerChanged() {
    if (_request != null) {
      _refreshPending = true;
    } else {
      _refresh();
    }
  }

  Future<void> _refresh() {
    if (_request != null) return _request!;
    final request = _load();
    _request = request;
    return request.whenComplete(() {
      if (identical(_request, request)) _request = null;
      if (_refreshPending && mounted) {
        _refreshPending = false;
        _refresh();
      }
    });
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final serverTime = _serverTime;
    if (_stale || serverTime == null) return;
    final now = serverTime.add(_elapsed.elapsed);
    final remaining = _offers
        .map((offer) => DateTime.parse('${offer['ends_at']}').difference(now))
        .where((duration) => duration > Duration.zero)
        .toList()
      ..sort();
    if (remaining.isEmpty) return;
    _expiryTimer = Timer(remaining.first, () {
      if (!mounted) return;
      setState(() {});
      _scheduleExpiry();
    });
  }

  List<Map<String, dynamic>> _parse(dynamic raw) {
    if (raw is! List) throw const FormatException('قائمة العروض غير صالحة');
    return raw.map((entry) {
      if (entry is! Map) {
        throw const FormatException('بيانات العرض غير صالحة');
      }
      final offer = Map<String, dynamic>.from(entry);
      final old = num.tryParse('${offer['old_price']}');
      final price = num.tryParse('${offer['offer_price']}');
      final quantity = num.tryParse('${offer['min_quantity']}');
      if ((offer['offer_id']?.toString().trim() ?? '').isEmpty ||
          (offer['product_code']?.toString().trim() ?? '').isEmpty ||
          (offer['unit']?.toString().trim() ?? '').isEmpty ||
          (offer['currency']?.toString().trim() ?? '').isEmpty ||
          old == null ||
          !old.isFinite ||
          old <= 0 ||
          price == null ||
          !price.isFinite ||
          price <= 0 ||
          price >= old ||
          quantity == null ||
          !quantity.isFinite ||
          quantity <= 0 ||
          DateTime.tryParse('${offer['ends_at']}') == null) {
        throw const FormatException('بيانات العرض غير صالحة');
      }
      return offer;
    }).toList();
  }

  Future<void> _load() async {
    final api = ApiService();
    final token = api.token;
    try {
      final response = await (widget.loadOffers?.call() ??
          api.post({'action': 'offer_list'}, useCache: false));
      final data = response['data'];
      final raw = response['offers'] ?? (data is Map ? data['offers'] : null);
      final time =
          response['server_time'] ?? (data is Map ? data['server_time'] : null);
      final serverTime = DateTime.tryParse('$time');
      if (serverTime == null) {
        throw const FormatException('وقت الخادم غير متوفر');
      }
      final offers = _parse(raw);
      if (!mounted || token != api.token) return;
      final key = _cacheKey;
      if (key != null) {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(key, jsonEncode(offers))) {
          throw StateError('تعذر حفظ العروض محليًا');
        }
      }
      if (!mounted || token != api.token) return;
      setState(() {
        _offers = offers;
        _serverTime = serverTime;
        _elapsed
          ..reset()
          ..start();
        _stale = false;
        _error = null;
      });
      _scheduleExpiry();
    } catch (error) {
      if (!mounted || token != api.token) return;
      if (error is ApiException && error.transportFailure) {
        try {
          final key = _cacheKey;
          final prefs = await SharedPreferences.getInstance();
          final cached = key == null ? null : prefs.getString(key);
          if (cached != null) {
            final offers = _parse(jsonDecode(cached));
            if (!mounted || token != api.token) return;
            setState(() {
              _offers = offers;
              _stale = true;
              _serverTime = null;
              _error = null;
            });
            _expiryTimer?.cancel();
            return;
          }
        } catch (cacheError) {
          debugPrint('Offers cache read failed: ${cacheError.runtimeType}');
        }
      }
      if (mounted && token == api.token) {
        setState(() {
          _offers = [];
          _error = error.toString();
        });
      }
    } finally {
      if (mounted && token == api.token) setState(() => _loading = false);
    }
  }

  void _openOffer(Product product, Map<String, dynamic> offer) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _canOrder
            ? NewOrderScreen(
                session: widget.session,
                initialProduct: product,
                initialOffer: offer,
              )
            : ProductDetailScreen(product: product, session: widget.session),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return const SizedBox.shrink();
    }
    final products = context.watch<ProductsProvider>().allProducts;
    final byCode = {for (final product in products) product.code: product};
    final now = _serverTime?.add(_elapsed.elapsed);
    final entries = _offers.where((offer) {
      final end = DateTime.parse('${offer['ends_at']}');
      return byCode.containsKey(offer['product_code']?.toString()) &&
          (_stale || now == null || now.isBefore(end));
    }).toList();
    if (!_loading && entries.isEmpty && _error == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
              child: Text('عروض وتخفيضات',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold))),
          if (entries.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('عروض وتخفيضات')),
                    body: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: entries.length + (_stale ? 1 : 0),
                      itemBuilder: (_, index) {
                        if (_stale && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                                'عروض محفوظة دون اتصال؛ يلزم التحقق من صلاحيتها وسعرها.'),
                          );
                        }
                        final offer = entries[index - (_stale ? 1 : 0)];
                        final product = byCode[offer['product_code']]!;
                        return OfferCard(
                          offer: offer,
                          product: product,
                          actionLabel: _canOrder ? 'اطلب العرض' : 'عرض المنتج',
                          onOpen: () => _openOffer(product, offer),
                        );
                      },
                    ),
                  ),
                ),
              ),
              child: const Text('عرض الكل'),
            ),
        ]),
        if (_stale)
          const Text('عروض محفوظة دون اتصال؛ يلزم التحقق من صلاحيتها وسعرها.')
        else if (_error != null)
          Row(children: [
            const Expanded(child: Text('تعذر تحميل العروض.')),
            TextButton(
                onPressed: _refresh, child: const Text('إعادة المحاولة')),
          ]),
        if (_loading && entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (entries.isNotEmpty)
          SizedBox(
            height: (390 * MediaQuery.textScalerOf(context).scale(1))
                .clamp(390.0, 650.0),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final offer = entries[index];
                final product = byCode[offer['product_code']]!;
                return SizedBox(
                  width:
                      MediaQuery.sizeOf(context).width.clamp(250.0, 320.0) - 32,
                  child: OfferCard(
                    offer: offer,
                    product: product,
                    actionLabel: _canOrder ? 'اطلب العرض' : 'عرض المنتج',
                    onOpen: () => _openOffer(product, offer),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class OfferCard extends StatelessWidget {
  const OfferCard(
      {super.key,
      required this.offer,
      required this.product,
      required this.onOpen,
      this.actionLabel = 'عرض المنتج'});
  final Map<String, dynamic> offer;
  final Product product;
  final VoidCallback onOpen;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final old = num.parse('${offer['old_price']}');
    final price = num.parse('${offer['offer_price']}');
    final discount = (100 * (old - price) / old).toStringAsFixed(1);
    final end = DateTime.parse('${offer['ends_at']}').toLocal();
    final note = (offer['note'] ?? '').toString().trim();
    final title = (offer['title'] ?? '').toString().trim();
    final currency = offer['currency'].toString();
    final colors = Theme.of(context).colorScheme;
    final bundleItems = offer['bundle_items'];
    final isBundle = bundleItems is List && bundleItems.length > 1;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 144,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: colors.surfaceContainerHighest.withValues(alpha: .5),
                    child: Center(
                      child: ProductImageWidget(
                        imageUrl: product.imageUrl,
                        height: 124,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: _OfferBadge(
                      icon: Icons.percent_rounded,
                      label: 'خصم $discount%',
                      background: colors.errorContainer,
                      foreground: colors.onErrorContainer,
                    ),
                  ),
                  PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: _OfferBadge(
                      icon: Icons.local_offer_outlined,
                      label: 'لفترة محدودة',
                      background: colors.primaryContainer,
                      foreground: colors.onPrimaryContainer,
                    ),
                  ),
                  if (isBundle)
                    PositionedDirectional(
                      bottom: 10,
                      end: 10,
                      child: _OfferBadge(
                        icon: Icons.inventory_2_outlined,
                        label: 'عرض مجموعة',
                        background: colors.tertiaryContainer,
                        foreground: colors.onTertiaryContainer,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title.isNotEmpty) ...[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    product.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    softWrap: true,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _InfoChip(
                        icon: Icons.qr_code_rounded,
                        label: 'الرمز: ${product.code}',
                      ),
                      _InfoChip(
                        icon: Icons.shopping_basket_outlined,
                        label:
                            'عند طلب ${offer['min_quantity']} ${offer['unit']} أو أكثر',
                      ),
                      if ((product.brand ?? '').trim().isNotEmpty)
                        _InfoChip(
                          icon: Icons.sell_outlined,
                          label: product.brand!.trim(),
                        ),
                      if (product.origin.trim().isNotEmpty)
                        _InfoChip(
                          icon: Icons.public_outlined,
                          label: product.origin.trim(),
                        ),
                      if (product.oem.trim().isNotEmpty)
                        _InfoChip(
                          icon: Icons.tag_outlined,
                          label: product.oem.trim(),
                        ),
                    ],
                  ),
                  if (isBundle) ...[
                    const SizedBox(height: 10),
                    Text(
                      'محتويات العرض',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    for (final item in bundleItems.whereType<Map>())
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 18, color: colors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${item['quantity'] ?? ''} × ${item['product_name'] ?? item['name'] ?? item['product_code'] ?? ''}'
                                '${(item['unit'] ?? '').toString().trim().isEmpty ? '' : ' ${item['unit']}'}\n'
                                '${item['old_price'] ?? '—'} $currency ← ${item['offer_price'] ?? '—'} $currency / قطعة',
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(note, softWrap: true),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          '$price $currency',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '$old $currency',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.error,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isBundle
                        ? 'سعر المجموعة'
                        : 'سعر العرض: $price $currency للوحدة',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ينتهي: ${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')} ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: Text(
                      isBundle ? 'اطلب الحزمة' : actionLabel,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferBadge extends StatelessWidget {
  const _OfferBadge({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.onSecondaryContainer),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

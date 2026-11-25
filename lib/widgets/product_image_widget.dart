import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ProductImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;
  final String? heroTag;

  const ProductImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.placeholderIcon = Icons.inventory_2_outlined,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    Widget image;

    if (url.isEmpty) {
      image = _placeholder(context);
    } else if (kIsWeb) {
      // Google Drive لا يضمن CORS؛ استخدم عنصر صورة HTML كخيار احتياطي للويب.
      image = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        alignment: Alignment.center,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _placeholder(context, loading: true),
        errorBuilder: (context, error, stackTrace) =>
            _placeholder(context, isError: true),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        alignment: Alignment.center,
        placeholder: (context, url) => _placeholder(context, loading: true),
        errorWidget: (context, url, error) =>
            _placeholder(context, isError: true),
      );
    }

    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }

  Widget _placeholder(
    BuildContext context, {
    bool loading = false,
    bool isError = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: borderRadius,
      ),
      child: loading
          ? Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colors.primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          : Icon(
              isError ? Icons.broken_image_outlined : placeholderIcon,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
              size: width != null && width! < 50 ? 20 : 32,
            ),
    );
  }
}

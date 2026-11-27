import '../models/product.dart';

class SmartProductSearchIndex {
  final List<_IndexedProduct> _products;

  SmartProductSearchIndex(Iterable<Product> products)
      : _products = products.map(_IndexedProduct.new).toList(growable: false);

  List<Product> search(String query) {
    return searchWithRanks(query).map((match) => match.product).toList(
          growable: false,
        );
  }

  List<ProductSearchMatch> searchWithRanks(String query) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) {
      return _products
          .map((entry) => ProductSearchMatch(entry.product, 0))
          .toList(growable: false);
    }

    final queryTokens = normalizedQuery.split(' ');
    final matches = <({Product product, int rank, int sourceIndex})>[];
    for (var index = 0; index < _products.length; index++) {
      final entry = _products[index];
      final rank = _rank(entry, normalizedQuery, queryTokens);
      if (rank != null) {
        matches.add((product: entry.product, rank: rank, sourceIndex: index));
      }
    }
    matches.sort((a, b) {
      final byRank = a.rank.compareTo(b.rank);
      return byRank != 0 ? byRank : a.sourceIndex.compareTo(b.sourceIndex);
    });
    return matches
        .map((match) => ProductSearchMatch(match.product, match.rank))
        .toList(growable: false);
  }

  static int? _rank(
    _IndexedProduct entry,
    String query,
    List<String> queryTokens,
  ) {
    if (entry.code == query) return 0;
    if (entry.code.startsWith(query)) return 1;
    if (entry.name == query) return 2;
    if (entry.name.startsWith(query)) return 3;
    if (_matchesInitials(entry.nameTokens, queryTokens)) return 4;
    if (_matchesEveryToken(entry.tokens, queryTokens)) return 5;
    return null;
  }

  static bool _matchesInitials(
      List<String> nameTokens, List<String> queryTokens) {
    if (nameTokens.length < queryTokens.length) return false;
    final used = <int>{};
    for (final queryToken in queryTokens) {
      final index = _findUnused(nameTokens, used, queryToken,
          (token, query) => token.startsWith(query));
      if (index < 0) return false;
      used.add(index);
    }
    return true;
  }

  static bool _matchesEveryToken(
    List<String> candidateTokens,
    List<String> queryTokens,
  ) {
    final used = <int>{};
    final orderedQuery = [...queryTokens]
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final queryToken in orderedQuery) {
      final index = _findUnused(candidateTokens, used, queryToken,
          (token, query) => token.contains(query));
      if (index < 0) return false;
      used.add(index);
    }
    return true;
  }

  static int _findUnused(
    List<String> tokens,
    Set<int> used,
    String query,
    bool Function(String, String) matches,
  ) {
    for (var index = 0; index < tokens.length; index++) {
      if (!used.contains(index) && matches(tokens[index], query)) return index;
    }
    return -1;
  }

  static String normalize(String value) {
    var normalized = value.toLowerCase();
    const digits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };
    normalized = normalized.replaceAllMapped(
      RegExp('[${digits.keys.join()}]'),
      (match) => digits[match.group(0)]!,
    );
    normalized = normalized
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ء', '')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9\u0621-\u064A]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

class ProductSearchMatch {
  final Product product;
  final int rank;

  const ProductSearchMatch(this.product, this.rank);
}

class _IndexedProduct {
  final Product product;
  final String code;
  final String name;
  final List<String> nameTokens;
  final List<String> tokens;

  _IndexedProduct(Product product)
      : product = product,
        code = SmartProductSearchIndex.normalize(product.code),
        name = SmartProductSearchIndex.normalize(product.name),
        nameTokens = SmartProductSearchIndex.normalize(product.name)
            .split(' ')
            .where((token) => token.isNotEmpty)
            .toList(growable: false),
        tokens = [
          product.name,
          product.code,
          product.oem,
          product.group,
          product.subGroup,
          product.origin,
          product.category,
          product.brand ?? '',
          product.description ?? '',
          product.notes ?? '',
        ]
            .map(SmartProductSearchIndex.normalize)
            .expand((field) => field.split(' '))
            .where((token) => token.isNotEmpty)
            .toList(growable: false);
}

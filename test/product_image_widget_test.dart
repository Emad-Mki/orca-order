import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/widgets/product_image_widget.dart';

void main() {
  testWidgets('uses CORS fallback on web and preserves native image caching',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final context = tester.element(find.byType(SizedBox));
    final widget = const ProductImageWidget(
      imageUrl: 'https://images.example.test/product.png',
      width: 100,
      height: 100,
    ).build(context);

    if (kIsWeb) {
      expect(widget, isA<Image>());
      final image = widget as Image;
      expect(image.image, isA<NetworkImage>());
      expect(
        (image.image as NetworkImage).webHtmlElementStrategy,
        WebHtmlElementStrategy.fallback,
      );
    } else {
      expect(widget, isA<CachedNetworkImage>());
    }
  });
}

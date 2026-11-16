import 'package:flutter/material.dart';

class ProductSkeletonWidget extends StatefulWidget {
  final bool isGrid;
  const ProductSkeletonWidget({super.key, this.isGrid = true});

  @override
  State<ProductSkeletonWidget> createState() => _ProductSkeletonWidgetState();
}

class _ProductSkeletonWidgetState extends State<ProductSkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.isGrid ? _buildGridSkeleton() : _buildListSkeleton();
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return widget.isGrid ? _buildGridSkeleton() : _buildListSkeleton();
      },
    );
  }

  Widget _buildGridSkeleton() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _shimmerBox(double.infinity, double.infinity)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(double.infinity, 14, borderRadius: 4),
                const SizedBox(height: 6),
                _shimmerBox(80, 10, borderRadius: 4),
                const SizedBox(height: 10),
                _shimmerBox(60, 16, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSkeleton() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            _shimmerBox(80, 80, borderRadius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(double.infinity, 16, borderRadius: 4),
                  const SizedBox(height: 8),
                  _shimmerBox(150, 12, borderRadius: 4),
                  const SizedBox(height: 8),
                  _shimmerBox(100, 12, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _shimmerBox(50, 20, borderRadius: 4),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double width, double height, {double borderRadius = 0}) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    final opacity = 0.35 + (_controller.value * 0.24);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// A single shimmering placeholder rectangle.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: _animation.value),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// A shimmer placeholder card that mimics a list tile.
class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({super.key, this.hasSubtitle = true});

  final bool hasSubtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ShimmerBox(width: 44, height: 44, borderRadius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: double.infinity, height: 14),
                if (hasSubtitle) ...[
                  const SizedBox(height: 6),
                  ShimmerBox(width: 160, height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A shimmer placeholder card for post/event cards.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerBox(width: double.infinity, height: 14),
              SizedBox(height: 8),
              ShimmerBox(width: double.infinity, height: 12),
              SizedBox(height: 6),
              ShimmerBox(width: 180, height: 12),
              SizedBox(height: 16),
              ShimmerBox(width: double.infinity, height: 120, borderRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience widget: shows [count] shimmer list tiles.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 6, this.hasSubtitle = true});

  final int count;
  final bool hasSubtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => ShimmerListTile(hasSubtitle: hasSubtitle),
      ),
    );
  }
}

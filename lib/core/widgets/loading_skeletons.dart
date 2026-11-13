import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF25252B),
      highlightColor: const Color(0xFF41414B),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF25252B),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ServiceCardSkeleton extends StatelessWidget {
  const ServiceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Column(
            children: [
              ShimmerBox(width: 60, height: 60, borderRadius: 30),
              SizedBox(height: 8),
              ShimmerBox(width: 64, height: 9),
              SizedBox(height: 6),
              ShimmerBox(width: 48, height: 16, borderRadius: 8),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 160, height: 18),
                const SizedBox(height: 12),
                const ShimmerBox(width: double.infinity, height: 12),
                const SizedBox(height: 7),
                const ShimmerBox(width: 190, height: 12),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 72, height: 18),
                    ShimmerBox(width: 82, height: 34, borderRadius: 18),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceListSkeleton extends StatelessWidget {
  const ServiceListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) => const ServiceCardSkeleton(),
    );
  }
}

class PortfolioGridSkeleton extends StatelessWidget {
  const PortfolioGridSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: count,
      itemBuilder: (context, index) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ShimmerBox(borderRadius: 16)),
          SizedBox(height: 8),
          ShimmerBox(height: 12),
          SizedBox(height: 6),
          ShimmerBox(width: 72, height: 12),
        ],
      ),
    );
  }
}

class PortfolioStripSkeleton extends StatelessWidget {
  const PortfolioStripSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) =>
            const ShimmerBox(width: 150, height: 150, borderRadius: 12),
      ),
    );
  }
}

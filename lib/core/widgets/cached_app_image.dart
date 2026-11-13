import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'loading_skeletons.dart';

class CachedAppImage extends StatelessWidget {
  const CachedAppImage({
    required this.imageUrl,
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius = 0,
    this.errorIconSize = 40,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double borderRadius;
  final double errorIconSize;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => const ShimmerBox(borderRadius: 0),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: const Color(0xFF25252B),
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_outlined,
            size: errorIconSize,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}

class CachedAppAvatar extends StatelessWidget {
  const CachedAppAvatar({
    required this.imageUrl,
    required this.radius,
    super.key,
    this.fallbackIcon = Icons.person,
    this.backgroundColor = const Color(0xFF303030),
  });

  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Icon(
          fallbackIcon,
          color: Colors.white70,
          size: radius,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: const Color(0xFF25252B),
        highlightColor: const Color(0xFF41414B),
        child: CircleAvatar(radius: radius, backgroundColor: backgroundColor),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Icon(fallbackIcon, color: Colors.white70, size: radius),
      ),
    );
  }
}

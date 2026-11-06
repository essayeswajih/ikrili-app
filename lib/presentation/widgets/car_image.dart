import 'package:flutter/material.dart';

class CarImage extends StatelessWidget {
  const CarImage({
    super.key,
    required this.image,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.fallbackSize = 44,
  });

  final String image;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double fallbackSize;

  bool get _isNetworkImage {
    final value = image.trim().toLowerCase();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final value = image.trim();
    if (value.isEmpty) {
      return _FallbackCarIcon(size: fallbackSize);
    }

    if (_isNetworkImage) {
      return Image.network(
        value,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            _FallbackCarIcon(size: fallbackSize),
      );
    }

    return Image.asset(
      'assets/images/cars/$value',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          _FallbackCarIcon(size: fallbackSize),
    );
  }
}

class _FallbackCarIcon extends StatelessWidget {
  const _FallbackCarIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(
          Icons.directions_car,
          size: size,
          color: const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

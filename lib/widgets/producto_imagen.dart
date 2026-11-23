import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Muestra una imagen de producto guardada como base64.
class ProductoImagen extends StatelessWidget {
  const ProductoImagen({
    super.key,
    required this.imagenBase64,
    this.fit = BoxFit.cover,
    this.iconSize = 40,
  });

  final String imagenBase64;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = _decodificar(imagenBase64);

    if (bytes == null) {
      return Container(
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.inventory_2_outlined,
          size: iconSize,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return Image.memory(
      bytes,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          size: iconSize,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static Uint8List? _decodificar(String value) {
    if (value.trim().isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }
}

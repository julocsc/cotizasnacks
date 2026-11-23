import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Muestra el logotipo de la empresa guardado como base64.
///
/// Si no hay logotipo o el contenido no es una imagen válida, muestra un
/// ícono de negocio para mantener el mismo tamaño en la interfaz.
class EmpresaLogo extends StatelessWidget {
  const EmpresaLogo({
    super.key,
    required this.logoBase64,
    this.size = 88,
    this.iconSize = 32,
    this.fit = BoxFit.contain,
    this.borderRadius = 16,
  });

  final String logoBase64;
  final double size;
  final double iconSize;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = _decodificar(logoBase64);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: bytes == null
            ? Icon(
                Icons.storefront_outlined,
                size: iconSize,
                color: scheme.onSurfaceVariant,
              )
            : Image.memory(
                bytes,
                fit: fit,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.broken_image_outlined,
                  size: iconSize,
                  color: scheme.onSurfaceVariant,
                ),
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

import 'package:flutter/material.dart';

/// Estado de error reutilizable del panel de administración.
class AdminErrorState extends StatelessWidget {
  const AdminErrorState({
    super.key,
    required this.mensaje,
    required this.onReintentar,
  });

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.cloud_off_outlined,
                size: 52,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 14),
              Text(
                'No se pudo cargar la información',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vacío reutilizable del panel de administración.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.titulo,
    required this.mensaje,
    required this.accionEtiqueta,
    required this.onAccion,
  });

  final IconData icon;
  final String titulo;
  final String mensaje;
  final String accionEtiqueta;
  final VoidCallback onAccion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 52, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 14),
              Text(titulo, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAccion,
                icon: const Icon(Icons.add),
                label: Text(accionEtiqueta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

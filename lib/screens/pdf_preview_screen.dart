import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../models/cotizacion.dart';
import '../models/empresa_config.dart';
import '../services/empresa_service.dart';
import '../services/pdf_service.dart';

/// Visualiza el PDF generado y permite imprimirlo, descargarlo o compartirlo.
class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({super.key, required this.cotizacion});

  final Cotizacion cotizacion;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  final PdfService _pdfService = PdfService();
  final EmpresaService _empresaService = EmpresaService();
  late Future<Uint8List> _pdf;

  String get _nombreArchivo {
    final folio = widget.cotizacion.numeroCotizacion.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    return 'cotizacion_$folio.pdf';
  }

  @override
  void initState() {
    super.initState();
    _pdf = _generar();
  }

  Future<Uint8List> _generar() async {
    EmpresaConfig empresa;
    try {
      empresa = await _empresaService.obtenerConfiguracion();
    } catch (_) {
      // Si la configuración no está disponible (sin conexión o reglas), el
      // PDF se genera igualmente con los datos predeterminados.
      empresa = const EmpresaConfig();
    }
    return _pdfService.generar(widget.cotizacion, empresa: empresa);
  }

  void _regenerar() {
    setState(() {
      _pdf = _generar();
    });
  }

  Future<void> _compartir() async {
    try {
      final bytes = await _pdf;
      if (!mounted) return;
      await Printing.sharePdf(bytes: bytes, filename: _nombreArchivo);
    } catch (error) {
      _mostrarError('No se pudo compartir el PDF: $error');
    }
  }

  Future<void> _imprimir() async {
    try {
      final bytes = await _pdf;
      if (!mounted) return;
      await Printing.layoutPdf(
        name: _nombreArchivo,
        onLayout: (format) async => bytes,
      );
    } catch (error) {
      _mostrarError('No se pudo abrir la impresión: $error');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF · ${widget.cotizacion.numeroCotizacion}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Imprimir',
            onPressed: _imprimir,
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Descargar o compartir',
            onPressed: _compartir,
            icon: const Icon(Icons.ios_share_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorPdf(error: snapshot.error!, onReintentar: _regenerar);
          }

          if (!snapshot.hasData) {
            return const _CargandoPdf();
          }

          return PdfPreview(
            build: (format) async => snapshot.data!,
            initialPageFormat: PdfPageFormat.a4,
            canChangePageFormat: false,
            canChangeOrientation: false,
            allowPrinting: true,
            allowSharing: true,
            pdfFileName: _nombreArchivo,
          );
        },
      ),
    );
  }
}

class _CargandoPdf extends StatelessWidget {
  const _CargandoPdf();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Generando PDF...'),
        ],
      ),
    );
  }
}

/// Vista previa reutilizable para boletas, gastos u otros documentos PDF.
class DocumentoPdfScreen extends StatefulWidget {
  const DocumentoPdfScreen({
    super.key,
    required this.titulo,
    required this.nombreArchivo,
    required this.generar,
  });

  final String titulo;
  final String nombreArchivo;
  final Future<Uint8List> Function() generar;

  @override
  State<DocumentoPdfScreen> createState() => _DocumentoPdfScreenState();
}

class _DocumentoPdfScreenState extends State<DocumentoPdfScreen> {
  late Future<Uint8List> _pdf;

  @override
  void initState() {
    super.initState();
    _pdf = widget.generar();
  }

  void _regenerar() {
    setState(() {
      _pdf = widget.generar();
    });
  }

  Future<void> _compartir() async {
    try {
      final bytes = await _pdf;
      if (!mounted) return;
      await Printing.sharePdf(bytes: bytes, filename: widget.nombreArchivo);
    } catch (error) {
      _mostrarError('No se pudo compartir el PDF: $error');
    }
  }

  Future<void> _imprimir() async {
    try {
      final bytes = await _pdf;
      if (!mounted) return;
      await Printing.layoutPdf(
        name: widget.nombreArchivo,
        onLayout: (format) async => bytes,
      );
    } catch (error) {
      _mostrarError('No se pudo abrir la impresión: $error');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: <Widget>[
          IconButton(
            tooltip: 'Imprimir',
            onPressed: _imprimir,
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Descargar o compartir',
            onPressed: _compartir,
            icon: const Icon(Icons.ios_share_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorPdf(error: snapshot.error!, onReintentar: _regenerar);
          }

          if (!snapshot.hasData) {
            return const _CargandoPdf();
          }

          return PdfPreview(
            build: (format) async => snapshot.data!,
            initialPageFormat: PdfPageFormat.a4,
            canChangePageFormat: false,
            canChangeOrientation: false,
            allowPrinting: true,
            allowSharing: true,
            pdfFileName: widget.nombreArchivo,
          );
        },
      ),
    );
  }
}

class _ErrorPdf extends StatelessWidget {
  const _ErrorPdf({required this.error, required this.onReintentar});

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 42,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No se pudo generar el PDF',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    error.toString(),
                    maxLines: 5,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
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
        ),
      ),
    );
  }
}

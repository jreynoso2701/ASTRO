import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:astro/core/models/minuta.dart';
import 'package:astro/core/models/compromiso_status.dart';

/// Servicio para generar PDFs de minutas de reunión.
class MinutaPdfService {
  /// Genera un documento PDF a partir de una [Minuta].
  static Future<pw.Document> generate(Minuta minuta) async {
    final pdf = pw.Document(
      title: 'Minuta ${minuta.folio}',
      author: minuta.createdByName,
    );

    final dateStr = minuta.fecha != null
        ? DateFormat('dd/MM/yyyy').format(minuta.fecha!)
        : '—';
    final horaStr = '${minuta.horaInicio ?? '—'} – ${minuta.horaFin ?? '—'}';

    // Lugar compuesto
    String lugarStr = '';
    if (minuta.modalidad.label == 'Videoconferencia' ||
        minuta.modalidad.label == 'Llamada') {
      lugarStr = minuta.urlVideoconferencia ?? minuta.modalidad.label;
    } else if (minuta.modalidad.label == 'Híbrida') {
      final parts = <String>[];
      if (minuta.urlVideoconferencia != null) {
        parts.add(minuta.urlVideoconferencia!);
      }
      if (minuta.direccion != null) parts.add(minuta.direccion!);
      if (minuta.lugar != null) parts.add(minuta.lugar!);
      lugarStr = parts.join(' / ');
    } else {
      final parts = <String>[];
      if (minuta.direccion != null) parts.add(minuta.direccion!);
      if (minuta.lugar != null) parts.add(minuta.lugar!);
      lugarStr = parts.isNotEmpty ? parts.join(' — ') : 'Presencial';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(minuta, dateStr),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Información general
          _infoTable(minuta, dateStr, horaStr, lugarStr),
          pw.SizedBox(height: 16),

          // Objetivo
          _sectionTitle('OBJETIVO'),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 12),
            child: pw.Text(
              minuta.objetivo,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),

          // Asistentes
          if (minuta.asistentes.isNotEmpty) ...[
            _sectionTitle('ASISTENTES'),
            _asistentesTable(minuta.asistentes),
            pw.SizedBox(height: 12),
          ],

          // Asuntos tratados
          if (minuta.asuntosTratados.isNotEmpty) ...[
            _sectionTitle('ASUNTOS TRATADOS'),
            ...minuta.asuntosTratados.map(_asuntoWidget),
            pw.SizedBox(height: 12),
          ],

          // Compromisos
          if (minuta.compromisos.isNotEmpty) ...[
            _sectionTitle('COMPROMISOS ASUMIDOS'),
            _compromisosTable(minuta.compromisos),
            pw.SizedBox(height: 12),
          ],

          // Observaciones
          if (minuta.observaciones != null &&
              minuta.observaciones!.isNotEmpty) ...[
            _sectionTitle('OBSERVACIONES'),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, bottom: 12),
              child: pw.Text(
                minuta.observaciones!,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  // ── Header ───────────────────────────────────────────

  static pw.Widget _buildHeader(Minuta minuta, String dateStr) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MINUTA DE REUNIÓN',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  minuta.empresaName,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  minuta.folio,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'v${minuta.version}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 1.5),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── Footer ───────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generado por ASTRO',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }

  // ── Info table ───────────────────────────────────────

  static pw.Widget _infoTable(
    Minuta minuta,
    String dateStr,
    String horaStr,
    String lugarStr,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(3),
      },
      children: [
        _infoRow('Folio Minuta', minuta.folio),
        _infoRow('Proyecto', minuta.projectName),
        _infoRow('Empresa', minuta.empresaName),
        _infoRow('Versión', minuta.version),
        _infoRow('Fecha', dateStr),
        _infoRow('Horario', horaStr),
        _infoRow('Modalidad', minuta.modalidad.label),
        _infoRow('Lugar / Enlace', lugarStr),
      ],
    );
  }

  static pw.TableRow _infoRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  // ── Section title ────────────────────────────────────

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      margin: const pw.EdgeInsets.only(bottom: 8),
      color: PdfColors.grey200,
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  // ── Asistentes table ─────────────────────────────────

  static pw.Widget _asistentesTable(List<AsistenteMinuta> asistentes) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cellBold('No.'),
            _cellBold('Nombre'),
            _cellBold('Puesto / Empresa'),
            _cellBold('Asistencia'),
          ],
        ),
        for (var i = 0; i < asistentes.length; i++)
          pw.TableRow(
            children: [
              _cell('${i + 1}'),
              _cell(asistentes[i].nombre),
              _cell(asistentes[i].puesto),
              _cell(asistentes[i].asistencia ? 'Sí' : 'No'),
            ],
          ),
      ],
    );
  }

  // ── Asunto widget ────────────────────────────────────

  static pw.Widget _asuntoWidget(AsuntoTratado asunto) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 8, bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${asunto.numero}. ${asunto.texto}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (asunto.subitems.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16, top: 2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: asunto.subitems
                    .asMap()
                    .entries
                    .map(
                      (e) => pw.Text(
                        '${String.fromCharCode(97 + e.key)}. ${e.value}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ── Compromisos table ────────────────────────────────

  static pw.Widget _compromisosTable(List<CompromisoMinuta> compromisos) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cellBold('No.'),
            _cellBold('Tarea'),
            _cellBold('Responsable'),
            _cellBold('Fecha Entrega'),
            _cellBold('Estado'),
          ],
        ),
        for (final c in compromisos)
          pw.TableRow(
            children: [
              _cell('${c.numero}'),
              _cell(c.tarea),
              _cell(c.responsable),
              _cell(
                c.fechaEntrega != null
                    ? DateFormat('dd/MM/yyyy').format(c.fechaEntrega!)
                    : '—',
              ),
              _statusCell(c.status),
            ],
          ),
      ],
    );
  }

  static pw.Widget _statusCell(CompromisoStatus status) {
    final (color, label) = switch (status) {
      CompromisoStatus.pendiente => (PdfColors.orange, 'Pendiente'),
      CompromisoStatus.cumplido => (PdfColors.green, 'Cumplido'),
      CompromisoStatus.vencido => (PdfColors.red, 'Vencido'),
    };

    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8,
          color: color,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────

  static pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  static pw.Widget _cellBold(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }
}

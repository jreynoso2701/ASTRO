import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

import 'package:astro/core/models/minuta.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/tarea.dart';
import 'package:astro/core/models/ticket.dart';

/// Ancho del papel del rollo en uso: 58 mm ≈ 32 caracteres en fuente A.
const _paperSize = PaperSize.mm58;
const _cols = 32;

final _fecha = DateFormat('dd/MM/yyyy');
final _fechaHora = DateFormat('dd/MM/yyyy HH:mm');

/// Quita acentos y demás signos fuera de ASCII.
///
/// Las impresoras térmicas baratas ignoran la tabla de códigos que se les pide
/// y sustituyen los acentos por símbolos sueltos; transliterar es más legible
/// que arriesgarse a un carácter de bloque a mitad de palabra.
String _ascii(String input) {
  const from = 'áàäâãÁÀÄÂÃéèëêÉÈËÊíìïîÍÌÏÎóòöôõÓÒÖÔÕúùüûÚÙÜÛñÑçÇ';
  const to = 'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUnNcC';

  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final i = from.indexOf(char);
    if (i >= 0) {
      buffer.write(to[i]);
    } else if (rune == 0x2018 || rune == 0x2019) {
      buffer.write("'");
    } else if (rune == 0x201C || rune == 0x201D) {
      buffer.write('"');
    } else if (rune == 0x2013 || rune == 0x2014) {
      buffer.write('-');
    } else if (rune < 0x20 && rune != 0x0A) {
      buffer.write(' ');
    } else if (rune > 0x7E) {
      buffer.write('?');
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// Parte [text] en líneas de como mucho [width] caracteres sin cortar palabras
/// (salvo las que por sí solas no caben).
List<String> _wrap(String text, int width) {
  final out = <String>[];
  for (final rawLine in text.split('\n')) {
    var line = '';
    for (final word in rawLine.trim().split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (word.length > width) {
        if (line.isNotEmpty) {
          out.add(line);
          line = '';
        }
        var rest = word;
        while (rest.length > width) {
          out.add(rest.substring(0, width));
          rest = rest.substring(width);
        }
        line = rest;
        continue;
      }
      if (line.isEmpty) {
        line = word;
      } else if (line.length + 1 + word.length <= width) {
        line = '$line $word';
      } else {
        out.add(line);
        line = word;
      }
    }
    out.add(line);
  }
  return out.isEmpty ? [''] : out;
}

/// Escribe un recibo de 32 columnas sobre un [Generator].
///
/// Existe para que los cuatro recibos (ticket, requerimiento, tarea y minuta)
/// compartan el mismo aspecto: mismos separadores, mismas etiquetas y el mismo
/// pie.
class _ReceiptWriter {
  _ReceiptWriter(this._g);

  final Generator _g;
  final List<int> _bytes = [];

  List<int> get bytes => _bytes;

  void title(String text) {
    _bytes.addAll(
      _g.text(
        _ascii(text),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
  }

  void centered(String text, {bool bold = false}) {
    _bytes.addAll(
      _g.text(
        _ascii(text),
        styles: PosStyles(align: PosAlign.center, bold: bold),
      ),
    );
  }

  void divider([String ch = '-']) => _bytes.addAll(_g.text(ch * _cols));

  /// Encabezado de sección, centrado y subrayado en su propia línea.
  void section(String label) {
    _bytes.addAll(
      _g.text(
        _ascii(label).toUpperCase(),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
  }

  /// Par etiqueta/valor. Si no cabe en una línea, el valor baja a la siguiente
  /// con sangría en vez de partirse a mitad de palabra.
  void field(String label, String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return;

    final tag = '${_ascii(label)}: ';
    final text = _ascii(v);
    if (tag.length + text.length <= _cols) {
      _bytes.addAll(_g.text('$tag$text'));
      return;
    }
    _bytes.addAll(_g.text(tag.trimRight()));
    paragraph(text, indent: 2);
  }

  /// Texto largo partido por palabras.
  void paragraph(String text, {int indent = 0}) {
    final pad = ' ' * indent;
    for (final line in _wrap(_ascii(text), _cols - indent)) {
      _bytes.addAll(_g.text('$pad$line'));
    }
  }

  /// Elemento de lista, con la sangría colgante alineada bajo el texto y no
  /// bajo la marca.
  void bullet(String mark, String text) {
    final prefix = '$mark ';
    final lines = _wrap(_ascii(text), _cols - prefix.length);
    for (var i = 0; i < lines.length; i++) {
      _bytes.addAll(
        _g.text('${i == 0 ? prefix : ' ' * prefix.length}${lines[i]}'),
      );
    }
  }

  void blank([int n = 1]) => _bytes.addAll(_g.emptyLines(n));

  /// Cierra el recibo y avanza papel.
  ///
  /// Avanza en vez de cortar porque este modelo no lleva cuchilla: el corte se
  /// hace a mano contra la barra dentada.
  void footer() {
    divider();
    centered('ASTRO', bold: true);
    centered('Impreso ${_fechaHora.format(DateTime.now())}');
    _bytes.addAll(_g.feed(3));
  }
}

Future<_ReceiptWriter> _writer(String heading, String folio) async {
  final profile = await CapabilityProfile.load();
  return _ReceiptWriter(Generator(_paperSize, profile))
    ..blank()
    ..centered(heading, bold: true)
    ..title(folio)
    ..divider('=');
}

String _list(List<String> names) => names.isEmpty ? '' : names.join(', ');

// ── Recibos ──────────────────────────────────────────────

Future<List<int>> buildTicketReceipt(Ticket t) async {
  final w = await _writer('TICKET', t.folio);

  w
    ..paragraph(t.titulo)
    ..divider()
    ..field('Proyecto', t.projectName)
    ..field('Modulo', t.moduleName)
    ..field('Empresa', t.empresaName)
    ..field('Estatus', t.status.label)
    ..field('Prioridad', t.priority.label)
    ..field('Avance', '${t.porcentajeAvance.round()}%')
    ..field('Reporta', t.createdByName)
    ..field('Asignado', _list(t.assignedToNames))
    ..field(
      'Registro',
      t.createdAt == null ? null : _fecha.format(t.createdAt!),
    )
    ..field('Compromiso', t.solucionProgramada);

  if (t.descripcion.trim().isNotEmpty) {
    w
      ..divider()
      ..section('Descripcion')
      ..paragraph(t.descripcion);
  }

  w.footer();
  return w.bytes;
}

Future<List<int>> buildRequerimientoReceipt(Requerimiento r) async {
  final w = await _writer('REQUERIMIENTO', r.folio);

  w
    ..paragraph(r.titulo)
    ..divider()
    ..field('Proyecto', r.projectName)
    ..field('Modulo', r.moduleName ?? r.moduloPropuesto)
    ..field('Empresa', r.empresaName)
    ..field('Tipo', r.tipo.label)
    ..field('Estatus', r.status.label)
    ..field('Fase', r.faseAsignada?.label)
    ..field('Prioridad', r.prioridad.label)
    ..field('Avance', '${r.porcentajeAvance.round()}%')
    ..field('Levanta', r.createdByName)
    ..field('Asignado', _list(r.assignedToNames))
    ..field(
      'Compromiso',
      r.fechaCompromiso == null ? null : _fecha.format(r.fechaCompromiso!),
    );

  if (r.descripcion.trim().isNotEmpty) {
    w
      ..divider()
      ..section('Descripcion')
      ..paragraph(r.descripcion);
  }

  if (r.criteriosAceptacion.isNotEmpty) {
    w
      ..divider()
      ..section('Criterios de aceptacion');
    final criterios = [...r.criteriosAceptacion]
      ..sort((a, b) => a.orden.compareTo(b.orden));
    for (final c in criterios) {
      w.bullet(c.completado ? '[X]' : '[ ]', c.texto);
    }
  }

  if (r.participantes.isNotEmpty) {
    w
      ..divider()
      ..section('Participantes');
    for (final p in r.participantes) {
      w.bullet('-', p.rol == null ? p.nombre : '${p.nombre} (${p.rol})');
    }
  }

  w.footer();
  return w.bytes;
}

Future<List<int>> buildTareaReceipt(Tarea t) async {
  final w = await _writer('TAREA', t.folio);

  w
    ..paragraph(t.titulo)
    ..divider()
    ..field('Proyecto', t.projectName)
    ..field('Modulo', t.moduleName)
    ..field('Estatus', t.status.label)
    ..field('Prioridad', t.prioridad.label)
    ..field('Creada por', t.createdByName)
    ..field('Asignado', _list(t.assignedToNames))
    ..field(
      'Entrega',
      t.fechaEntrega == null ? null : _fecha.format(t.fechaEntrega!),
    );

  if (t.descripcion.trim().isNotEmpty) {
    w
      ..divider()
      ..section('Descripcion')
      ..paragraph(t.descripcion);
  }

  if (t.subtareas.isNotEmpty) {
    final hechas = t.subtareas.where((s) => s.completada).length;
    w
      ..divider()
      ..section('Subtareas ($hechas/${t.subtareas.length})');
    final subtareas = [...t.subtareas]
      ..sort((a, b) => a.orden.compareTo(b.orden));
    for (final s in subtareas) {
      w.bullet(s.completada ? '[X]' : '[ ]', s.titulo);
    }
  }

  w.footer();
  return w.bytes;
}

Future<List<int>> buildMinutaReceipt(Minuta m) async {
  final w = await _writer('MINUTA', m.folio);

  w
    ..centered('v${m.version}')
    ..divider()
    ..field('Proyecto', m.projectName)
    ..field('Empresa', m.empresaName)
    ..field('Fecha', m.fecha == null ? null : _fecha.format(m.fecha!))
    ..field(
      'Horario',
      m.horaInicio == null ? null : '${m.horaInicio} - ${m.horaFin ?? ''}',
    )
    ..field('Modalidad', m.modalidad.label)
    ..field('Lugar', m.lugar)
    ..field('Direccion', m.direccion)
    ..field('Levanta', m.createdByName);

  if (m.objetivo.trim().isNotEmpty) {
    w
      ..divider()
      ..section('Objetivo')
      ..paragraph(m.objetivo);
  }

  if (m.asistentes.isNotEmpty) {
    w
      ..divider()
      ..section('Asistentes');
    for (final a in m.asistentes) {
      final puesto = a.puesto.trim().isEmpty ? '' : ' (${a.puesto})';
      w.bullet(a.asistencia ? '[X]' : '[ ]', '${a.nombre}$puesto');
    }
  }

  if (m.asuntosTratados.isNotEmpty) {
    w
      ..divider()
      ..section('Asuntos tratados');
    for (final a in m.asuntosTratados) {
      w.bullet('${a.numero}.', a.texto);
      for (final sub in a.subitems) {
        w.bullet('   -', sub);
      }
    }
  }

  if (m.compromisos.isNotEmpty) {
    w
      ..divider()
      ..section('Compromisos');
    for (final c in m.compromisos) {
      final fecha = c.fechaEntrega == null
          ? ''
          : ' | ${_fecha.format(c.fechaEntrega!)}';
      w
        ..bullet('${c.numero}.', c.tarea)
        ..paragraph(
          'Resp: ${c.responsable}$fecha | ${c.status.label}',
          indent: 4,
        );
    }
  }

  if ((m.observaciones ?? '').trim().isNotEmpty) {
    w
      ..divider()
      ..section('Observaciones')
      ..paragraph(m.observaciones!);
  }

  w.footer();
  return w.bytes;
}

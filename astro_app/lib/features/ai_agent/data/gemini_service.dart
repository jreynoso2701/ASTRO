import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:astro/core/models/ai_chat_message.dart';

/// Servicio que interactúa con Gemini via Firebase AI Logic.
///
/// Usa function calling para consultar datos del proyecto y ejecutar
/// acciones dentro de la app.
class GeminiService {
  GeminiService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  GenerativeModel? _model;
  ChatSession? _chat;

  /// Nombres de proyectos a los que el usuario tiene acceso.
  Set<String> _allowedProjects = {};

  /// Mapa de nombre en minúsculas → nombre real para matching flexible.
  Map<String, String> _projectNameMap = {};

  /// Si es Root, tiene acceso a todos los proyectos.
  bool _isRoot = false;

  /// Configura los proyectos permitidos y reinicializa el modelo
  /// con un system prompt personalizado.
  Future<void> initWithUserContext({
    required List<String> allowedProjectNames,
    required bool isRoot,
  }) async {
    _allowedProjects = allowedProjectNames.toSet();
    _projectNameMap = {
      for (final name in allowedProjectNames) name.toLowerCase(): name,
    };
    _isRoot = isRoot;

    final prompt = _buildSystemPrompt(allowedProjectNames, isRoot);
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(prompt),
      tools: _tools,
    );
    _chat = null; // Reiniciar sesión con el nuevo modelo
  }

  /// Inicia (o reinicia) una sesión de chat.
  void startChat({List<Content>? history}) {
    if (_model == null) return;
    _chat = _model!.startChat(history: history ?? []);
  }

  /// Valida que el proyecto esté en la lista de permitidos.
  /// Root tiene acceso a todos.
  bool _isProjectAllowed(String projectName) {
    if (_isRoot) return true;
    // Buscar por coincidencia exacta o case-insensitive
    if (_allowedProjects.contains(projectName)) return true;
    return _projectNameMap.containsKey(projectName.toLowerCase());
  }

  /// Resuelve el nombre real del proyecto en Firestore.
  /// Busca por coincidencia case-insensitive en proyectos permitidos.
  /// Si es Root y no encuentra, consulta Firestore directamente.
  Future<String> _resolveProjectName(String input) async {
    // Coincidencia exacta
    if (_allowedProjects.contains(input)) return input;

    // Coincidencia case-insensitive en proyectos del usuario
    final lower = input.toLowerCase();
    if (_projectNameMap.containsKey(lower)) return _projectNameMap[lower]!;

    // Para Root: buscar en Firestore por nombre case-insensitive
    if (_isRoot) {
      final snap = await _db.collection('Proyectos').get();
      for (final doc in snap.docs) {
        final name = doc.data()['nombreProyecto'] as String? ?? '';
        if (name.toLowerCase() == lower) {
          // Cachear para futuras consultas
          _projectNameMap[lower] = name;
          _allowedProjects.add(name);
          return name;
        }
      }
    }

    // Si no se resolvió, devolver el input original
    return input;
  }

  /// Envía un mensaje del usuario y obtiene la respuesta completa del agente.
  ///
  /// Maneja automáticamente las function calls iterativamente hasta obtener
  /// una respuesta de texto final.
  Future<List<AiContentBlock>> sendMessage(
    String userText, {
    required String userId,
    String? projectId,
  }) async {
    if (_model == null) {
      throw StateError(
        'GeminiService no inicializado. Llama a initWithUserContext primero.',
      );
    }
    _chat ??= _model!.startChat();

    final response = await _chat!.sendMessage(Content.text(userText));
    return _processResponse(response, userId: userId, projectId: projectId);
  }

  // ── Procesar respuesta (incluye function call loop) ──

  Future<List<AiContentBlock>> _processResponse(
    GenerateContentResponse response, {
    required String userId,
    String? projectId,
  }) async {
    final blocks = <AiContentBlock>[];
    var currentResponse = response;

    // Loop de function calls
    while (true) {
      final functionCalls = currentResponse.functionCalls.toList();
      if (functionCalls.isEmpty) break;

      final functionResponses = <FunctionResponse>[];

      for (final call in functionCalls) {
        final result = await _executeFunction(
          call.name,
          call.args,
          userId: userId,
          projectId: projectId,
        );

        // Agregar bloques de contenido enriquecido si la función retornó
        if (result['_contentBlock'] != null) {
          blocks.add(result['_contentBlock'] as AiContentBlock);
        }

        // Remover _contentBlock antes de enviar a Gemini (no es serializable)
        final cleanResult = Map<String, dynamic>.from(result)
          ..remove('_contentBlock');

        functionResponses.add(FunctionResponse(call.name, cleanResult));
      }

      // Enviar resultados de las funciones al modelo
      currentResponse = await _chat!.sendMessage(
        Content.functionResponses(functionResponses),
      );
    }

    // Extraer texto de la respuesta final
    final text = currentResponse.text;
    if (text != null && text.trim().isNotEmpty) {
      blocks.insert(0, AiContentBlock(type: AiContentType.text, text: text));
    }

    return blocks;
  }

  // ── Definición de tools (function declarations) ──

  List<Tool> get _tools => [
    Tool.functionDeclarations([
      _searchTicketsFn,
      _getProjectProgressFn,
      _searchMinutasFn,
      _searchRequerimientosFn,
      _searchCitasFn,
      _searchTareasFn,
      _getProjectSummaryFn,
    ]),
  ];

  FunctionDeclaration get _searchTicketsFn => FunctionDeclaration(
    'buscarTickets',
    'Busca tickets/incidentes de un proyecto. Puede filtrar por estado, prioridad o texto. Por defecto solo busca activos; usa archivados=true para buscar en los archivados.',
    parameters: {
      'projectName': Schema.string(
        description: 'Nombre del proyecto en Firestore',
      ),
      'status': Schema.string(
        description:
            'Filtro de estado: PENDIENTE, EN_DESARROLLO, PRUEBAS_INTERNAS, PRUEBAS_CLIENTE, BUGS, RESUELTO, ARCHIVADO',
        nullable: true,
      ),
      'prioridad': Schema.string(
        description: 'Filtro de prioridad: baja, media, alta, critica',
        nullable: true,
      ),
      'busqueda': Schema.string(
        description: 'Texto libre para buscar en folio o título',
        nullable: true,
      ),
      'archivados': Schema.boolean(
        description:
            'true para buscar solo tickets archivados (isActive=false). Default: false (solo activos).',
        nullable: true,
      ),
      'limit': Schema.integer(
        description: 'Máximo de resultados (default 10)',
        nullable: true,
      ),
    },
  );

  FunctionDeclaration get _getProjectProgressFn => FunctionDeclaration(
    'obtenerProgresoProyecto',
    'Obtiene el progreso general de un proyecto, incluyendo módulos y penalización por tickets.',
    parameters: {
      'projectName': Schema.string(description: 'Nombre del proyecto'),
    },
  );

  FunctionDeclaration get _searchMinutasFn => FunctionDeclaration(
    'buscarMinutas',
    'Busca minutas de un proyecto. Puede filtrar por texto en folio u objetivo.',
    parameters: {
      'projectName': Schema.string(description: 'Nombre del proyecto'),
      'busqueda': Schema.string(
        description: 'Texto libre para buscar en folio u objetivo',
        nullable: true,
      ),
      'limit': Schema.integer(
        description: 'Máximo de resultados (default 5)',
        nullable: true,
      ),
    },
  );

  FunctionDeclaration get _searchRequerimientosFn => FunctionDeclaration(
    'buscarRequerimientos',
    'Busca requerimientos de un proyecto. Puede filtrar por estado o texto.',
    parameters: {
      'projectName': Schema.string(description: 'Nombre del proyecto'),
      'status': Schema.string(
        description:
            'Estado: Propuesto, En Revisión, En Desarrollo, Implementado, Completado, Descartado',
        nullable: true,
      ),
      'busqueda': Schema.string(
        description: 'Texto libre para buscar en folio o título',
        nullable: true,
      ),
      'limit': Schema.integer(
        description: 'Máximo de resultados (default 5)',
        nullable: true,
      ),
    },
  );

  FunctionDeclaration get _searchCitasFn => FunctionDeclaration(
    'buscarCitas',
    'Busca citas/reuniones de un proyecto. Puede filtrar por estado.',
    parameters: {
      'projectName': Schema.string(description: 'Nombre del proyecto'),
      'status': Schema.string(
        description: 'Estado: programada, enCurso, completada, cancelada',
        nullable: true,
      ),
      'limit': Schema.integer(
        description: 'Máximo de resultados (default 5)',
        nullable: true,
      ),
    },
  );

  FunctionDeclaration get _searchTareasFn => FunctionDeclaration(
    'buscarTareas',
    'Busca tareas de un proyecto. Puede filtrar por estado, prioridad, asignado o texto.',
    parameters: {
      'projectName': Schema.string(
        description: 'Nombre del proyecto en Firestore',
      ),
      'status': Schema.string(
        description:
            'Filtro de estado: pendiente, enProgreso, completada, cancelada',
        nullable: true,
      ),
      'prioridad': Schema.string(
        description: 'Filtro de prioridad: baja, media, alta, urgente',
        nullable: true,
      ),
      'assignedToName': Schema.string(
        description: 'Nombre del responsable asignado para filtrar sus tareas',
        nullable: true,
      ),
      'busqueda': Schema.string(
        description: 'Texto libre para buscar en folio o título',
        nullable: true,
      ),
      'archivados': Schema.boolean(
        description:
            'true para buscar solo tareas archivadas (isActive=false). Default: false (solo activas).',
        nullable: true,
      ),
      'limit': Schema.integer(
        description: 'Máximo de resultados (default 10)',
        nullable: true,
      ),
    },
  );

  FunctionDeclaration get _getProjectSummaryFn => FunctionDeclaration(
    'obtenerResumenProyecto',
    'Obtiene un resumen completo del proyecto: tickets activos, módulos, requerimientos pendientes, próximas citas.',
    parameters: {
      'projectName': Schema.string(description: 'Nombre del proyecto'),
    },
  );

  // ── Ejecución de funciones ──

  Future<Map<String, dynamic>> _executeFunction(
    String name,
    Map<String, dynamic> args, {
    required String userId,
    String? projectId,
  }) async {
    // ── Resolver y validar nombre del proyecto ──
    final rawName = args['projectName'] as String?;
    if (rawName != null) {
      final resolved = await _resolveProjectName(rawName);
      args = {...args, 'projectName': resolved};

      if (!_isProjectAllowed(resolved)) {
        return {
          'error': 'No tienes acceso al proyecto "$rawName".',
          'allowed': false,
        };
      }
    }

    switch (name) {
      case 'buscarTickets':
        return _execSearchTickets(args);
      case 'obtenerProgresoProyecto':
        return _execGetProgress(args);
      case 'buscarMinutas':
        return _execSearchMinutas(args);
      case 'buscarRequerimientos':
        return _execSearchRequerimientos(args);
      case 'buscarCitas':
        return _execSearchCitas(args);
      case 'buscarTareas':
        return _execSearchTareas(args);
      case 'obtenerResumenProyecto':
        return _execGetSummary(args);
      default:
        return {'error': 'Función no reconocida: $name'};
    }
  }

  Future<Map<String, dynamic>> _execSearchTickets(
    Map<String, dynamic> args,
  ) async {
    final projectName = args['projectName'] as String;
    final status = args['status'] as String?;
    final prioridad = args['prioridad'] as String?;
    final busqueda = args['busqueda'] as String?;
    final archivados = args['archivados'] as bool? ?? false;
    final limit = (args['limit'] as num?)?.toInt() ?? 10;

    Query<Map<String, dynamic>> query = _db
        .collection('Incidentes')
        .where('fkxProyecto', isEqualTo: projectName)
        .where('isActive', isEqualTo: !archivados);

    if (status != null) {
      query = query.where('estatusIncidente', isEqualTo: status);
    }
    if (prioridad != null) {
      query = query.where('prioridadIncidente', isEqualTo: prioridad);
    }

    final snap = await query
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();

    final tickets = snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'folio': data['folioIncidente'] ?? '',
        'titulo': data['tituloIncidente'] ?? '',
        'status': data['estatusIncidente'] ?? '',
        'prioridad': data['prioridadIncidente'] ?? '',
        'modulo': data['fkModulo'] ?? '',
        'avance': data['porcentajeAvance'] ?? 0,
        'impacto': data['impactoIncidente'] ?? 0,
        'reporto': data['nombreReportante'] ?? '',
        'soporte': data['soporteAsignado'] ?? '',
        'createdAt':
            (data['fhCreacion'] as Timestamp?)?.toDate().toIso8601String() ??
            (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ??
            '',
      };
    }).toList();

    // Filtrar por texto si se proporcionó
    var filtered = tickets;
    if (busqueda != null && busqueda.isNotEmpty) {
      final lower = busqueda.toLowerCase();
      filtered = tickets
          .where(
            (t) =>
                (t['folio'] as String).toLowerCase().contains(lower) ||
                (t['titulo'] as String).toLowerCase().contains(lower),
          )
          .toList();
    }

    final ids = filtered.map((t) => t['id'] as String).toList();
    final items = filtered
        .map(
          (t) => {
            'id': t['id'],
            'folio': t['folio'],
            'titulo': t['titulo'],
            'status': t['status'],
            'prioridad': t['prioridad'],
          },
        )
        .toList();

    return {
      'count': filtered.length,
      'tickets': filtered,
      '_contentBlock': AiContentBlock(
        type: AiContentType.tickets,
        text: '${filtered.length} ticket(s) encontrados',
        data: ids,
        items: items,
      ),
    };
  }

  Future<Map<String, dynamic>> _execGetProgress(
    Map<String, dynamic> args,
  ) async {
    final projectName = args['projectName'] as String;

    // Obtener módulos activos (estatusModulo = true)
    final modSnap = await _db
        .collection('Modulos')
        .where('fkProyecto', isEqualTo: projectName)
        .where('estatusModulo', isEqualTo: true)
        .get();

    // Obtener tickets abiertos del proyecto para calcular penalización
    final ticketSnap = await _db
        .collection('Incidentes')
        .where('fkxProyecto', isEqualTo: projectName)
        .where('isActive', isEqualTo: true)
        .get();

    // Ticket data para penalización por módulo
    final openTickets = ticketSnap.docs.where((d) {
      final st = (d.data()['estatusIncidente'] ?? '').toString().toUpperCase();
      return st != 'RESUELTO' && st != 'ARCHIVADO';
    }).toList();

    final modulos = modSnap.docs.map((d) {
      final data = d.data();
      final moduleName = data['nombreModulo'] as String? ?? '';
      final base = _parseDouble(data['porcentCompletaModulo']) ?? 0;

      // Penalización: prioridad.weight × (impacto/10) × (1 - avance/100)
      double penalty = 0;
      for (final t in openTickets) {
        final td = t.data();
        if ((td['fkxModulo'] ?? '') != moduleName) continue;
        final pWeight = _priorityWeight(td['prioridadIncidente'] ?? '');
        final impacto = (_parseDouble(td['impacto']) ?? 5) / 10.0;
        final avance = (_parseDouble(td['porcentajeAvance']) ?? 0) / 100.0;
        penalty += pWeight * impacto * (1.0 - avance);
      }

      final adjusted = (base - penalty).clamp(0, 100).toDouble();
      return {
        'nombre': moduleName,
        'progresoBase': base.round(),
        'penalizacion': penalty.round(),
        'progreso': adjusted.round(),
      };
    }).toList();

    double totalProgress = 0;
    double totalBase = 0;
    if (modulos.isNotEmpty) {
      totalProgress =
          modulos.fold<double>(
            0,
            (acc, m) => acc + ((m['progreso'] as num).toDouble()),
          ) /
          modulos.length;
      totalBase =
          modulos.fold<double>(
            0,
            (acc, m) => acc + ((m['progresoBase'] as num).toDouble()),
          ) /
          modulos.length;
    }

    final hasPenalty = totalBase > totalProgress;
    final progressText = hasPenalty
        ? 'Progreso general: ${totalProgress.round()}% (base: ${totalBase.round()}%, penalización por tickets: -${(totalBase - totalProgress).toStringAsFixed(1)}%)'
        : 'Progreso general: ${totalProgress.round()}%';

    return {
      'projectName': projectName,
      'totalModules': modulos.length,
      'moduleDetails': modulos,
      'overallProgress': totalProgress.round(),
      'baseProgress': totalBase.round(),
      '_contentBlock': AiContentBlock(
        type: AiContentType.progress,
        text: progressText,
      ),
    };
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static double _priorityWeight(String prioridad) {
    final upper = prioridad.toUpperCase().trim();
    return switch (upper) {
      'BAJA' => 1.0,
      'NORMAL' => 3.0,
      'ALTA' => 5.0,
      'CRITICA' || 'CRÍTICA' => 8.0,
      _ => 3.0,
    };
  }

  Future<Map<String, dynamic>> _execSearchMinutas(
    Map<String, dynamic> args,
  ) async {
    final projectName = args['projectName'] as String;
    final busqueda = args['busqueda'] as String?;
    final limit = (args['limit'] as num?)?.toInt() ?? 5;

    final snap = await _db
        .collection('Minutas')
        .where('projectName', isEqualTo: projectName)
        .where('isActive', isEqualTo: true)
        .orderBy('fecha', descending: true)
        .limit(limit)
        .get();

    var minutas = snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'folio': data['folio'] ?? '',
        'objetivo': data['objetivo'] ?? '',
        'fecha':
            (data['fecha'] as Timestamp?)?.toDate().toIso8601String() ?? '',
        'modalidad': data['modalidad'] ?? '',
      };
    }).toList();

    if (busqueda != null && busqueda.isNotEmpty) {
      final lower = busqueda.toLowerCase();
      minutas = minutas
          .where(
            (m) =>
                (m['folio'] as String).toLowerCase().contains(lower) ||
                (m['objetivo'] as String).toLowerCase().contains(lower),
          )
          .toList();
    }

    final ids = minutas.map((m) => m['id'] as String).toList();
    final items = minutas
        .map(
          (m) => {
            'id': m['id'],
            'folio': m['folio'],
            'titulo': m['objetivo'],
            'fecha': m['fecha'],
            'modalidad': m['modalidad'],
          },
        )
        .toList();

    return {
      'count': minutas.length,
      'minutas': minutas,
      '_contentBlock': AiContentBlock(
        type: AiContentType.minutas,
        text: '${minutas.length} minuta(s) encontradas',
        data: ids,
        items: items,
      ),
    };
  }

  Future<Map<String, dynamic>> _execSearchRequerimientos(
    Map<String, dynamic> args,
  ) async {
    final projectName = args['projectName'] as String;
    final status = args['status'] as String?;
    final busqueda = args['busqueda'] as String?;
    final limit = (args['limit'] as num?)?.toInt() ?? 5;

    Query<Map<String, dynamic>> query = _db
        .collection('Requerimientos')
        .where('projectName', isEqualTo: projectName);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final snap = await query
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();

    var reqs = snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'folio': data['folio'] ?? '',
        'titulo': data['titulo'] ?? '',
        'status': data['status'] ?? '',
        'tipo': data['tipo'] ?? '',
        'avance': data['porcentajeAvance'] ?? 0,
      };
    }).toList();

    if (busqueda != null && busqueda.isNotEmpty) {
      final lower = busqueda.toLowerCase();
      reqs = reqs
          .where(
            (r) =>
                (r['folio'] as String).toLowerCase().contains(lower) ||
                (r['titulo'] as String).toLowerCase().contains(lower),
          )
          .toList();
    }

    final ids = reqs.map((r) => r['id'] as String).toList();
    final items = reqs
        .map(
          (r) => {
            'id': r['id'],
            'folio': r['folio'],
            'titulo': r['titulo'],
            'status': r['status'],
          },
        )
        .toList();

    return {
      'count': reqs.length,
      'requerimientos': reqs,
      '_contentBlock': AiContentBlock(
        type: AiContentType.requerimientos,
        text: '${reqs.length} requerimiento(s) encontrados',
        data: ids,
        items: items,
      ),
    };
  }

  Future<Map<String, dynamic>> _execSearchCitas(
    Map<String, dynamic> args,
  ) async {
    final projectName = args['projectName'] as String;
    final status = args['status'] as String?;
    final limit = (args['limit'] as num?)?.toInt() ?? 5;

    Query<Map<String, dynamic>> query = _db
        .collection('Citas')
        .where('projectName', isEqualTo: projectName)
        .where('isActive', isEqualTo: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final snap = await query
        .orderBy('fechaHora', descending: true)
        .limit(limit)
        .get();

    final citas = snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'folio': data['folio'] ?? '',
        'titulo': data['titulo'] ?? '',
        'status': data['status'] ?? '',
        'fecha':
            (data['fechaHora'] as Timestamp?)?.toDate().toIso8601String() ?? '',
        'modalidad': data['modalidad'] ?? '',
      };
    }).toList();

    final ids = citas.map((c) => c['id'] as String).toList();
    final citaItems = citas
        .map(
          (c) => {
            'id': c['id'],
            'folio': c['folio'],
            'titulo': c['titulo'],
            'status': c['status'],
            'fecha': c['fecha'],
          },
        )
        .toList();

    return {
      'count': citas.length,
      'citas': citas,
      '_contentBlock': AiContentBlock(
        type: AiContentType.citas,
        text: '${citas.length} cita(s) encontradas',
        data: ids,
        items: citaItems,
      ),
    };
  }

  Future<Map<String, dynamic>> _execSearchTareas(
    Map<String, dynamic> args,
  ) async {
    final projectName = args['projectName'] as String;
    final status = args['status'] as String?;
    final prioridad = args['prioridad'] as String?;
    final assignedToName = args['assignedToName'] as String?;
    final busqueda = args['busqueda'] as String?;
    final archivados = args['archivados'] as bool? ?? false;
    final limit = (args['limit'] as num?)?.toInt() ?? 10;

    // Resolver projectId a partir del nombre.
    final projSnap = await _db
        .collection('Proyectos')
        .where('nombreProyecto', isEqualTo: projectName)
        .limit(1)
        .get();
    if (projSnap.docs.isEmpty) {
      return {'error': 'Proyecto "$projectName" no encontrado', 'count': 0};
    }
    final projectId = projSnap.docs.first.id;

    Query<Map<String, dynamic>> query = _db
        .collection('Tareas')
        .where('projectId', isEqualTo: projectId)
        .where('isActive', isEqualTo: !archivados);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    if (prioridad != null) {
      query = query.where('prioridad', isEqualTo: prioridad);
    }

    final snap = await query
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();

    var tareas = snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'folio': data['folio'] ?? '',
        'titulo': data['titulo'] ?? '',
        'status': data['status'] ?? '',
        'prioridad': data['prioridad'] ?? '',
        'assignedToName': data['assignedToName'] ?? '',
        'moduleName': data['moduleName'] ?? '',
        'fechaEntrega':
            (data['fechaEntrega'] as Timestamp?)?.toDate().toIso8601String() ??
            '',
        'projectId': projectId,
      };
    }).toList();

    // Filtros client-side
    if (assignedToName != null && assignedToName.isNotEmpty) {
      final lower = assignedToName.toLowerCase();
      tareas = tareas
          .where(
            (t) =>
                (t['assignedToName'] as String).toLowerCase().contains(lower),
          )
          .toList();
    }
    if (busqueda != null && busqueda.isNotEmpty) {
      final lower = busqueda.toLowerCase();
      tareas = tareas
          .where(
            (t) =>
                (t['folio'] as String).toLowerCase().contains(lower) ||
                (t['titulo'] as String).toLowerCase().contains(lower),
          )
          .toList();
    }

    final ids = tareas.map((t) => t['id'] as String).toList();
    final items = tareas
        .map(
          (t) => {
            'id': t['id'],
            'folio': t['folio'],
            'titulo': t['titulo'],
            'status': t['status'],
            'prioridad': t['prioridad'],
            'assignedToName': t['assignedToName'],
            'fechaEntrega': t['fechaEntrega'],
            'projectId': t['projectId'],
          },
        )
        .toList();

    return {
      'count': tareas.length,
      'tareas': tareas,
      '_contentBlock': AiContentBlock(
        type: AiContentType.tareas,
        text: '${tareas.length} tarea(s) encontradas',
        data: ids,
        items: items,
      ),
    };
  }

  Future<Map<String, dynamic>> _execGetSummary(
    Map<String, dynamic> args,
  ) async {
    final projectName = args['projectName'] as String;

    // Tickets activos — query simple + filtro client-side
    // (evita whereNotIn que requiere índices compuestos adicionales)
    final ticketSnap = await _db
        .collection('Incidentes')
        .where('fkxProyecto', isEqualTo: projectName)
        .get();

    const closedStatuses = {'RESUELTO', 'ARCHIVADO'};
    final statusCount = <String, int>{};
    int activeCount = 0;
    for (final doc in ticketSnap.docs) {
      final st = doc.data()['estatusIncidente'] ?? 'PENDIENTE';
      if (!closedStatuses.contains(st)) {
        statusCount[st] = (statusCount[st] ?? 0) + 1;
        activeCount++;
      }
    }

    // Requerimientos pendientes — query simple + filtro client-side
    // (evita whereIn que requiere índices compuestos adicionales)
    final reqSnap = await _db
        .collection('Requerimientos')
        .where('projectName', isEqualTo: projectName)
        .get();

    const pendingStatuses = {'Propuesto', 'En Revisión', 'En Desarrollo'};
    final pendingReqs = reqSnap.docs.where((d) {
      final data = d.data();
      if (data['isActive'] == false) return false;
      return pendingStatuses.contains(data['status'] ?? '');
    }).toList();

    // Próximas citas
    final citaSnap = await _db
        .collection('Citas')
        .where('projectName', isEqualTo: projectName)
        .where('status', isEqualTo: 'programada')
        .where('isActive', isEqualTo: true)
        .orderBy('fechaHora')
        .limit(3)
        .get();

    final citas = citaSnap.docs.map((d) {
      final data = d.data();
      return {
        'folio': data['folio'] ?? '',
        'titulo': data['titulo'] ?? '',
        'fecha':
            (data['fechaHora'] as Timestamp?)?.toDate().toIso8601String() ?? '',
      };
    }).toList();

    // Progreso
    final progress = await _execGetProgress({'projectName': projectName});

    // IDs y datos de tickets activos para renderizar cards en la UI
    final activeTicketIds = <String>[];
    final activeTicketItems = <Map<String, dynamic>>[];
    for (final doc in ticketSnap.docs) {
      final data = doc.data();
      final st = data['estatusIncidente'] ?? 'PENDIENTE';
      if (!closedStatuses.contains(st)) {
        activeTicketIds.add(doc.id);
        activeTicketItems.add({
          'id': doc.id,
          'folio': data['folioIncidente'] ?? '',
          'titulo': data['tituloIncidente'] ?? '',
          'status': st,
          'prioridad': data['prioridadIncidente'] ?? '',
        });
      }
    }

    final result = <String, dynamic>{
      'projectName': projectName,
      'ticketsActivos': activeCount,
      'ticketsPorEstado': statusCount,
      'requerimientosPendientes': pendingReqs.length,
      'proximasCitas': citas,
      'progresoGeneral': progress['overallProgress'],
      'totalModulos': progress['totalModules'],
    };

    // Agregar cards de tickets si hay activos
    if (activeTicketIds.isNotEmpty) {
      result['_contentBlock'] = AiContentBlock(
        type: AiContentType.tickets,
        text: '$activeCount ticket(s) activos',
        data: activeTicketIds,
        items: activeTicketItems,
      );
    }

    return result;
  }

  // ── System prompt (dinámico según usuario) ──

  static String _buildSystemPrompt(List<String> allowedProjects, bool isRoot) {
    final roleDesc = isRoot
        ? 'Eres administrador Root con acceso a TODOS los proyectos de la plataforma.'
        : 'Solo tienes acceso a los siguientes proyectos: ${allowedProjects.join(', ')}.';

    final projectRule = isRoot
        ? ''
        : '''

REGLA DE SEGURIDAD CRÍTICA:
- SOLO puedes consultar datos de estos proyectos: ${allowedProjects.join(', ')}.
- Si el usuario pide información de un proyecto fuera de esta lista, responde que no tiene acceso a ese proyecto.
- NUNCA intentes consultar proyectos que no estén en la lista permitida.''';

    return '''
Eres ASTRO AI, el asistente inteligente de la plataforma ASTRO para gestión de proyectos de desarrollo de software.

$roleDesc$projectRule

Tu rol:
- Ayudar a los usuarios a consultar el estado de sus proyectos, tickets, tareas, minutas, requerimientos y citas.
- Responder en español, de forma concisa y profesional.
- Usar las funciones disponibles para obtener datos reales del proyecto antes de responder.
- Cuando muestres datos, sé específico: incluye folios, estados, porcentajes.
- Si no tienes suficiente información, pregunta al usuario qué proyecto o detalle necesita.
- Si el usuario tiene un solo proyecto asignado, úsalo automáticamente sin preguntar.
- Nunca inventes datos. Si una función no retorna resultados, informa al usuario.
- Para tareas, puedes buscar por estado (pendiente, enProgreso, completada, cancelada), prioridad (baja, media, alta, urgente), asignado o texto libre.
- Si el usuario pregunta por "mis tareas" o tareas pendientes, usa buscarTareas con status pendiente o enProgreso.
- Tanto buscarTickets como buscarTareas soportan el parámetro archivados=true para buscar elementos archivados (isActive=false). Por defecto solo muestran activos.
- Si el usuario pregunta por tickets/tareas archivados, usa archivados=true.

Personalidad:
- Profesional pero amigable.
- Directo y conciso, sin rodeos.
- Proactivo: si detectas algo relevante (tickets críticos, citas próximas), menciónalo.

Formato de respuesta:
- Usa texto breve y claro.
- Cuando haya datos tabulares, resúmelos de forma legible.
- Las cards de tickets/tareas/minutas/requerimientos/citas se renderizan automáticamente en la app, solo menciónalos en tu texto de forma natural.
''';
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:astro/core/models/ai_chat_message.dart';
import 'package:astro/core/models/user_role.dart';

/// Servicio que interactúa con Gemini via Firebase AI Logic.
///
/// Usa function calling para consultar datos del proyecto y ejecutar
/// acciones dentro de la app. Solo consultas, nunca crear/editar/borrar.
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

  /// Rol global del usuario (Root si isRoot, o el rol de su primer assignment).
  String _userRole = 'Usuario';

  /// Nombre del usuario para contexto personalizado (usado en system prompt).
  // ignore: unused_field
  String _userDisplayName = '';

  /// Mapa de projectName → rol del usuario en ese proyecto.
  Map<String, UserRole> _projectRoles = {};

  /// Mapa de projectName → projectId para lookups rápidos.
  Map<String, String> _projectIdMap = {};

  /// Configura los proyectos permitidos y reinicializa el modelo
  /// con un system prompt personalizado.
  Future<void> initWithUserContext({
    required List<String> allowedProjectNames,
    required bool isRoot,
    required String userDisplayName,
    required String userRole,
    Map<String, UserRole> projectRoles = const {},
    Map<String, String> projectIdMap = const {},
  }) async {
    _allowedProjects = allowedProjectNames.toSet();
    _projectNameMap = {
      for (final name in allowedProjectNames) name.toLowerCase(): name,
    };
    _isRoot = isRoot;
    _userRole = userRole;
    _userDisplayName = userDisplayName;
    _projectRoles = Map.of(projectRoles);
    _projectIdMap = Map.of(projectIdMap);

    final prompt = _buildSystemPrompt(
      allowedProjectNames,
      isRoot,
      userDisplayName,
      userRole,
      projectRoles,
    );
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
  /// Usa matching flexible: exacto → case-insensitive → substring/parcial.
  /// Si es Root y no encuentra localmente, consulta Firestore.
  Future<String> _resolveProjectName(String input) async {
    // Coincidencia exacta
    if (_allowedProjects.contains(input)) return input;

    // Coincidencia case-insensitive en proyectos del usuario
    final lower = input.toLowerCase();
    if (_projectNameMap.containsKey(lower)) return _projectNameMap[lower]!;

    // Matching parcial/fuzzy en proyectos del usuario
    final localMatch = _fuzzyMatchLocal(lower);
    if (localMatch != null) return localMatch;

    // Para Root: buscar en Firestore
    if (_isRoot) {
      final snap = await _db
          .collection('Proyectos')
          .where('isActive', isEqualTo: true)
          .get();
      for (final doc in snap.docs) {
        final name = doc.data()['nombreProyecto'] as String? ?? '';
        final nameLower = name.toLowerCase();
        // Cachear todos los proyectos de Firestore para futuros lookups
        if (!_projectNameMap.containsKey(nameLower)) {
          _projectNameMap[nameLower] = name;
          _allowedProjects.add(name);
        }
      }
      // Re-intentar matching exacto y fuzzy con cache actualizado
      if (_projectNameMap.containsKey(lower)) return _projectNameMap[lower]!;
      final fsMatch = _fuzzyMatchLocal(lower);
      if (fsMatch != null) return fsMatch;
    }

    // Si no se resolvió, devolver el input original
    return input;
  }

  /// Matching parcial: busca en _projectNameMap por substring.
  /// Primero intenta "contains" (el input está contenido en el nombre);
  /// luego intenta que el nombre esté contenido en el input.
  /// Si hay múltiples candidatos, retorna el más corto (más específico).
  String? _fuzzyMatchLocal(String inputLower) {
    final candidates = <String>[];
    for (final entry in _projectNameMap.entries) {
      final nameLower = entry.key;
      // Input contenido en el nombre del proyecto (ej: "erp" match "ERP Personalizado")
      if (nameLower.contains(inputLower) || inputLower.contains(nameLower)) {
        candidates.add(entry.value);
      }
    }
    if (candidates.isEmpty) {
      // Intentar matching por palabras clave (ej: "ifeelmx" → "IFEELMX APP")
      final inputWords = inputLower
          .replaceAll(RegExp(r'[^a-záéíóúñü0-9]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 1)
          .toList();
      if (inputWords.isNotEmpty) {
        for (final entry in _projectNameMap.entries) {
          final nameLower = entry.key;
          final allWordsMatch = inputWords.every((w) => nameLower.contains(w));
          if (allWordsMatch) candidates.add(entry.value);
        }
      }
    }
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;
    // Múltiples: retornar el más corto (más específico)
    candidates.sort((a, b) => a.length.compareTo(b.length));
    return candidates.first;
  }

  /// Retorna la lista de nombres de proyectos disponibles para el usuario.
  List<String> get _availableProjectNames => _allowedProjects.toList()..sort();

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
    'Busca tickets/incidentes de un proyecto. Puede filtrar por estado, prioridad o texto. Retorna fechaCompromiso (fecha de compromiso de solución). Por defecto solo busca activos; usa archivados=true para buscar en los archivados.',
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
    try {
      // ── Resolver y validar nombre del proyecto ──
      final rawName = args['projectName'] as String?;
      if (rawName != null) {
        final resolved = await _resolveProjectName(rawName);
        args = {...args, 'projectName': resolved};

        // Validar acceso al proyecto
        if (!_isProjectAllowed(resolved)) {
          return {
            'error':
                'No tienes permisos para consultar el proyecto "$rawName".',
            'allowed': false,
            'proyectosDisponibles': _availableProjectNames,
            'sugerencia':
                'Tu acceso está limitado a: ${_availableProjectNames.join(", ")}.',
          };
        }

        // Verificar que el proyecto exista en Firestore
        final exists = await _projectExistsInFirestore(resolved);
        if (!exists) {
          return {
            'error': 'El proyecto "$rawName" no fue encontrado.',
            'proyectosDisponibles': _availableProjectNames,
            'sugerencia':
                'Los proyectos disponibles son: ${_availableProjectNames.join(", ")}. ¿Cuál necesitas consultar?',
          };
        }

        // Inyectar contexto de rol del usuario en este proyecto
        final roleInProject = _getUserRoleInProject(resolved);
        args = {...args, '_userRole': roleInProject};
      }

      switch (name) {
        case 'buscarTickets':
          return await _execSearchTickets(args);
        case 'obtenerProgresoProyecto':
          return await _execGetProgress(args);
        case 'buscarMinutas':
          return await _execSearchMinutas(args);
        case 'buscarRequerimientos':
          return await _execSearchRequerimientos(args);
        case 'buscarCitas':
          return await _execSearchCitas(args);
        case 'buscarTareas':
          return await _execSearchTareas(args);
        case 'obtenerResumenProyecto':
          return await _execGetSummary(args);
        default:
          return {'error': 'Función no reconocida: $name'};
      }
    } catch (e) {
      return {
        'error': 'Error al ejecutar la consulta: $e',
        'proyectosDisponibles': _availableProjectNames,
      };
    }
  }

  /// Obtiene el rol del usuario en un proyecto específico.
  String _getUserRoleInProject(String projectName) {
    if (_isRoot) return 'Root';
    final role = _projectRoles[projectName];
    if (role != null) return role.label;
    // Intentar por projectId
    final pid = _projectIdMap[projectName];
    if (pid != null) {
      for (final entry in _projectRoles.entries) {
        if (_projectIdMap[entry.key] == pid) return entry.value.label;
      }
    }
    return _userRole;
  }

  /// Verifica si un proyecto con ese nombre exacto existe en Firestore.
  /// Cachea resultados positivos para evitar queries repetidas.
  final Set<String> _verifiedProjects = {};
  Future<bool> _projectExistsInFirestore(String projectName) async {
    if (_verifiedProjects.contains(projectName)) return true;
    final snap = await _db
        .collection('Proyectos')
        .where('nombreProyecto', isEqualTo: projectName)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      _verifiedProjects.add(projectName);
      return true;
    }
    return false;
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
        'fechaCompromiso': data['fhCompromisoSol'] as String? ?? '',
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
        .orderBy('fecha', descending: true)
        .limit(limit)
        .get();

    final citas = snap.docs.map((d) {
      final data = d.data();
      final fechaTs =
          data['fecha'] as Timestamp? ?? data['fechaHora'] as Timestamp?;
      return {
        'id': d.id,
        'folio': data['folio'] ?? '',
        'titulo': data['titulo'] ?? '',
        'status': data['status'] ?? '',
        'fecha': fechaTs?.toDate().toIso8601String() ?? '',
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
        .orderBy('fecha')
        .limit(3)
        .get();

    final citas = citaSnap.docs.map((d) {
      final data = d.data();
      final fechaTs =
          data['fecha'] as Timestamp? ?? data['fechaHora'] as Timestamp?;
      return {
        'folio': data['folio'] ?? '',
        'titulo': data['titulo'] ?? '',
        'fecha': fechaTs?.toDate().toIso8601String() ?? '',
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

  static String _buildSystemPrompt(
    List<String> allowedProjects,
    bool isRoot,
    String userDisplayName,
    String userRole,
    Map<String, UserRole> projectRoles,
  ) {
    final greeting = userDisplayName.isNotEmpty
        ? 'El usuario se llama **$userDisplayName**.'
        : '';

    final roleDesc = isRoot
        ? 'Este usuario es **Root** (administrador) con acceso total a TODOS los proyectos.'
        : 'Este usuario tiene rol **$userRole**.';

    final projectList = allowedProjects.isEmpty
        ? 'Este usuario no tiene proyectos asignados aún.'
        : 'Proyectos asignados: ${allowedProjects.map((p) {
            final r = projectRoles[p]?.label ?? userRole;
            return '$p (rol: $r)';
          }).join(', ')}.';

    final securityRules = isRoot
        ? ''
        : '''

═══ SEGURIDAD Y PERMISOS ═══
- Este usuario SOLO tiene acceso a: ${allowedProjects.join(', ')}.
- Si pide info de otro proyecto → responde amablemente que no tiene acceso y muéstrale sus proyectos.
- NUNCA consultes datos de proyectos no autorizados.
- Roles por proyecto:
${allowedProjects.map((p) {
            final r = projectRoles[p]?.label ?? userRole;
            return '  • $p → $r';
          }).join('\n')}

Permisos por rol:
  • Supervisor: Ve todo el proyecto, progreso de usuarios, reporta tickets, participa en minutas.
  • Usuario: Solo ve sus propios tickets, sus tareas, participa en minutas.
  • Soporte: Ve todo del proyecto asignado, da soporte a tickets, levanta requerimientos.''';

    return '''
═══ IDENTIDAD ═══
Eres ASTRO AI, el asistente inteligente de la plataforma ASTRO.
Eres un facilitador PRO de atención al cliente para gestión de proyectos de software.

$greeting
$roleDesc
$projectList
$securityRules

═══ MODO DE OPERACIÓN: SOLO CONSULTAS ═══
- Tu función es EXCLUSIVAMENTE de consulta. NUNCA puedes crear, editar ni eliminar datos.
- Si el usuario pide crear un ticket, modificar una tarea, borrar algo, etc. → responde amablemente que esas acciones se realizan directamente en la app, no a través del asistente.
- Eres un facilitador: ayudas a encontrar información rápidamente.

═══ FLUJO DE ATENCIÓN AL CLIENTE ═══
1. Si el usuario tiene UN SOLO proyecto → úsalo automáticamente, no preguntes.
2. Si tiene MÚLTIPLES proyectos y no especifica cuál → pregunta: "¿Sobre cuál proyecto necesitas información?" y LISTA los proyectos disponibles.
3. Si el nombre del proyecto no coincide exactamente → el sistema hace matching flexible ("ERP" → "ERP Personalizado", "ifeelmx" → "IFEELMX APP").
4. Si aún así no se encuentra → muestra SIEMPRE la lista de proyectos disponibles y pide que elija.
5. Una vez identificado el proyecto → ejecuta la consulta y muestra resultados con tarjetas.
6. Si no hay resultados → informa claramente: "No se encontraron [tickets/tareas/etc.] en [proyecto]." Sin inventar datos.
7. Sé proactivo: si encuentras algo relevante (tickets críticos, citas hoy, tareas vencidas), menciónalo.

═══ REGLAS DE FILTROS (CRÍTICO) ═══
- NO agregues filtros de status/prioridad a menos que el usuario lo pida EXPLÍCITAMENTE.
- Ejemplos:
  • "Hay tickets?" → buscarTickets SIN filtro (todos los activos)
  • "Hay tickets pendientes?" → buscarTickets CON status=PENDIENTE
  • "Hay nuevos tickets?" → buscarTickets SIN filtro ("nuevos" NO es un estado)
  • "Hay tareas?" → buscarTareas SIN filtro
  • "Hay tareas pendientes?" → buscarTareas CON status=pendiente
  • "Tickets de alta prioridad" → buscarTickets CON prioridad=alta

═══ DATOS TÉCNICOS DE REFERENCIA ═══
Estados de tickets: PENDIENTE, EN_DESARROLLO, PRUEBAS_INTERNAS, PRUEBAS_CLIENTE, BUGS, RESUELTO, ARCHIVADO
Estados de tareas: pendiente, enProgreso, completada, cancelada
Prioridades de tareas: baja, media, alta, urgente
Prioridades de tickets: baja, normal, alta, critica
Estados de requerimientos: Propuesto, En Revisión, En Desarrollo, Implementado, Completado, Descartado
Estados de citas: programada, enCurso, completada, cancelada
- archivados=true → busca en inactivos (isActive=false). Por defecto busca activos.
- fechaCompromiso en tickets: fecha de compromiso de solución (vacío = no asignada).
- "mis tareas" → buscarTareas (status pendiente o enProgreso)

═══ PERSONALIDAD ═══
- Profesional, amigable y servicial.
- Conciso: ve al grano, sin rodeos innecesarios.
- Proactivo: si detectas tickets urgentes, citas próximas o tareas vencidas, menciónalo.
- Cuando muestres datos, incluye folios, estados y porcentajes.
- Las tarjetas (cards) de tickets/tareas/minutas/requerimientos/citas se renderizan automáticamente en la app. Menciónalos de forma natural en tu texto.
- Si el usuario saluda, responde cordialmente y ofrece ayuda: "¡Hola${userDisplayName.isNotEmpty ? ' $userDisplayName' : ''}! ¿En qué puedo ayudarte hoy?"
''';
  }
}

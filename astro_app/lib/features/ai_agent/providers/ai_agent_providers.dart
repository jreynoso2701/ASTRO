import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/ai_chat_message.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/features/ai_agent/data/ai_chat_repository.dart';
import 'package:astro/features/ai_agent/data/gemini_service.dart';
import 'package:astro/features/ai_agent/data/voice_service.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

// ── Repositories & Services ─────────────────────────────

final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  return AiChatRepository();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ── Chat messages stream ────────────────────────────────

final aiChatMessagesProvider = StreamProvider<List<AiChatMessage>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(aiChatRepositoryProvider).watchMessages(uid);
});

// ── Chat notifier (maneja estado del agente) ────────────

final aiChatNotifierProvider = NotifierProvider<AiChatNotifier, AiChatState>(
  AiChatNotifier.new,
);

class AiChatState {
  const AiChatState({
    this.isLoading = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.autoSpeak = true,
    this.error,
  });

  final bool isLoading;
  final bool isListening;
  final bool isSpeaking;
  final bool autoSpeak;
  final String? error;

  AiChatState copyWith({
    bool? isLoading,
    bool? isListening,
    bool? isSpeaking,
    bool? autoSpeak,
    String? error,
  }) {
    return AiChatState(
      isLoading: isLoading ?? this.isLoading,
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      autoSpeak: autoSpeak ?? this.autoSpeak,
      error: error,
    );
  }
}

class AiChatNotifier extends Notifier<AiChatState> {
  @override
  AiChatState build() => const AiChatState();

  bool _geminiReady = false;

  /// Asegura que Gemini esté inicializado con el contexto del usuario.
  Future<void> _ensureGeminiReady() async {
    if (_geminiReady) return;

    final gemini = ref.read(geminiServiceProvider);
    final isRoot = ref.read(isCurrentUserRootProvider);
    final myProjects = ref.read(myProjectsProvider);
    final profile = ref.read(currentUserProfileProvider).value;
    final uid = ref.read(authStateProvider).value?.uid;

    final projectNames = myProjects.map((p) => p.nombreProyecto).toList();

    // Obtener rol y nombre del usuario
    final userDisplayName = profile?.displayName ?? '';
    String userRole = isRoot ? 'Root' : 'Usuario';

    // Construir mapa projectName → rol y projectName → projectId
    final Map<String, UserRole> projectRoles = {};
    final Map<String, String> projectIdMap = {};

    if (uid != null) {
      final assignmentsAsync = ref.read(userAssignmentsProvider(uid));
      final assignments = assignmentsAsync.value ?? [];

      for (final project in myProjects) {
        projectIdMap[project.nombreProyecto] = project.id;
        // Buscar assignment de este usuario en este proyecto
        final assignment = assignments
            .where((a) => a.projectId == project.id && a.isActive)
            .firstOrNull;
        if (assignment != null) {
          projectRoles[project.nombreProyecto] = assignment.role;
          // Usar el primer rol encontrado como userRole si no es Root
          if (!isRoot && userRole == 'Usuario') {
            userRole = assignment.role.label;
          }
        }
      }
    }

    await gemini.initWithUserContext(
      allowedProjectNames: projectNames,
      isRoot: isRoot,
      userDisplayName: userDisplayName,
      userRole: userRole,
      projectRoles: projectRoles,
      projectIdMap: projectIdMap,
    );
    _geminiReady = true;
  }

  /// Envía un mensaje de texto al agente.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final repo = ref.read(aiChatRepositoryProvider);
    final gemini = ref.read(geminiServiceProvider);
    final voice = ref.read(voiceServiceProvider);

    // Detener TTS activo antes de procesar nuevo mensaje
    if (state.isSpeaking) {
      await voice.stop();
      state = state.copyWith(isSpeaking: false);
    }

    // Inicializar Gemini con contexto de usuario si no se ha hecho
    await _ensureGeminiReady();

    // Guardar mensaje del usuario
    await repo.addMessage(
      AiChatMessage(
        id: '',
        userId: uid,
        role: AiMessageRole.user,
        content: [AiContentBlock(type: AiContentType.text, text: text)],
        createdAt: DateTime.now(),
      ),
    );

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Obtener respuesta de Gemini
      final responseBlocks = await gemini.sendMessage(text, userId: uid);

      // Guardar respuesta del asistente
      await repo.addMessage(
        AiChatMessage(
          id: '',
          userId: uid,
          role: AiMessageRole.assistant,
          content: responseBlocks,
          createdAt: DateTime.now(),
        ),
      );

      state = state.copyWith(isLoading: false);

      // Auto-speak la respuesta de texto
      if (state.autoSpeak) {
        final textContent = responseBlocks
            .where((b) => b.type == AiContentType.text)
            .map((b) => b.text)
            .join('. ');
        if (textContent.isNotEmpty) {
          state = state.copyWith(isSpeaking: true);
          await voice.speak(textContent);
          state = state.copyWith(isSpeaking: false);
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al comunicarse con el agente: $e',
      );
    }
  }

  /// Reproduce la voz de un mensaje específico.
  Future<void> speakMessage(AiChatMessage message) async {
    final voice = ref.read(voiceServiceProvider);
    final textContent = message.content
        .where((b) => b.type == AiContentType.text)
        .map((b) => b.text)
        .join('. ');
    if (textContent.isEmpty) return;

    state = state.copyWith(isSpeaking: true);
    await voice.speak(textContent);
    state = state.copyWith(isSpeaking: false);
  }

  /// Detiene la voz actual.
  Future<void> stopSpeaking() async {
    final voice = ref.read(voiceServiceProvider);
    await voice.stop();
    state = state.copyWith(isSpeaking: false);
  }

  /// Inicia escucha de voz (STT).
  Future<void> startListening() async {
    final voice = ref.read(voiceServiceProvider);
    state = state.copyWith(isListening: true);

    await voice.startListening(
      onResult: (text, isFinal) {
        if (isFinal && text.isNotEmpty) {
          state = state.copyWith(isListening: false);
          sendMessage(text);
        }
      },
    );
  }

  /// Detiene escucha de voz.
  Future<void> stopListening() async {
    final voice = ref.read(voiceServiceProvider);
    await voice.stopListening();
    state = state.copyWith(isListening: false);
  }

  /// Toggle auto-speak.
  void toggleAutoSpeak() {
    final newAutoSpeak = !state.autoSpeak;
    state = state.copyWith(autoSpeak: newAutoSpeak);
    // Si se desactiva y está hablando, detener TTS inmediatamente
    if (!newAutoSpeak && state.isSpeaking) {
      stopSpeaking();
    }
  }

  /// Elimina todo el historial de chat.
  Future<void> clearHistory() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final repo = ref.read(aiChatRepositoryProvider);
    final gemini = ref.read(geminiServiceProvider);
    await repo.clearHistory(uid);
    // Reiniciar la sesión de Gemini y forzar re-init con contexto
    gemini.startChat();
    _geminiReady = false;
  }
}

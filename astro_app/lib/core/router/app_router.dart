import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/router/app_shell.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/auth/presentation/screens/login_screen.dart';
import 'package:astro/features/auth/presentation/screens/register_screen.dart';
import 'package:astro/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:astro/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:astro/features/users/presentation/screens/user_list_screen.dart';
import 'package:astro/features/users/presentation/screens/user_detail_screen.dart';
import 'package:astro/features/users/presentation/screens/assign_project_screen.dart';
import 'package:astro/features/projects/presentation/screens/project_list_screen.dart';
import 'package:astro/features/projects/presentation/screens/project_detail_screen.dart';
import 'package:astro/features/projects/presentation/screens/project_form_screen.dart';
import 'package:astro/features/modules/presentation/screens/module_list_screen.dart';
import 'package:astro/features/modules/presentation/screens/module_detail_screen.dart';
import 'package:astro/features/modules/presentation/screens/module_form_screen.dart';
import 'package:astro/features/tickets/presentation/screens/ticket_list_screen.dart';
import 'package:astro/features/tickets/presentation/screens/ticket_detail_screen.dart';
import 'package:astro/features/tickets/presentation/screens/ticket_form_screen.dart';
import 'package:astro/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:astro/features/auth/presentation/screens/pending_approval_screen.dart';
import 'package:astro/features/auth/presentation/screens/rejection_screen.dart';
import 'package:astro/features/auth/presentation/screens/deactivated_screen.dart';
import 'package:astro/features/auth/presentation/screens/loading_screen.dart';
import 'package:astro/features/users/presentation/screens/registration_requests_screen.dart';
import 'package:astro/features/requirements/presentation/screens/requerimiento_list_screen.dart';
import 'package:astro/features/requirements/presentation/screens/requerimiento_detail_screen.dart';
import 'package:astro/features/requirements/presentation/screens/requerimiento_form_screen.dart';
import 'package:astro/features/notifications/presentation/screens/notification_inbox_screen.dart';
import 'package:astro/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:astro/features/documentation/presentation/screens/documento_list_screen.dart';
import 'package:astro/features/documentation/presentation/screens/documento_detail_screen.dart';
import 'package:astro/features/documentation/presentation/screens/documento_form_screen.dart';
import 'package:astro/features/documentation/presentation/screens/bitacora_screen.dart';
import 'package:astro/features/documentation/presentation/screens/categorias_screen.dart';
import 'package:astro/features/minutas/presentation/screens/minuta_list_screen.dart';
import 'package:astro/features/minutas/presentation/screens/minuta_detail_screen.dart';
import 'package:astro/features/minutas/presentation/screens/minuta_form_screen.dart';
import 'package:astro/features/citas/presentation/screens/cita_list_screen.dart';
import 'package:astro/features/citas/presentation/screens/cita_detail_screen.dart';
import 'package:astro/features/citas/presentation/screens/cita_form_screen.dart';
import 'package:astro/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:astro/features/profile/presentation/screens/profile_screen.dart';
import 'package:astro/features/profile/presentation/screens/about_screen.dart';
import 'package:astro/features/empresas/presentation/screens/empresa_list_screen.dart';
import 'package:astro/features/empresas/presentation/screens/empresa_detail_screen.dart';
import 'package:astro/features/empresas/presentation/screens/empresa_form_screen.dart';
import 'package:astro/features/gestion/presentation/screens/gestion_screen.dart';
import 'package:astro/features/tareas/presentation/screens/tareas_list_screen.dart';
import 'package:astro/features/tareas/presentation/screens/tareas_global_screen.dart';
import 'package:astro/features/tareas/presentation/screens/tarea_detail_screen.dart';
import 'package:astro/features/tareas/presentation/screens/tarea_form_screen.dart';
import 'package:astro/features/avisos/presentation/screens/aviso_list_screen.dart';
import 'package:astro/features/avisos/presentation/screens/aviso_detail_screen.dart';
import 'package:astro/features/avisos/presentation/screens/aviso_form_screen.dart';

/// Rutas nombradas.
abstract final class AppRoutes {
  static const String dashboard = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';
  static const String users = '/users';
  static const String userDetail = '/users/:uid';
  static const String userAssign = '/users/:uid/assign';
  static const String projects = '/projects';
  static const String projectNew = '/projects/new';
  static const String projectDetail = '/projects/:id';
  static const String projectEdit = '/projects/:id/edit';
  static const String projectModules = '/projects/:id/modules';
  static const String moduleNew = '/projects/:id/modules/new';
  static const String moduleDetail = '/projects/:id/modules/:moduleId';
  static const String moduleEdit = '/projects/:id/modules/:moduleId/edit';
  static const String projectTickets = '/projects/:id/tickets';
  static const String ticketNew = '/projects/:id/tickets/new';
  static const String ticketDetail = '/projects/:id/tickets/:ticketId';
  static const String ticketEdit = '/projects/:id/tickets/:ticketId/edit';
  static const String projectRequirements = '/projects/:id/requirements';
  static const String reqNew = '/projects/:id/requirements/new';
  static const String reqDetail = '/projects/:id/requirements/:reqId';
  static const String reqEdit = '/projects/:id/requirements/:reqId/edit';
  static const String notifications = '/notifications';
  static const String projectNotifSettings =
      '/projects/:id/notification-settings';
  static const String projectDocuments = '/projects/:id/documents';
  static const String documentNew = '/projects/:id/documents/new';
  static const String documentDetail = '/projects/:id/documents/:docId';
  static const String documentEdit = '/projects/:id/documents/:docId/edit';
  static const String documentLog = '/projects/:id/documents/log';
  static const String documentCategories = '/projects/:id/documents/categories';

  // Minutas
  static const String projectMinutas = '/projects/:id/minutas';
  static const String minutaNew = '/projects/:id/minutas/new';
  static const String minutaDetail = '/projects/:id/minutas/:minutaId';
  static const String minutaEdit = '/projects/:id/minutas/:minutaId/edit';

  // Tareas
  static const String tareas = '/tareas';
  static const String projectTareas = '/projects/:id/tareas';
  static const String tareaNew = '/projects/:id/tareas/new';
  static const String tareaDetail = '/projects/:id/tareas/:tareaId';
  static const String tareaEdit = '/projects/:id/tareas/:tareaId/edit';

  // Calendario global
  static const String calendar = '/calendar';

  // Citas
  static const String projectCitas = '/projects/:id/citas';
  static const String citaNew = '/projects/:id/citas/new';
  static const String citaDetail = '/projects/:id/citas/:citaId';
  static const String citaEdit = '/projects/:id/citas/:citaId/edit';

  // Avisos
  static const String projectAvisos = '/projects/:id/avisos';
  static const String avisoNew = '/projects/:id/avisos/new';
  static const String avisoDetail = '/projects/:id/avisos/:avisoId';
  static const String avisoEdit = '/projects/:id/avisos/:avisoId/edit';

  // Perfil
  static const String profile = '/profile';
  static const String about = '/about';

  // Gestión (hub)
  static const String gestion = '/gestion';
  static const String registrationRequests = '/gestion/requests';

  // Empresas
  static const String empresas = '/empresas';
  static const String empresaNew = '/empresas/new';
  static const String empresaDetail = '/empresas/:empresaId';
  static const String empresaEdit = '/empresas/:empresaId/edit';

  // Pantallas de estado de registro (sin shell)
  static const String pendingApproval = '/pending-approval';
  static const String rejected = '/rejected';
  static const String deactivated = '/deactivated';

  // Pantalla de carga inicial
  static const String loading = '/loading';
}

/// Notifier que dispara re-evaluación de redirects cuando cambia el estado
/// de auth o perfil (sin recrear el GoRouter).
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProfileProvider, (_, __) => notifyListeners());
    ref.listen(hasProjectAssignmentsProvider, (_, __) => notifyListeners());
  }
}

/// Provider del router — se crea UNA sola vez.
/// Los cambios de auth/perfil disparan re-evaluación de redirects via
/// refreshListenable, sin destruir y recrear el GoRouter.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  ref.onDispose(() => refreshNotifier.dispose());

  return GoRouter(
    initialLocation: AppRoutes.loading,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final userProfile = ref.read(currentUserProfileProvider);

      final isLoggedIn = authState.value != null;
      final isAuthRoute =
          state.uri.path == AppRoutes.login ||
          state.uri.path == AppRoutes.register ||
          state.uri.path == AppRoutes.forgotPassword;
      final isLoadingRoute = state.uri.path == AppRoutes.loading;

      // ── Mientras auth o perfil cargan → mantener en /loading ──
      if (authState.isLoading) {
        return isLoadingRoute ? null : AppRoutes.loading;
      }
      if (isLoggedIn && userProfile.isLoading) {
        return isLoadingRoute ? null : AppRoutes.loading;
      }

      // ── Auth y perfil resueltos ──

      // No autenticado → redirigir a login (excepto si ya está en auth).
      if (!isLoggedIn) {
        return isAuthRoute ? null : AppRoutes.login;
      }

      // Autenticado → no permitir acceder a pantallas de auth ni loading.
      if (isAuthRoute || isLoadingRoute) {
        final user = userProfile.value;
        if (user != null) {
          if (!user.isActive) return AppRoutes.deactivated;
          if (user.isPending) return AppRoutes.pendingApproval;
          if (user.isRejected) return AppRoutes.rejected;
        }
        return AppRoutes.dashboard;
      }

      // ── Guards de estado de cuenta ─────────────────
      final user = userProfile.value;
      if (user != null) {
        final isPending = user.isPending;
        final isRejected = user.isRejected;
        final isDeactivated = !user.isActive;
        final isStatusRoute =
            state.uri.path == AppRoutes.pendingApproval ||
            state.uri.path == AppRoutes.rejected ||
            state.uri.path == AppRoutes.deactivated;

        // Desactivado → forzar pantalla de cuenta desactivada.
        if (isDeactivated && state.uri.path != AppRoutes.deactivated) {
          return AppRoutes.deactivated;
        }
        // Reactivado → salir de la pantalla de desactivado.
        if (!isDeactivated && state.uri.path == AppRoutes.deactivated) {
          return AppRoutes.dashboard;
        }

        // Pendiente → forzar pantalla de espera.
        if (isPending && state.uri.path != AppRoutes.pendingApproval) {
          return AppRoutes.pendingApproval;
        }
        // Ya no está pendiente → salir de la pantalla de espera.
        if (!isPending && state.uri.path == AppRoutes.pendingApproval) {
          return isRejected ? AppRoutes.rejected : AppRoutes.dashboard;
        }

        // Rechazado → forzar pantalla de rechazo.
        if (isRejected && state.uri.path != AppRoutes.rejected) {
          return AppRoutes.rejected;
        }
        // Ya no está rechazado → salir de la pantalla de rechazo.
        if (!isRejected && state.uri.path == AppRoutes.rejected) {
          return AppRoutes.dashboard;
        }

        // Si está en ruta de status y ya está aprobado+activo, redirigir.
        if (user.isApproved && user.isActive && isStatusRoute) {
          return AppRoutes.dashboard;
        }
      }

      // Onboarding: usuario sin asignaciones (excepto Root).
      // No aplica a usuarios pendientes o rechazados (ya redirigidos arriba).
      if (state.uri.path != AppRoutes.onboarding &&
          state.uri.path != AppRoutes.profile &&
          state.uri.path != AppRoutes.pendingApproval &&
          state.uri.path != AppRoutes.rejected &&
          state.uri.path != AppRoutes.deactivated) {
        final u = userProfile.value;
        if (u != null && u.isApproved) {
          final hasAssignments = ref.read(hasProjectAssignmentsProvider);
          if (hasAssignments == false) return AppRoutes.onboarding;
        }
      }

      // Ya tiene asignaciones → no permitir acceder a onboarding.
      if (state.uri.path == AppRoutes.onboarding) {
        final hasAssignments = ref.read(hasProjectAssignmentsProvider);
        if (hasAssignments == true) return AppRoutes.dashboard;
      }

      // Guardia de rol: /users solo para Root.
      if (state.uri.path.startsWith('/users')) {
        if (!userProfile.isLoading && !(userProfile.value?.isRoot ?? false)) {
          return AppRoutes.dashboard;
        }
      }

      // Guardia de rol: /empresas solo para Root.
      if (state.uri.path.startsWith('/empresas')) {
        if (!userProfile.isLoading && !(userProfile.value?.isRoot ?? false)) {
          return AppRoutes.dashboard;
        }
      }

      // Guardia de rol: /gestion/requests solo para Root.
      if (state.uri.path == AppRoutes.registrationRequests) {
        if (!userProfile.isLoading && !(userProfile.value?.isRoot ?? false)) {
          return AppRoutes.dashboard;
        }
      }

      return null;
    },
    routes: [
      // ── Pantalla de carga (sin shell)
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => const LoadingScreen(),
      ),

      // ── Rutas de autenticación (sin shell)
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.pendingApproval,
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: AppRoutes.rejected,
        builder: (context, state) => const RejectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.deactivated,
        builder: (context, state) => const DeactivatedScreen(),
      ),

      // ── Perfil (sin shell — tiene su propio AppBar)
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutScreen(),
      ),

      // ── Rutas protegidas (con shell adaptativo)
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.tareas,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TareasGlobalScreen()),
          ),
          GoRoute(
            path: AppRoutes.gestion,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: GestionScreen()),
          ),
          GoRoute(
            path: AppRoutes.users,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: UserListScreen()),
          ),
          GoRoute(
            path: AppRoutes.empresas,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmpresaListScreen()),
          ),
          GoRoute(
            path: AppRoutes.projects,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProjectListScreen()),
          ),
          GoRoute(
            path: AppRoutes.calendar,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CalendarScreen()),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NotificationInboxScreen()),
          ),
        ],
      ),

      // ── Rutas de detalle (sin shell — tienen su propio AppBar)

      // Solicitudes de registro (solo Root)
      GoRoute(
        path: AppRoutes.registrationRequests,
        builder: (context, state) => const RegistrationRequestsScreen(),
      ),

      // Empresas (más específicas primero)
      GoRoute(
        path: AppRoutes.empresaNew,
        builder: (context, state) => const EmpresaFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.empresaEdit,
        builder: (context, state) =>
            EmpresaFormScreen(empresaId: state.pathParameters['empresaId']!),
      ),
      GoRoute(
        path: AppRoutes.empresaDetail,
        builder: (context, state) =>
            EmpresaDetailScreen(empresaId: state.pathParameters['empresaId']!),
      ),

      GoRoute(
        path: AppRoutes.userDetail,
        builder: (context, state) =>
            UserDetailScreen(userId: state.pathParameters['uid']!),
      ),
      GoRoute(
        path: AppRoutes.userAssign,
        builder: (context, state) =>
            AssignProjectScreen(userId: state.pathParameters['uid']!),
      ),
      GoRoute(
        path: AppRoutes.projectNew,
        builder: (context, state) => const ProjectFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.projectEdit,
        builder: (context, state) =>
            ProjectFormScreen(projectId: state.pathParameters['id']!),
      ),

      // ── Rutas de tickets (más específicas primero)
      GoRoute(
        path: AppRoutes.projectNotifSettings,
        builder: (context, state) =>
            NotificationSettingsScreen(projectId: state.pathParameters['id']!),
      ),

      // ── Rutas de documentación (más específicas primero)
      GoRoute(
        path: AppRoutes.documentNew,
        builder: (context, state) =>
            DocumentoFormScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.documentLog,
        builder: (context, state) =>
            BitacoraScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.documentCategories,
        builder: (context, state) =>
            CategoriasScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.documentEdit,
        builder: (context, state) => DocumentoFormScreen(
          projectId: state.pathParameters['id']!,
          documentId: state.pathParameters['docId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.documentDetail,
        builder: (context, state) => DocumentoDetailScreen(
          projectId: state.pathParameters['id']!,
          documentId: state.pathParameters['docId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.projectDocuments,
        builder: (context, state) =>
            DocumentoListScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.ticketNew,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return TicketFormScreen(
            projectId: state.pathParameters['id']!,
            returnId: extra?['returnId'] as bool? ?? false,
            refCitaId: extra?['refCitaId'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.ticketEdit,
        builder: (context, state) => TicketFormScreen(
          projectId: state.pathParameters['id']!,
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.ticketDetail,
        builder: (context, state) => TicketDetailScreen(
          projectId: state.pathParameters['id']!,
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.projectTickets,
        builder: (context, state) =>
            TicketListScreen(projectId: state.pathParameters['id']!),
      ),

      // ── Rutas de requerimientos (más específicas primero)
      GoRoute(
        path: AppRoutes.reqNew,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return RequerimientoFormScreen(
            projectId: state.pathParameters['id']!,
            returnId: extra?['returnId'] as bool? ?? false,
            refCitaId: extra?['refCitaId'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.reqEdit,
        builder: (context, state) => RequerimientoFormScreen(
          projectId: state.pathParameters['id']!,
          reqId: state.pathParameters['reqId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.reqDetail,
        builder: (context, state) => RequerimientoDetailScreen(
          projectId: state.pathParameters['id']!,
          reqId: state.pathParameters['reqId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.projectRequirements,
        builder: (context, state) =>
            RequerimientoListScreen(projectId: state.pathParameters['id']!),
      ),

      // ── Rutas de minutas (más específicas primero)
      GoRoute(
        path: AppRoutes.minutaNew,
        builder: (context, state) => MinutaFormScreen(
          projectId: state.pathParameters['id']!,
          citaId: state.uri.queryParameters['refCitaId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.minutaEdit,
        builder: (context, state) => MinutaFormScreen(
          projectId: state.pathParameters['id']!,
          minutaId: state.pathParameters['minutaId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.minutaDetail,
        builder: (context, state) => MinutaDetailScreen(
          projectId: state.pathParameters['id']!,
          minutaId: state.pathParameters['minutaId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.projectMinutas,
        builder: (context, state) =>
            MinutaListScreen(projectId: state.pathParameters['id']!),
      ),

      // ── Rutas de citas (más específicas primero)
      GoRoute(
        path: AppRoutes.citaNew,
        builder: (context, state) =>
            CitaFormScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.citaEdit,
        builder: (context, state) => CitaFormScreen(
          projectId: state.pathParameters['id']!,
          citaId: state.pathParameters['citaId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.citaDetail,
        builder: (context, state) => CitaDetailScreen(
          projectId: state.pathParameters['id']!,
          citaId: state.pathParameters['citaId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.projectCitas,
        builder: (context, state) =>
            CitaListScreen(projectId: state.pathParameters['id']!),
      ),

      // ── Rutas de avisos (más específicas primero)
      GoRoute(
        path: AppRoutes.avisoNew,
        builder: (context, state) =>
            AvisoFormScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.avisoEdit,
        builder: (context, state) => AvisoFormScreen(
          projectId: state.pathParameters['id']!,
          avisoId: state.pathParameters['avisoId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.avisoDetail,
        builder: (context, state) => AvisoDetailScreen(
          projectId: state.pathParameters['id']!,
          avisoId: state.pathParameters['avisoId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.projectAvisos,
        builder: (context, state) =>
            AvisoListScreen(projectId: state.pathParameters['id']!),
      ),

      // ── Rutas de tareas (más específicas primero)
      GoRoute(
        path: AppRoutes.tareaNew,
        builder: (context, state) {
          final qp = state.uri.queryParameters;
          return TareaFormScreen(
            projectId: state.pathParameters['id']!,
            initialRefMinutaId: qp['refMinutaId'],
            initialRefCompromisoNumero: int.tryParse(
              qp['refCompromisoNumero'] ?? '',
            ),
            initialTitulo: qp['titulo'],
            initialDescripcion: qp['descripcion'],
            initialAssignedToUid: qp['assignedToUid']?.isNotEmpty == true
                ? qp['assignedToUid']
                : null,
            initialAssignedToName: qp['assignedToName']?.isNotEmpty == true
                ? qp['assignedToName']
                : null,
            initialFechaEntrega: qp['fechaEntrega']?.isNotEmpty == true
                ? DateTime.tryParse(qp['fechaEntrega']!)
                : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.tareaEdit,
        builder: (context, state) => TareaFormScreen(
          projectId: state.pathParameters['id']!,
          tareaId: state.pathParameters['tareaId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.tareaDetail,
        builder: (context, state) => TareaDetailScreen(
          projectId: state.pathParameters['id']!,
          tareaId: state.pathParameters['tareaId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.projectTareas,
        builder: (context, state) =>
            TareasListScreen(projectId: state.pathParameters['id']!),
      ),

      // ── Rutas de módulos (más específicas primero)
      GoRoute(
        path: AppRoutes.moduleNew,
        builder: (context, state) =>
            ModuleFormScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.moduleEdit,
        builder: (context, state) => ModuleFormScreen(
          projectId: state.pathParameters['id']!,
          moduleId: state.pathParameters['moduleId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.moduleDetail,
        builder: (context, state) => ModuleDetailScreen(
          projectId: state.pathParameters['id']!,
          moduleId: state.pathParameters['moduleId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.projectModules,
        builder: (context, state) =>
            ModuleListScreen(projectId: state.pathParameters['id']!),
      ),

      // ── Detalle de proyecto (al final porque :id matchea cualquier cosa)
      GoRoute(
        path: AppRoutes.projectDetail,
        builder: (context, state) =>
            ProjectDetailScreen(projectId: state.pathParameters['id']!),
      ),
    ],
  );
});

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

  // Calendario global
  static const String calendar = '/calendar';

  // Citas
  static const String projectCitas = '/projects/:id/citas';
  static const String citaNew = '/projects/:id/citas/new';
  static const String citaDetail = '/projects/:id/citas/:citaId';
  static const String citaEdit = '/projects/:id/citas/:citaId/edit';

  // Perfil
  static const String profile = '/profile';
}

/// Provider del router — depende del estado de autenticación.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfile = ref.watch(currentUserProfileProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isAuthRoute =
          state.uri.path == AppRoutes.login ||
          state.uri.path == AppRoutes.register ||
          state.uri.path == AppRoutes.forgotPassword;

      // No autenticado → redirigir a login (excepto si ya está en auth).
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;

      // Autenticado → no permitir acceder a pantallas de auth.
      if (isLoggedIn && isAuthRoute) return AppRoutes.dashboard;

      // Onboarding: usuario sin asignaciones (excepto Root).
      if (isLoggedIn &&
          state.uri.path != AppRoutes.onboarding &&
          state.uri.path != AppRoutes.profile) {
        final hasAssignments = ref.read(hasProjectAssignmentsProvider);
        if (hasAssignments == false) return AppRoutes.onboarding;
      }

      // Ya tiene asignaciones → no permitir acceder a onboarding.
      if (isLoggedIn && state.uri.path == AppRoutes.onboarding) {
        final hasAssignments = ref.read(hasProjectAssignmentsProvider);
        if (hasAssignments == true) return AppRoutes.dashboard;
      }

      // Guardia de rol: /users solo para Root.
      if (isLoggedIn && state.uri.path.startsWith('/users')) {
        if (!userProfile.isLoading && !(userProfile.value?.isRoot ?? false)) {
          return AppRoutes.dashboard;
        }
      }

      return null;
    },
    routes: [
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

      // ── Perfil (sin shell — tiene su propio AppBar)
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
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
            path: AppRoutes.users,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: UserListScreen()),
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
        builder: (context, state) => TicketFormScreen(
          projectId: state.pathParameters['id']!,
          returnId:
              (state.extra as Map<String, dynamic>?)?['returnId'] as bool? ??
              false,
        ),
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
        builder: (context, state) => RequerimientoFormScreen(
          projectId: state.pathParameters['id']!,
          returnId:
              (state.extra as Map<String, dynamic>?)?['returnId'] as bool? ??
              false,
        ),
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
        builder: (context, state) =>
            MinutaFormScreen(projectId: state.pathParameters['id']!),
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

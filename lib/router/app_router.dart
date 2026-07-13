import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../authentication/models/user_model.dart';
import '../authentication/screens/login_page.dart';
import '../authentication/screens/login_screen_web.dart';
import '../authentication/services/auth_service.dart';
import '../mobile/admin/main_navigation.dart' as mobile_admin;
import '../mobile/maintenance/maintenance_navigation.dart';
import '../mobile/teacher/menu_pages/about_us_page.dart';
import '../mobile/teacher/menu_pages/archives_page.dart';
import '../mobile/teacher/menu_pages/contact_us_page.dart';
import '../mobile/teacher/menu_pages/settings_page.dart';
import '../mobile/teacher/menu_pages/system_workflow_page.dart';
import '../mobile/teacher/reports/request_details_page.dart';
import '../mobile/teacher/reports/work_request_form_page.dart';
import '../mobile/teacher/reports/work_request_success_page.dart';
import '../mobile/teacher/scanner/manual_room_entry_page.dart';
import '../mobile/teacher/scanner/room_verification_page.dart';
import '../mobile/teacher/student_teacher_navigation.dart';
import '../shared/utils/app_route_observer.dart';
import '../shared/widgets/loading_screen.dart';
import '../web/admin/admin_main_navigation_web.dart' as web_admin;
import '../web/maintenance/maintenance_navigation_web.dart' as web_maintenance;
import '../shared/widgets/splash/smart_splash_screen.dart';
import '../web/teacher/menu/teacher_about_web.dart';
import '../web/teacher/menu/teacher_archives_web.dart';
import '../web/teacher/menu/teacher_contact_web.dart';
import '../web/teacher/menu/teacher_settings_web.dart';
import '../web/teacher/menu/teacher_workflow_web.dart';
import 'package:psu_maintsystem/web/teacher/reports/teacher_create_request_web.dart';
import 'package:psu_maintsystem/web/teacher/reports/teacher_work_process_web.dart';
import 'package:psu_maintsystem/web/admin/tickets/admin_create_request_web.dart';
import 'package:psu_maintsystem/web/teacher/reports/teacher_request_success_web.dart';
import '../web/teacher/teacher_navigation_web.dart' as web_teacher;
import '../web/system_admin/system_admin_main_navigation_web.dart' as web_sysadmin;
import '../mobile/system_admin/system_admin_main_navigation.dart' as mobile_sysadmin;

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

const String appStartupRoute = '/startup';
const String teacherDashboardRoute = '/teacher/dashboard';
const String teacherReportsRoute = '/teacher/reports';
const String teacherLogsRoute = '/teacher/logs';
const String teacherScannerRoute = '/teacher/scanner';
const String teacherProfileRoute = '/teacher/profile';
const String teacherArchivesRoute = '/teacher/archives';
const String teacherSettingsRoute = '/teacher/settings';
const String teacherAboutRoute = '/teacher/about';
const String teacherContactRoute = '/teacher/contact';
const String teacherWorkflowRoute = '/teacher/workflow';
const String teacherCreateRequestRoute = '/teacher/create-request';

String? resolveAuthRedirect({
  required String location,
  required bool isSessionInitialized,
  required bool isPostLoginSplashActive,
  required AppUser? user,
  required bool Function() consumeLoginRedirectPause,
}) {
  final isAtStartup = location == appStartupRoute;
  final isAtLogin = location == '/login';

  if (!isSessionInitialized) {
    return isAtStartup ? null : appStartupRoute;
  }

  if (isPostLoginSplashActive) {
    return null;
  }

  if (user == null) {
    if (isAtStartup) {
      return '/login';
    }
    return isAtLogin ? null : '/login';
  }

  final dashboardRoute = user.dashboardRoute;

  if (isAtStartup) {
    return dashboardRoute;
  }

  if (isAtLogin) {
    if (consumeLoginRedirectPause()) {
      return null;
    }
    return dashboardRoute;
  }

  if (location.startsWith('/admin') && user.role != UserRole.campadmin) {
    return dashboardRoute;
  }

  if (location.startsWith('/system-admin') && user.role != UserRole.admin) {
    return dashboardRoute;
  }

  if (location.startsWith('/teacher') && user.role != UserRole.teacher) {
    return dashboardRoute;
  }

  if (location.startsWith('/maintenance') && user.role != UserRole.maintenance) {
    return dashboardRoute;
  }

  return null;
}

GoRouter buildAppRouter(AuthService authService) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: appStartupRoute,
    refreshListenable: authService,
    redirect: (context, state) {
      return resolveAuthRedirect(
        location: state.matchedLocation,
        isSessionInitialized: authService.isSessionInitialized,
        isPostLoginSplashActive: authService.isPostLoginSplashActive,
        user: authService.currentUser,
        consumeLoginRedirectPause: authService.consumeLoginRedirectPause,
      );
    },
    observers: [appRouteObserver],
    routes: [
      GoRoute(
        path: appStartupRoute,
        builder: (context, state) => const _AppStartupPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            kIsWeb ? const LoginScreenWeb() : const LoginPage(),
      ),
      GoRoute(
        path: '/post-login-splash',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? const {};
          final destinationRoute =
              args['destinationRoute'] as String? ??
              authService.currentUser?.dashboardRoute ??
              '/login';

          return kIsWeb
              ? SmartSplashScreen(
                  destinationRoute: destinationRoute,
                  onCompleted: () {
                    authService.finishPostLoginSplash();
                  },
                )
              : LoadingScreen(
                  destinationRoute: destinationRoute,
                  delay: const Duration(seconds: 4),
                  statusText: 'INITIALIZING',
                  onCompleted: () {
                    authService.finishPostLoginSplash();
                  },
                );
        },
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => kIsWeb
            ? const web_admin.AdminMainNavigationWeb()
            : const mobile_admin.MainNavigation(),
      ),
      GoRoute(
        path: '/system-admin/dashboard',
        builder: (context, state) => kIsWeb
            ? const web_sysadmin.SystemAdminMainNavigationWeb()
            : const mobile_sysadmin.SystemAdminMainNavigation(),
      ),
      GoRoute(
        path: teacherDashboardRoute,
        builder: (context, state) => kIsWeb
            ? const web_teacher.TeacherNavigationWeb(initialIndex: 0)
            : const StudentTeacherNavigation(initialIndex: 0),
      ),
      GoRoute(
        path: teacherReportsRoute,
        builder: (context, state) => kIsWeb
            ? const web_teacher.TeacherNavigationWeb(initialIndex: 1)
            : const StudentTeacherNavigation(initialIndex: 3),
      ),
      GoRoute(
        path: teacherLogsRoute,
        builder: (context, state) => kIsWeb
            ? const web_teacher.TeacherNavigationWeb(initialIndex: 2)
            : const StudentTeacherNavigation(initialIndex: 1),
      ),
      GoRoute(
        path: teacherScannerRoute,
        builder: (context, state) => kIsWeb
            ? const web_teacher.TeacherNavigationWeb(initialIndex: 3)
            : const StudentTeacherNavigation(initialIndex: 2),
      ),
      GoRoute(
        path: teacherProfileRoute,
        builder: (context, state) => kIsWeb
            ? const web_teacher.TeacherNavigationWeb(initialIndex: 4)
            : const StudentTeacherNavigation(initialIndex: 4),
      ),
      GoRoute(
        path: '/maintenance/dashboard',
        builder: (context, state) => kIsWeb
            ? const web_maintenance.MaintenanceNavigationWeb()
            : const MaintenanceNavigation(),
      ),
      GoRoute(
        path: '/manual-room-entry',
        builder: (context, state) => const ManualRoomEntryPage(),
      ),
      GoRoute(
        path: teacherArchivesRoute,
        builder: (context, state) =>
            kIsWeb ? const TeacherArchivesWeb() : const ArchivesPage(),
      ),
      GoRoute(
        path: teacherSettingsRoute,
        builder: (context, state) =>
            kIsWeb ? const TeacherSettingsWeb() : const SettingsPage(),
      ),
      GoRoute(
        path: teacherAboutRoute,
        builder: (context, state) =>
            kIsWeb ? const TeacherAboutWeb() : const AboutUsPage(),
      ),
      GoRoute(
        path: teacherContactRoute,
        builder: (context, state) =>
            kIsWeb ? const TeacherContactWeb() : const ContactUsPage(),
      ),
      GoRoute(
        path: teacherWorkflowRoute,
        builder: (context, state) => kIsWeb
            ? const TeacherSystemWorkflowWeb()
            : const SystemWorkflowPage(),
      ),
      GoRoute(
        path: '/teacher-archives',
        redirect: (_, __) => teacherArchivesRoute,
      ),
      GoRoute(
        path: '/teacher-settings',
        redirect: (_, __) => teacherSettingsRoute,
      ),
      GoRoute(
        path: '/teacher-about-us',
        redirect: (_, __) => teacherAboutRoute,
      ),
      GoRoute(
        path: '/teacher-contact-us',
        redirect: (_, __) => teacherContactRoute,
      ),
      GoRoute(
        path: '/teacher-system-workflow',
        redirect: (_, __) => teacherWorkflowRoute,
      ),
      GoRoute(
        path: '/room-verification',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return RoomVerificationPage(
            roomId: args?['roomId'] ?? '',
            room: args?['room'],
          );
        },
      ),
      GoRoute(
        path: '/work-request-form',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return WorkRequestFormPage(
            roomId: args?['roomId'],
            buildingName: args?['buildingName'],
            roomName: args?['roomName'],
            verifiedRoom: args?['verifiedRoom'],
            lockLocationDetails: args?['lockLocationDetails'] ?? false,
          );
        },
      ),
      GoRoute(
        path: '/work-request-success',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          if (kIsWeb) {
            return TeacherRequestSuccessWeb(
              trackingNumber: args?['trackingNumber'] ?? '',
              location: args?['location'] ?? '',
              severity: args?['severity'] ?? '',
              reportedDate: args?['reportedDate'] ?? DateTime.now(),
            );
          }
          return WorkRequestSuccessPage(
            trackingNumber: args?['trackingNumber'] ?? '',
            location: args?['location'] ?? '',
            severity: args?['severity'] ?? '',
            reportedDate: args?['reportedDate'] ?? DateTime.now(),
          );
        },
      ),
      GoRoute(
        path: '/request-details',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          if (kIsWeb) {
             // For web, if it's a teacher, we can use TeacherWorkProcessWeb
             // But wait, TeacherWorkProcessWeb needs a WorkRequest object.
             // We'll need a way to fetch it if only trackingNumber is provided, 
             // or pass the object in extra.
             if (args?['request'] != null) {
               return TeacherWorkProcessWeb(request: args!['request']);
             }
          }
          return RequestDetailsPage(
            trackingNumber: args?['trackingNumber'] ?? '',
            status: args?['status'] ?? 'PENDING',
          );
        },
      ),
      GoRoute(
        path: teacherCreateRequestRoute,
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return TeacherCreateRequestWeb(
            roomId: args?['roomId'],
            roomName: args?['roomName'],
            buildingName: args?['buildingName'],
          );
        },
      ),
      GoRoute(
        path: '/admin/work-requests/create',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return AdminCreateRequestWeb(
            roomId: args?['roomId'],
            roomName: args?['roomName'],
            buildingName: args?['buildingName'],
          );
        },
      ),
    ],
  );
}

class _AppStartupPage extends StatelessWidget {
  const _AppStartupPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: kIsWeb ? 180 : 220,
              width: kIsWeb ? 180 : 220,
              child: Image.asset(
                'assets/images/psummsIcon.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
            ),
            const SizedBox(height: 32),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'PSU ',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  TextSpan(
                    text: 'MaintSystem',
                    style: TextStyle(
                      color: Color(0xFF4169E1),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'PANGASINAN STATE UNIVERSITY',
              style: TextStyle(
                color: Color(0xFF757575),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 220,
              child: Column(
                children: const [
                  LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Color(0xFFE0E0E0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF4169E1),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'RESTORING SESSION',
                    style: TextStyle(
                      color: Color(0xFF4169E1),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

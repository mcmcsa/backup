import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'authentication/services/auth_service.dart';
import 'config/supabase_config.dart';
import 'shared/providers/theme_provider.dart';
import 'authentication/screens/login_page.dart';
import 'mobile/admin/main_navigation.dart' as mobile_admin;
import 'web/admin/main_navigation_web.dart' as web_admin;
import 'mobile/teacher/student_teacher_navigation.dart';
import 'mobile/teacher/scanner/manual_room_entry_page.dart';
import 'mobile/teacher/scanner/room_verification_page.dart';
import 'mobile/teacher/reports/work_request_form_page.dart';
import 'mobile/teacher/reports/work_request_success_page.dart';
import 'mobile/teacher/reports/request_details_page.dart';
import 'mobile/teacher/menu_pages/archives_page.dart';
import 'mobile/teacher/menu_pages/settings_page.dart';
import 'mobile/teacher/menu_pages/about_us_page.dart';
import 'mobile/teacher/menu_pages/contact_us_page.dart';
import 'mobile/teacher/menu_pages/system_workflow_page.dart';
import 'mobile/maintenance/maintenance_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }
  
  // Initialize Supabase — prefer .env values; fall back to compile-time config.
  final url = (dotenv.env['SUPABASE_URL']?.isNotEmpty == true)
      ? dotenv.env['SUPABASE_URL']!
      : supabaseUrl;
  final anonKey = (dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty == true)
      ? dotenv.env['SUPABASE_ANON_KEY']!
      : supabaseAnonKey;

  try {
    await Supabase.initialize(url: url, anonKey: anonKey);
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
    rethrow;
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'PSU MaintSystem',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            initialRoute: '/login',
            routes: {
              '/login': (context) => const LoginPage(),
              '/admin/dashboard': (context) => kIsWeb
                  ? const web_admin.MainNavigationWeb()
                  : const mobile_admin.MainNavigation(),
              '/student-teacher/dashboard': (context) => const StudentTeacherNavigation(),
              '/maintenance/dashboard': (context) => const MaintenanceNavigation(),
              '/manual-room-entry': (context) => const ManualRoomEntryPage(),
              '/student-archives': (context) => const ArchivesPage(),
              '/student-settings': (context) => const SettingsPage(),
              '/student-about-us': (context) => const AboutUsPage(),
              '/student-contact-us': (context) => const ContactUsPage(),
              '/student-system-workflow': (context) => const SystemWorkflowPage(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/room-verification') {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => RoomVerificationPage(
                    roomId: args?['roomId'] ?? '',
                    room: args?['room'],
                  ),
                );
              }
              if (settings.name == '/work-request-form') {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => WorkRequestFormPage(
                    roomId: args?['roomId'],
                    buildingName: args?['buildingName'],
                    roomName: args?['roomName'],
                  ),
                );
              }
              if (settings.name == '/work-request-success') {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => WorkRequestSuccessPage(
                    trackingNumber: args?['trackingNumber'] ?? '',
                    location: args?['location'] ?? '',
                    severity: args?['severity'] ?? '',
                    reportedDate: args?['reportedDate'] ?? DateTime.now(),
                  ),
                );
              }
              if (settings.name == '/request-details') {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => RequestDetailsPage(
                    trackingNumber: args?['trackingNumber'] ?? '',
                    status: args?['status'] ?? 'PENDING',
                  ),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}



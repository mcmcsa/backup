import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'authentication/services/auth_service.dart';
import 'config/supabase_config.dart';
import 'router/app_router.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/work_request_provider.dart';
import 'shared/providers/room_provider.dart';
import 'shared/providers/user_provider.dart';
import 'shared/services/connectivity_service.dart';
import 'shared/services/offline_sync_service.dart';
import 'shared/services/offline_handlers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }
  
  // Initialize Supabase — prefer .env values; fall back to compile-time config.
  final isEnvInitialized = dotenv.isInitialized;
  final url = (isEnvInitialized && dotenv.env['SUPABASE_URL']?.isNotEmpty == true)
      ? dotenv.env['SUPABASE_URL']!
      : supabaseUrl;
  final anonKey = (isEnvInitialized && dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty == true)
      ? dotenv.env['SUPABASE_ANON_KEY']!
      : supabaseAnonKey;

  try {
    await Supabase.initialize(url: url, anonKey: anonKey);
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
    rethrow;
  }
  
  // Initialize offline services
  await ConnectivityService().initialize();
  await OfflineSyncService().initialize();
  registerOfflineHandlers();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthService _authService;
  late final ThemeProvider _themeProvider;
  late final GoRouter _router;
  late final WorkRequestProvider _workRequestProvider;
  late final RoomProvider _roomProvider;
  late final UserProvider _userProvider;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(
      restoreSessionOnStartup: true,
    );
    _themeProvider = ThemeProvider();
    _workRequestProvider = WorkRequestProvider();
    _roomProvider = RoomProvider();
    _userProvider = UserProvider();
    _router = buildAppRouter(_authService);
  }

  @override
  void dispose() {
    _authService.dispose();
    _themeProvider.dispose();
    _workRequestProvider.dispose();
    _roomProvider.dispose();
    _userProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: _authService),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
        ChangeNotifierProvider<WorkRequestProvider>.value(value: _workRequestProvider),
        ChangeNotifierProvider<RoomProvider>.value(value: _roomProvider),
        ChangeNotifierProvider<UserProvider>.value(value: _userProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'PSU QR-MMS',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

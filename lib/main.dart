import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'authentication/services/auth_service.dart';
import 'config/supabase_config.dart';
import 'router/app_router.dart';
import 'shared/providers/theme_provider.dart';

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthService _authService;
  late final ThemeProvider _themeProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(
      restoreSessionOnStartup: true,
    );
    _themeProvider = ThemeProvider();
    _router = buildAppRouter(_authService);
  }

  @override
  void dispose() {
    _authService.dispose();
    _themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: _authService),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
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



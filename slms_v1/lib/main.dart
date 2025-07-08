import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/connection_service.dart'; // Added for ConnectionService
import 'services/sync_service.dart';
import 'services/background_sync_service.dart';
import 'screens/timetable/timetable_screen.dart'; // Already correct, assuming timetable_screen.dart is the main timetable file
import 'screens/canvas/teacher_canvas_screen.dart';
import 'screens/canvas/learner_canvas_screen.dart';
import 'providers/sync_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/registration/learner_registration_screen.dart';
import 'screens/registration/teacher_registration_screen.dart';
import 'screens/registration/parent_registration_screen.dart';
import 'screens/registration/admin_registration_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/admin/admin_screen.dart'; // Added for admin screen

Future<void> requestPermissions() async {
  await [
    Permission.nearbyWifiDevices,
    Permission.photos,
    Permission.location,
  ].request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final dbService = DatabaseService();
  try {
    await dbService.init();
  } catch (e) {
    print("Initialization error: $e");
  }
  final connectionService =
      ConnectionService(dbService); // Initialize ConnectionService
  final syncService = SyncService(
      connectionService, dbService); // Correct order: ConnectionService first
  final backgroundSyncService = BackgroundSyncService(
      dbService, syncService, connectionService); // Add ConnectionService

  // Request permissions
  await requestPermissions();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: dbService),
        Provider<ConnectionService>.value(value: connectionService), // Added
        Provider<SyncService>.value(value: syncService),
        Provider<BackgroundSyncService>.value(value: backgroundSyncService),
        ChangeNotifierProvider(create: (_) => SyncState()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'schoollms',
      theme: ThemeData(
        primaryColor: const Color(
            0xFFD4A017), // Replace with primary color from schoollms.png
        scaffoldBackgroundColor:
            const Color(0xFFF1F5F9), // Replace with background color
        colorScheme: const ColorScheme.light(
          secondary:
              Color(0xFF1E7C8D), // Replace with accent color from schoollms.png
        ),
        textTheme: const TextTheme(
          bodyMedium:
              TextStyle(color: Color(0xFF1F2937)), // Replace with text color
          titleLarge: TextStyle(color: Color(0xFF1F2937)), // For AppBar title
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A), // Replace with primary color
          foregroundColor: Colors.white, // Text/icon color on AppBar
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                const Color(0xFFD4A017), // Replace with primary color
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF1E7C8D), // Replace with accent color
        ),
      ),
      initialRoute: '/login', // Start at login
      routes: {
        '/login': (context) => LoginScreen(),
        '/learner_registration': (context) => LearnerRegistrationScreen(),
        '/teacher_registration': (context) => TeacherRegistrationScreen(),
        '/parent_registration': (context) => ParentRegistrationScreen(
            learnerId: ModalRoute.of(context)!.settings.arguments as String),
        '/admin_registration': (context) => AdminRegistrationScreen(),
        '/timetable': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return TimetableScreen();
        },
        '/profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return ProfileScreen(userId: args['userId']);
        },
        '/admin': (context) => AdminScreen(), // Added admin route
        '/teacher_canvas': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return TeacherCanvasScreen(teacherId: args?['userId'] ?? 'teacher_1');
        },
        '/learner_canvas': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return LearnerCanvasScreen(learnerId: args?['userId'] ?? 'learner_1');
        },
      },
    );
  }
}

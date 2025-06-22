import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/sync_service.dart';
import 'services/background_sync_service.dart';
import 'screens/timetable/teacher_timetable_screen.dart';
import 'screens/timetable/learner_timetable_screen.dart';
import 'screens/canvas/teacher_canvas_screen.dart';
import 'screens/canvas/learner_canvas_screen.dart';
import 'providers/sync_state.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final syncService = SyncService(dbService);
  final backgroundSyncService = BackgroundSyncService(dbService, syncService);

  // Request permissions
  await requestPermissions();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: dbService),
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
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/teacher_timetable': (context) =>
            TeacherTimetableScreen(teacherId: 'teacher_1'),
        '/learner_timetable': (context) =>
            LearnerTimetableScreen(learnerId: 'learner_1'),
        '/teacher_canvas': (context) =>
            TeacherCanvasScreen(teacherId: 'teacher_1'),
        '/learner_canvas': (context) =>
            LearnerCanvasScreen(learnerId: 'learner_1'),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final backgroundSyncService = Provider.of<BackgroundSyncService>(context);

    // Start background sync for the learner
    backgroundSyncService.startBackgroundSync('learner_1', context);

    return Scaffold(
      appBar: AppBar(title: const Text('schoollms')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/teacher_timetable');
              },
              child: const Text('Teacher Timetable'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/learner_timetable');
              },
              child: const Text('Learner Timetable'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/teacher_canvas');
              },
              child: const Text('Teacher Canvas'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/learner_canvas');
              },
              child: const Text('Learner Canvas'),
            ),
          ],
        ),
      ),
    );
  }
}

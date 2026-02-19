import 'package:flutter/material.dart';
import 'package:quran_flutter/quran_flutter.dart';
import 'screens/dhikr_screen.dart';
import 'screens/home_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/quran_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Quran Database
  await Quran.initialize();
  
  // Initialize Notification Service
  await NotificationService.instance.initialize();
  await NotificationService.instance.scheduleSuhoorIftarIfConfigured();
  
  runApp(BarakaApp());
}

class BarakaApp extends StatelessWidget {
  BarakaApp({super.key});

  final ValueNotifier<int> _roundsGoalNotifier = ValueNotifier<int>(1);

  @override
  Widget build(BuildContext context) {
    // Premium Islamic Green Color Scheme
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.light,
      primary: const Color(0xFF2E7D32),
      secondary: const Color(0xFF66BB6A),
      surface: const Color(0xFFF3F1EA),
      // Fix: 'background' replaced with 'surface' based on Flutter 3.18+ standards
      tertiary: const Color(0xFF1B5E20),
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF66BB6A),
      brightness: Brightness.dark,
      primary: const Color(0xFF66BB6A),
      secondary: const Color(0xFF81C784),
      surface: const Color(0xFF1A1A1A),
      tertiary: const Color(0xFF4CAF50),
    );

    return MaterialApp(
      title: 'Baraka30',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        // Fix: Use surface for background color
        scaffoldBackgroundColor: lightScheme.surface,
        fontFamily: 'Serif', 
        
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: lightScheme.primary,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Serif',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: lightScheme.tertiary,
          ),
        ),

        // Fix: Changed CardTheme to CardThemeData
        cardTheme: CardThemeData(
          color: lightScheme.surface.withValues(alpha: 0.9), // Fix: used withValues
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: lightScheme.primary.withValues(alpha: 0.1)),
          ),
        ),

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: lightScheme.surface,
          indicatorColor: lightScheme.primary.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.all(
            TextStyle(color: lightScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: lightScheme.primary, size: 28);
            }
            return IconThemeData(color: lightScheme.primary.withValues(alpha: 0.6));
          }),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkScheme.surface,
        fontFamily: 'Serif',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: AppShell(roundsGoalNotifier: _roundsGoalNotifier),
      routes: {
        '/home': (_) => HomeScreen(roundsGoalListenable: _roundsGoalNotifier),
        '/dhikr': (_) => const DhikrScreen(),
        '/quran': (_) => const QuranScreen(),
        '/planner': (_) => PlannerScreen(roundsGoalNotifier: _roundsGoalNotifier),
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.roundsGoalNotifier});

  final ValueNotifier<int> roundsGoalNotifier;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final List<Widget> _screens = [
    HomeScreen(roundsGoalListenable: widget.roundsGoalNotifier),
    const DhikrScreen(),
    const QuranScreen(),
    PlannerScreen(roundsGoalNotifier: widget.roundsGoalNotifier),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        elevation: 8,
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined), 
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fingerprint_outlined),
            selectedIcon: Icon(Icons.fingerprint_rounded),
            label: 'Dhikr',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Quran',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Planner',
          ),
        ],
      ),
    );
  }
}
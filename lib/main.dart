import 'package:flutter/material.dart';
import 'screens/dhikr_screen.dart';
import 'screens/home_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/quran_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  // Ensure Flutter is initialized before calling native services
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Notification Service
  await NotificationService.instance.initialize();
  await NotificationService.instance.scheduleSuhoorIftarIfConfigured();
  
  runApp(const BarakaApp());
}

class BarakaApp extends StatelessWidget {
  const BarakaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Premium Islamic Green Color Scheme
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.light,
      primary: const Color(0xFF2E7D32), // Rich Green
      secondary: const Color(0xFF66BB6A), // Light Green
      surface: const Color(0xFFF3F1EA), // Warm Surface
      background: const Color(0xFFF8F6EF), // Soft Background
      tertiary: const Color(0xFF1B5E20), // Dark Accent
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF66BB6A),
      brightness: Brightness.dark,
      primary: const Color(0xFF66BB6A),
      secondary: const Color(0xFF81C784),
      surface: const Color(0xFF1A1A1A),
      background: const Color(0xFF121212),
      tertiary: const Color(0xFF4CAF50),
    );

    return MaterialApp(
      title: 'Baraka30',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Switches based on device settings
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        scaffoldBackgroundColor: lightScheme.background,
        fontFamily: 'Serif', // Elegant spiritual typography
        
        // Transparent AppBar allows Home Screen gradients to show through
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: lightScheme.primary,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            fontFamily: 'Serif',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),

        // Modern Rounded Cards
        cardTheme: CardThemeData(
          color: lightScheme.surface.withOpacity(0.9),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: lightScheme.primary.withOpacity(0.1)),
          ),
        ),

        // Bottom Navigation Styling
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: lightScheme.surface,
          indicatorColor: lightScheme.primary.withOpacity(0.12),
          labelTextStyle: MaterialStateProperty.all(
            TextStyle(color: lightScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          iconTheme: MaterialStateProperty.all(
            IconThemeData(color: lightScheme.primary),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkScheme.background,
        fontFamily: 'Serif',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const AppShell(),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/dhikr': (_) => const DhikrScreen(),
        '/quran': (_) => const QuranScreen(),
        '/planner': (_) => const PlannerScreen(),
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // Ordered list of screens for the Navigation Bar
  final _screens = const [
    HomeScreen(),
    DhikrScreen(),
    QuranScreen(),
    PlannerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody allows the Home Screen background to flow behind the Navigation Bar
      extendBody: true, 
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        elevation: 0,
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
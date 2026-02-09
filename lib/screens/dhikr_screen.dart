import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptic Feedback

class DhikrScreen extends StatefulWidget {
  const DhikrScreen({super.key});

  @override
  State<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends State<DhikrScreen> {
  int _counter = 0;
  String _selectedDhikr = "SubhanAllah";
  final List<String> _options = ["SubhanAllah", "Alhamdulillah", "Allahu Akbar", "Custom"];

  void _incrementCounter() {
    HapticFeedback.mediumImpact(); // Mimics the "click" of a bead
    setState(() {
      _counter++;
    });
  }

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tasbih"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Show confirmation to avoid accidental resets
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Reset Counter?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
                    TextButton(
                      onPressed: () {
                        _resetCounter();
                        Navigator.pop(context);
                      }, 
                      child: const Text("Yes")
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dhikr Selector
          DropdownButton<String>(
            value: _selectedDhikr,
            underline: Container(),
            style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
            items: _options.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedDhikr = newValue!;
                _counter = 0; // Reset on change
              });
            },
          ),
          
          const Spacer(),

          // The "Physical Bead" Tap Area
          GestureDetector(
            onTap: _incrementCounter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Glow/Ring
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                ),
                // The Bead
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$_counter',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          Text(
            "Tap anywhere on the circle",
            style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1.2),
          ),
          
          const Spacer(),
          
          // Target Indicator (Small Progress Bar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_counter % 33) / 33,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text("${(_counter / 33).floor()} Sets of 33 Completed"),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
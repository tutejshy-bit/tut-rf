import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/ble_provider.dart';
import 'providers/log_provider.dart';
import 'providers/notification_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => BleProvider()),
        ChangeNotifierProvider(create: (context) => LogProvider()),
        ChangeNotifierProvider(create: (context) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'Evil Crow RF v2 Controller',
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const flipperOrange = Color(0xFFFF8200);
    const flipperOrangeDark = Color(0xFFFF6C00);
    const flipperGray = Color(0xFF2C2C2C);
    const flipperLightGray = Color(0xFFF5F5F5);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: flipperOrange,
        brightness: Brightness.light,
        primary: flipperOrange,
        secondary: flipperOrangeDark,
        surface: Colors.white,
        surfaceContainerHighest: flipperLightGray,
        error: Colors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: flipperGray,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: flipperOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: flipperOrange,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: flipperOrange,
          side: const BorderSide(color: flipperOrange),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: flipperOrange,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return flipperOrange;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return flipperOrange.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return flipperOrange;
          }
          return Colors.transparent;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return flipperOrange;
          }
          return Colors.grey;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: flipperOrange,
        thumbColor: flipperOrange,
        inactiveTrackColor: flipperOrange.withOpacity(0.3),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: flipperOrange,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: flipperOrange,
        labelColor: flipperOrange,
        unselectedLabelColor: Colors.grey,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const flipperOrange = Color(0xFFFF8200);
    const flipperOrangeDark = Color(0xFFFF6C00);
    const flipperDarkGray = Color(0xFF1A1A1A);
    const flipperMediumGray = Color(0xFF2C2C2C);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: flipperOrange,
        brightness: Brightness.dark,
        primary: flipperOrange,
        secondary: flipperOrangeDark,
        surface: flipperDarkGray,
        surfaceContainerHighest: flipperMediumGray,
        error: Colors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: flipperMediumGray,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: flipperMediumGray,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: flipperOrange,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: flipperOrange,
          side: const BorderSide(color: flipperOrange),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: flipperOrange,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return flipperOrange;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return flipperOrange.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return flipperOrange;
          }
          return Colors.transparent;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return flipperOrange;
          }
          return Colors.grey;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: flipperOrange,
        thumbColor: flipperOrange,
        inactiveTrackColor: flipperOrange.withOpacity(0.3),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: flipperOrange,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: flipperOrange,
        labelColor: flipperOrange,
        unselectedLabelColor: Colors.grey,
      ),
    );
  }
}


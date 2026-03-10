import 'package:entrixo/screens/splash_screen.dart';
import 'package:entrixo/theme/theme.dart';
import 'package:entrixo/utils/network_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entrixo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return NetworkManager(
          navigatorKey: navigatorKey,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
                systemNavigationBarColor: Colors.white,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
              child: child!,
            ),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}

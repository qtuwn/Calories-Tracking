import 'package:flutter/material.dart';
import 'onboarding/onboarding_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wao - Nutrition App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFAAF0D1), // Mint Green
        ),
        useMaterial3: true,
      ),
      home: const OnboardingPage(),
    );
  }
}

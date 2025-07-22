import 'package:flutter/material.dart';

void main() {
  runApp(const ScanGrumesTestApp());
}

class ScanGrumesTestApp extends StatelessWidget {
  const ScanGrumesTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanGrumes Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.green[300],
        textTheme: Theme.of(context).textTheme.copyWith(
          bodyLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      home: const TestHomePage(),
    );
  }
}

class TestHomePage extends StatelessWidget {
  const TestHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'LANCEMENT OK ✅',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:habit_tracker/habitracker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart'; // Add this import
import 'package:path/path.dart'; // Add this import
import 'dart:io'; // Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // --- Add these lines to print the database path ---
  Directory documentsDirectory = await getApplicationDocumentsDirectory();
  String path = join(documentsDirectory.path, 'habit_tracker.db');
  print('Database path: $path');
  // ---------------------------------------------------

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HabitTracker(),
      debugShowCheckedModeBanner: false,
    );
  }
}

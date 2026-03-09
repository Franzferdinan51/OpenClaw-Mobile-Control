import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // TODO: Register Hive adapters
  // await Hive.openBox('settings');
  // await Hive.openBox('connections');
  // await Hive.openBox('cache');
  
  runApp(
    const ProviderScope(
      child: OpenClawApp(),
    ),
  );
}

import 'package:flutter/material.dart';
import 'app.dart';
import 'services/app_settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize app settings before app starts
  await AppSettingsService.initialize();
  
  runApp(const OpenClawApp());
}

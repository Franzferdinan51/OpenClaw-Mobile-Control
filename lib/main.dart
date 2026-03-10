import 'package:flutter/material.dart';
import 'app.dart';
import 'services/app_settings_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize app settings before app starts
  await AppSettingsService.initialize();
  
  // Initialize theme service
  await ThemeService.initialize();
  
  runApp(const DuckBotGoApp());
}

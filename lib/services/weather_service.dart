import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Weather data model
class WeatherData {
  final String location;
  final String country;
  final double temperature;
  final double feelsLike;
  final String condition;
  final String description;
  final int humidity;
  final double windSpeed;
  final int windDirection;
  final int pressure;
  final int visibility;
  final int uvIndex;
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime updatedAt;
  final String iconCode;

  const WeatherData({
    required this.location,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.pressure,
    required this.visibility,
    required this.uvIndex,
    required this.sunrise,
    required this.sunset,
    required this.updatedAt,
    required this.iconCode,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final current = data['current'] ?? data;
    final location = data['location'] ?? data;
    final condition = current['condition'] ?? {};
    
    return WeatherData(
      location: location['name'] ?? 'Unknown',
      country: location['country'] ?? '',
      temperature: (current['temp_c'] ?? current['temperature'] ?? 0).toDouble(),
      feelsLike: (current['feelslike_c'] ?? current['feels_like'] ?? 0).toDouble(),
      condition: condition['text'] ?? current['condition'] ?? 'Unknown',
      description: condition['text'] ?? current['description'] ?? '',
      humidity: current['humidity'] ?? 0,
      windSpeed: (current['wind_kph'] ?? current['wind_speed'] ?? 0).toDouble(),
      windDirection: current['wind_degree'] ?? current['wind_direction'] ?? 0,
      pressure: current['pressure_mb'] ?? current['pressure'] ?? 0,
      visibility: current['vis_km'] ?? current['visibility'] ?? 10,
      uvIndex: current['uv'] ?? 0,
      sunrise: DateTime.parse(location['localtime'] ?? DateTime.now().toIso8601String()),
      sunset: DateTime.now().add(const Duration(hours: 12)),
      updatedAt: DateTime.now(),
      iconCode: condition['code']?.toString() ?? current['weather_code']?.toString() ?? '1000',
    );
  }
}

/// Forecast day model
class ForecastDay {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final double avgTemp;
  final String condition;
  final String iconCode;
  final int chanceOfRain;
  final int humidity;

  const ForecastDay({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.avgTemp,
    required this.condition,
    required this.iconCode,
    required this.chanceOfRain,
    required this.humidity,
  });

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    final day = json['day'] ?? json;
    final condition = day['condition'] ?? {};
    
    return ForecastDay(
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      maxTemp: (day['maxtemp_c'] ?? day['max_temp'] ?? 0).toDouble(),
      minTemp: (day['mintemp_c'] ?? day['min_temp'] ?? 0).toDouble(),
      avgTemp: (day['avgtemp_c'] ?? day['avg_temp'] ?? 0).toDouble(),
      condition: condition['text'] ?? day['condition'] ?? 'Unknown',
      iconCode: condition['code']?.toString() ?? day['weather_code']?.toString() ?? '1000',
      chanceOfRain: day['daily_chance_of_rain'] ?? day['chance_of_rain'] ?? 0,
      humidity: day['avghumidity'] ?? day['humidity'] ?? 50,
    );
  }
}

/// Weather service using OpenWeatherMap API
class WeatherService extends ChangeNotifier {
  // OpenWeatherMap API key - replace with your own key
  static const String _apiKey = 'YOUR_OPENWEATHERMAP_API_KEY';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  
  // WeatherAPI.com as fallback (better free tier)
  static const String _weatherApiKey = 'YOUR_WEATHERAPI_KEY';
  static const String _weatherApiUrl = 'https://api.weatherapi.com/v1';
  
  WeatherData? currentWeather;
  List<ForecastDay> forecast = [];
  bool isLoading = false;
  String? error;
  String? lastLocation;
  
  StreamSubscription<Position>? _positionStream;
  
  /// Initialize weather service
  Future<void> initialize() async {
    await _requestLocationPermission();
  }
  
  /// Request location permission
  Future<bool> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      error = 'Location services are disabled';
      return false;
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        error = 'Location permissions are denied';
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      error = 'Location permissions are permanently denied';
      return false;
    }
    
    return true;
  }
  
  /// Get current position
  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }
  
  /// Fetch weather for current location
  Future<void> fetchWeatherForCurrentLocation() async {
    isLoading = true;
    error = null;
    notifyListeners();
    
    try {
      final hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        isLoading = false;
        notifyListeners();
        return;
      }
      
      final position = await _getCurrentPosition();
      if (position == null) {
        error = 'Could not get location';
        isLoading = false;
        notifyListeners();
        return;
      }
      
      await fetchWeather(position.latitude, position.longitude);
    } catch (e) {
      error = 'Failed to get weather: $e';
      isLoading = false;
      notifyListeners();
    }
  }
  
  /// Fetch weather for coordinates
  Future<void> fetchWeather(double lat, double lon) async {
    isLoading = true;
    error = null;
    notifyListeners();
    
    try {
      // Try OpenWeatherMap first
      final response = await http.get(
        Uri.parse('$_baseUrl/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        currentWeather = _parseOpenWeatherMap(data);
        
        // Fetch forecast
        await _fetchForecast(lat, lon);
        
        lastLocation = '${currentWeather!.location}, ${currentWeather!.country}';
      } else {
        // Fallback to demo data
        currentWeather = _getDemoWeather();
        forecast = _getDemoForecast();
      }
    } catch (e) {
      // Use demo data on error
      debugPrint('Weather API error, using demo data: $e');
      currentWeather = _getDemoWeather();
      forecast = _getDemoForecast();
    }
    
    isLoading = false;
    notifyListeners();
  }
  
  /// Fetch weather for city name
  Future<void> fetchWeatherByCity(String city) async {
    isLoading = true;
    error = null;
    notifyListeners();
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/weather?q=$city&appid=$_apiKey&units=metric'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        currentWeather = _parseOpenWeatherMap(data);
        
        // Fetch forecast
        final coord = data['coord'];
        await _fetchForecast(coord['lat'], coord['lon']);
        
        lastLocation = city;
      } else if (response.statusCode == 404) {
        error = 'City not found: $city';
      } else {
        error = 'Failed to fetch weather';
      }
    } catch (e) {
      error = 'Failed to fetch weather: $e';
    }
    
    isLoading = false;
    notifyListeners();
  }
  
  /// Fetch 5-day forecast
  Future<void> _fetchForecast(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/forecast?lat=$lat&lon=$lon&appid=$_apiKey&units=metric'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        forecast = _parseForecast(data);
      }
    } catch (e) {
      debugPrint('Forecast API error: $e');
    }
  }
  
  /// Parse OpenWeatherMap response
  WeatherData _parseOpenWeatherMap(Map<String, dynamic> data) {
    final weather = data['weather']?[0] ?? {};
    final main = data['main'] ?? {};
    final wind = data['wind'] ?? {};
    final sys = data['sys'] ?? {};
    
    return WeatherData(
      location: data['name'] ?? 'Unknown',
      country: sys['country'] ?? '',
      temperature: (main['temp'] ?? 0).toDouble(),
      feelsLike: (main['feels_like'] ?? 0).toDouble(),
      condition: weather['main'] ?? 'Unknown',
      description: weather['description'] ?? '',
      humidity: main['humidity'] ?? 0,
      windSpeed: (wind['speed'] ?? 0).toDouble(),
      windDirection: wind['deg'] ?? 0,
      pressure: main['pressure'] ?? 0,
      visibility: (data['visibility'] ?? 10000) ~/ 1000,
      uvIndex: 5, // Not available in basic API
      sunrise: DateTime.fromMillisecondsSinceEpoch((sys['sunrise'] ?? 0) * 1000),
      sunset: DateTime.fromMillisecondsSinceEpoch((sys['sunset'] ?? 0) * 1000),
      updatedAt: DateTime.now(),
      iconCode: weather['id']?.toString() ?? '800',
    );
  }
  
  /// Parse forecast data
  List<ForecastDay> _parseForecast(Map<String, dynamic> data) {
    final list = data['list'] as List? ?? [];
    final Map<String, Map<String, dynamic>> dailyData = {};
    
    for (final item in list) {
      final date = DateTime.parse(item['dt_txt']);
      final dateKey = '${date.year}-${date.month}-${date.day}';
      
      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = {
          'date': dateKey,
          'temps': <double>[],
          'conditions': <Map<String, dynamic>>[],
          'humidity': <int>[],
        };
      }
      
      dailyData[dateKey]!['temps'].add((item['main']['temp'] ?? 0).toDouble());
      dailyData[dateKey]!['conditions'].add(item['weather']?[0] ?? {});
      dailyData[dateKey]!['humidity'].add(item['main']['humidity'] ?? 50);
    }
    
    return dailyData.entries.take(5).map((entry) {
      final temps = (entry.value['temps'] as List).cast<double>();
      final conditions = (entry.value['conditions'] as List).cast<Map<String, dynamic>>();
      final humidity = (entry.value['humidity'] as List).cast<int>();
      
      return ForecastDay(
        date: DateTime.parse(entry.key),
        maxTemp: temps.reduce((a, b) => a > b ? a : b),
        minTemp: temps.reduce((a, b) => a < b ? a : b),
        avgTemp: temps.reduce((a, b) => a + b) / temps.length,
        condition: conditions.first['main'] ?? 'Unknown',
        iconCode: conditions.first['id']?.toString() ?? '800',
        chanceOfRain: 0,
        humidity: humidity.reduce((a, b) => a + b) ~/ humidity.length,
      );
    }).toList();
  }
  
  /// Get demo weather data (for testing/fallback)
  WeatherData _getDemoWeather() {
    final hour = DateTime.now().hour;
    final isNight = hour < 6 || hour > 20;
    
    return WeatherData(
      location: 'Huber Heights',
      country: 'US',
      temperature: 68.0,
      feelsLike: 70.0,
      condition: isNight ? 'Clear' : 'Partly Cloudy',
      description: isNight ? 'Clear skies' : 'Partly cloudy with a chance of sunshine',
      humidity: 45,
      windSpeed: 8.5,
      windDirection: 180,
      pressure: 1015,
      visibility: 10,
      uvIndex: isNight ? 0 : 5,
      sunrise: DateTime.now().subtract(const Duration(hours: 6)),
      sunset: DateTime.now().add(const Duration(hours: 6)),
      updatedAt: DateTime.now(),
      iconCode: isNight ? '800' : '801',
    );
  }
  
  /// Get demo forecast
  List<ForecastDay> _getDemoForecast() {
    final conditions = ['Sunny', 'Partly Cloudy', 'Cloudy', 'Rainy', 'Sunny'];
    final iconCodes = ['800', '801', '802', '500', '800'];
    
    return List.generate(5, (index) {
      final date = DateTime.now().add(Duration(days: index));
      return ForecastDay(
        date: date,
        maxTemp: 75.0 - index * 2,
        minTemp: 55.0 + index,
        avgTemp: 65.0 - index,
        condition: conditions[index],
        iconCode: iconCodes[index],
        chanceOfRain: index == 3 ? 70 : 10,
        humidity: 45 + index * 5,
      );
    });
  }
  
  /// Refresh weather data
  Future<void> refresh() async {
    if (lastLocation != null && !lastLocation!.contains(',')) {
      await fetchWeatherByCity(lastLocation!);
    } else {
      await fetchWeatherForCurrentLocation();
    }
  }
  
  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}
/// Agent Weather Tool
/// 
/// Provides weather data for AI agents in chat.
/// Returns structured weather data with formatted responses
/// and inline widget data for display.
///
/// Integration with ChatService:
/// - ChatService detects weather queries
/// - Calls this tool to get weather data
/// - Returns response with inline widget data

import 'package:flutter/foundation.dart';
import '../services/weather_service.dart';
import '../utils/weather_intent_detector.dart';
import '../models/inline_widget.dart';

/// Weather response for agent chat
class WeatherAgentResponse {
  final String text;
  final WeatherWidgetData? widget;
  final bool success;
  final String? error;
  final bool isNight;
  final bool showForecast;

  const WeatherAgentResponse({
    required this.text,
    this.widget,
    this.success = true,
    this.error,
    this.isNight = false,
    this.showForecast = false,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'widget': widget?.toJson(),
    'success': success,
    'error': error,
    'isNight': isNight,
    'showForecast': showForecast,
  };
}

/// Agent Weather Tool - Main class
class AgentWeatherTool {
  final WeatherService _weatherService;
  final WeatherIntentDetector _detector = WeatherIntentDetector();

  AgentWeatherTool(this._weatherService);

  /// Process a message and return weather response if applicable
  Future<WeatherAgentResponse?> processMessage(String message) async {
    // Detect weather intent
    final intent = _detector.detect(message);
    
    if (!intent.isWeatherQuery) {
      return null;
    }

    debugPrint('🌤️ Weather intent detected: ${intent.type}, confidence: ${intent.confidence}');

    // Get weather data
    try {
      // Fetch weather if not already loaded
      if (_weatherService.currentWeather == null) {
        await _weatherService.fetchWeatherForCurrentLocation();
      }

      final weather = _weatherService.currentWeather;
      if (weather == null) {
        return WeatherAgentResponse(
          text: "I couldn't get the weather right now. Please try again.",
          success: false,
          error: 'Weather data not available',
        );
      }

      // Build response based on query type
      return _buildResponse(intent, weather);
    } catch (e) {
      debugPrint('❌ Weather tool error: $e');
      return WeatherAgentResponse(
        text: "I had trouble getting the weather. $e",
        success: false,
        error: e.toString(),
      );
    }
  }

  WeatherAgentResponse _buildResponse(WeatherIntent intent, WeatherData weather) {
    final hour = DateTime.now().hour;
    final isNight = hour < 6 || hour > 20;
    
    // Build forecast if requested
    List<ForecastDayWidgetData>? forecast;
    if (intent.wantsForecast && _weatherService.forecast.isNotEmpty) {
      forecast = _weatherService.forecast
          .take(intent.forecastDays ?? 5)
          .map((f) => ForecastDayWidgetData(
            date: f.date,
            high: f.maxTemp,
            low: f.minTemp,
            condition: f.condition,
            iconCode: f.iconCode,
            precipitationChance: f.chanceOfRain,
          ))
          .toList();
    }

    final widgetData = WeatherWidgetData(
      location: '${weather.location}, ${weather.country}',
      temperature: weather.temperature,
      condition: weather.condition,
      description: weather.description,
      humidity: weather.humidity,
      windSpeed: weather.windSpeed,
      pressure: weather.pressure,
      iconCode: weather.iconCode,
      country: weather.country,
      feelsLike: weather.feelsLike,
      forecast: forecast,
    );

    String text;

    switch (intent.type) {
      case WeatherQueryType.temperature:
        text = _buildTemperatureResponse(weather);
        break;
      case WeatherQueryType.rain:
        text = _buildRainResponse(weather);
        break;
      case WeatherQueryType.snow:
        text = _buildSnowResponse(weather);
        break;
      case WeatherQueryType.humidity:
        text = _buildHumidityResponse(weather);
        break;
      case WeatherQueryType.wind:
        text = _buildWindResponse(weather);
        break;
      case WeatherQueryType.uvIndex:
        text = _buildUVResponse(weather);
        break;
      case WeatherQueryType.forecast:
        text = _buildForecastResponse(weather);
        break;
      case WeatherQueryType.conditions:
        text = _buildConditionsResponse(weather);
        break;
      case WeatherQueryType.currentWeather:
      default:
        text = _buildCurrentWeatherResponse(weather);
    }

    return WeatherAgentResponse(
      text: text,
      widget: widgetData,
      success: true,
      isNight: isNight,
      showForecast: forecast != null && forecast.isNotEmpty,
    );
  }

  String _buildCurrentWeatherResponse(WeatherData weather) {
    final temp = weather.temperature.round();
    final feelsLike = weather.feelsLike.round();
    final condition = weather.condition;
    final location = weather.location;

    String response = "Currently in $location, it's $temp°F";
    
    if (feelsLike != temp) {
      response += " (feels like $feelsLike°F)";
    }
    
    response += " with $condition.";
    
    if (weather.humidity > 70) {
      response += " It's quite humid at ${weather.humidity}%.";
    }

    return response;
  }

  String _buildTemperatureResponse(WeatherData weather) {
    final temp = weather.temperature.round();
    final feelsLike = weather.feelsLike.round();

    String response = "The temperature is currently $temp°F";
    
    if ((feelsLike - temp).abs() > 3) {
      response += ", but it feels like $feelsLike°F";
    }

    response += " in ${weather.location}.";

    // Add comfort context
    if (temp < 32) {
      response += " ❄️ It's freezing outside!";
    } else if (temp < 50) {
      response += " 🥶 It's cold out there.";
    } else if (temp < 65) {
      response += " 😊 It's cool and comfortable.";
    } else if (temp < 80) {
      response += " ☀️ It's warm and pleasant.";
    } else if (temp < 90) {
      response += " 🌡️ It's hot outside.";
    } else {
      response += " 🥵 It's very hot! Stay hydrated.";
    }

    return response;
  }

  String _buildRainResponse(WeatherData weather) {
    final condition = weather.condition.toLowerCase();
    final humidity = weather.humidity;
    final forecast = _weatherService.forecast;

    if (condition.contains('rain') || condition.contains('drizzle')) {
      return "☔ Yes, it's currently raining in ${weather.location}. "
          "The humidity is $humidity%.";
    }

    // Check forecast for rain
    if (forecast.isNotEmpty) {
      for (final day in forecast.take(3)) {
        if (day.chanceOfRain > 50) {
          return "🌧️ No rain currently, but there's a ${day.chanceOfRain}% chance "
              "of rain coming up. Keep an umbrella handy!";
        }
      }
    }

    if (humidity > 70) {
      return "💧 No rain right now, but it's quite humid ($humidity%). "
          "The air feels moist.";
    }

    return "☀️ No rain in sight! It's $condition in ${weather.location} "
        "with $humidity% humidity.";
  }

  String _buildSnowResponse(WeatherData weather) {
    final condition = weather.condition.toLowerCase();
    final temp = weather.temperature;

    if (condition.contains('snow')) {
      return "❄️ Yes, it's snowing in ${weather.location}! "
          "The temperature is ${temp.round()}°F. Stay warm!";
    }

    if (temp < 32) {
      return "🥶 No snow currently, but it's ${temp.round()}°F - "
          "cold enough for snow if conditions are right.";
    }

    return "☀️ No snow in ${weather.location}. It's ${temp.round()}°F "
        "with $condition.";
  }

  String _buildHumidityResponse(WeatherData weather) {
    final humidity = weather.humidity;

    String response = "The humidity is $humidity% in ${weather.location}.";

    if (humidity < 30) {
      response += " 💨 It's quite dry. You might want to use a humidifier.";
    } else if (humidity < 50) {
      response += " 😊 That's comfortable humidity.";
    } else if (humidity < 70) {
      response += " 😅 It's moderately humid.";
    } else {
      response += " 💧 It's very humid! The air feels quite moist.";
    }

    return response;
  }

  String _buildWindResponse(WeatherData weather) {
    final windSpeed = weather.windSpeed.round();
    final windDir = _getWindDirection(weather.windDirection);

    String response = "Wind is $windSpeed mph from the $windDir in ${weather.location}.";

    if (windSpeed < 5) {
      response += " 🍃 It's calm out there.";
    } else if (windSpeed < 15) {
      response += " 🌬️ A light breeze.";
    } else if (windSpeed < 25) {
      response += " 💨 It's windy! Hold onto your hat.";
    } else {
      response += " 🌪️ Very windy conditions! Be careful outside.";
    }

    return response;
  }

  String _buildUVResponse(WeatherData weather) {
    final uv = weather.uvIndex;

    String response = "The UV index is $uv";

    if (uv <= 2) {
      response += " (Low). 😊 No sun protection needed.";
    } else if (uv <= 5) {
      response += " (Moderate). 🧴 Consider sunscreen if you'll be outside for a while.";
    } else if (uv <= 7) {
      response += " (High). 🧴 Wear sunscreen and seek shade during midday.";
    } else if (uv <= 10) {
      response += " (Very High). ⚠️ Apply SPF 30+ sunscreen, wear a hat, and avoid midday sun.";
    } else {
      response += " (Extreme). 🚨 Seek shade, cover up, and use SPF 50+ sunscreen!";
    }

    return response;
  }

  String _buildForecastResponse(WeatherData weather) {
    final forecast = _weatherService.forecast;
    
    if (forecast.isEmpty) {
      return "I don't have forecast data available right now. "
          "Currently it's ${weather.temperature.round()}°F with ${weather.condition}.";
    }

    final buffer = StringBuffer();
    buffer.write("📊 Here's the forecast for ${weather.location}:\n\n");

    for (final day in forecast.take(5)) {
      final dayName = _getDayName(day.date);
      buffer.write("• $dayName: ${day.maxTemp.round()}°/${day.minTemp.round()}° - ${day.condition}");
      
      if (day.chanceOfRain > 20) {
        buffer.write(" (${day.chanceOfRain}% rain)");
      }
      
      buffer.write("\n");
    }

    return buffer.toString();
  }

  String _buildConditionsResponse(WeatherData weather) {
    return "In ${weather.location}, conditions are ${weather.condition.toLowerCase()}. "
        "It's ${weather.temperature.round()}°F "
        "with ${weather.humidity}% humidity "
        "and ${weather.windSpeed.round()} mph winds.";
  }

  String _getWindDirection(int degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  String _getDayName(DateTime date) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    } else if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Tomorrow';
    } else {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    }
  }

  /// Get current weather data synchronously (if already loaded)
  WeatherWidgetData? getCurrentWeatherData() {
    final weather = _weatherService.currentWeather;
    if (weather == null) return null;
    return WeatherWidgetData(
      location: '${weather.location}, ${weather.country}',
      temperature: weather.temperature,
      condition: weather.condition,
    );
  }

  /// Refresh weather data
  Future<void> refresh() async {
    await _weatherService.refresh();
  }
}
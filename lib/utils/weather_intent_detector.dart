/// Weather Intent Detector
/// 
/// Detects weather-related queries in chat messages and extracts
/// location and forecast type information.
///
/// Used by ChatService to trigger inline weather responses.

class WeatherIntent {
  final WeatherQueryType type;
  final String? location;
  final bool wantsForecast;
  final int? forecastDays;
  final double confidence;

  const WeatherIntent({
    required this.type,
    this.location,
    this.wantsForecast = false,
    this.forecastDays,
    this.confidence = 1.0,
  });

  bool get isWeatherQuery => type != WeatherQueryType.none;
}

enum WeatherQueryType {
  none,
  currentWeather,
  temperature,
  forecast,
  conditions,
  rain,
  snow,
  humidity,
  wind,
  uvIndex,
}

class WeatherIntentDetector {
  // Weather-related keywords with weights
  static const Map<String, int> _weatherKeywords = {
    'weather': 3,
    'temperature': 3,
    'temp': 2,
    'forecast': 3,
    'rain': 2,
    'snow': 2,
    'sunny': 2,
    'cloudy': 2,
    'cloud': 1,
    'humidity': 2,
    'humid': 1,
    'wind': 2,
    'windy': 2,
    'cold': 1,
    'hot': 1,
    'warm': 1,
    'cool': 1,
    'storm': 2,
    'thunder': 2,
    'fog': 2,
    'foggy': 2,
    'mist': 1,
    'uv': 2,
    'sun': 1,
    'sunshine': 1,
    'overcast': 2,
    'clear': 1,
    'degrees': 2,
    'celsius': 1,
    'fahrenheit': 1,
    'f': 1,
    'c': 1,
    'outside': 1,
    'outdoor': 1,
  };

  // Forecast-related keywords
  static const List<String> _forecastKeywords = [
    'forecast',
    'tomorrow',
    'weekend',
    'week',
    'days',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
    'next few',
    'upcoming',
    '5 day',
    'five day',
    '7 day',
    'seven day',
    '10 day',
    'ten day',
  ];

  // Rain-specific keywords
  static const List<String> _rainKeywords = [
    'rain',
    'raining',
    'rainy',
    'precipitation',
    'shower',
    'showers',
    'drizzle',
    'downpour',
    'wet',
    'umbrella',
    'will it rain',
    'gonna rain',
    'going to rain',
  ];

  // Question patterns
  static final List<RegExp> _questionPatterns = [
    // Current weather
    RegExp(r"what'?s?\s+(the\s+)?weather\s*(like)?", caseSensitive: false),
    RegExp(r"how'?s?\s+(the\s+)?weather", caseSensitive: false),
    RegExp(r"what'?s?\s+(the\s+)?temp(erature)?", caseSensitive: false),
    RegExp(r"how\s+(hot|cold|warm|cool)\s+is\s+it", caseSensitive: false),
    RegExp(r"is\s+it\s+(hot|cold|warm|cool|sunny|rainy|cloudy)", caseSensitive: false),
    
    // Forecast
    RegExp(r"what'?s?\s+(the\s+)?forecast", caseSensitive: false),
    RegExp(r"will\s+it\s+(rain|snow|be\s+sunny)", caseSensitive: false),
    RegExp(r"(is\s+it\s+going\s+to|gonna)\s+(rain|snow|be)", caseSensitive: false),
    RegExp(r"\d+\s*day\s*forecast", caseSensitive: false),
    
    // Conditions
    RegExp(r"(humidity|wind|uv)\s*(level|index)?", caseSensitive: false),
    RegExp(r"how\s+(humid|windy)", caseSensitive: false),
  ];

  /// Detect weather intent from a message
  WeatherIntent detect(String message) {
    final lowerMessage = message.toLowerCase().trim();
    
    // Skip very short messages
    if (lowerMessage.length < 3) {
      return const WeatherIntent(type: WeatherQueryType.none);
    }

    // Calculate weather relevance score
    int score = 0;
    for (final entry in _weatherKeywords.entries) {
      if (lowerMessage.contains(entry.key)) {
        score += entry.value;
      }
    }

    // Check question patterns
    bool hasQuestionPattern = false;
    for (final pattern in _questionPatterns) {
      if (pattern.hasMatch(lowerMessage)) {
        hasQuestionPattern = true;
        score += 5;
        break;
      }
    }

    // Also check for question mark
    if (lowerMessage.contains('?')) {
      score += 1;
    }

    // Need at least some weather relevance
    if (score < 2 && !hasQuestionPattern) {
      return const WeatherIntent(type: WeatherQueryType.none);
    }

    // Determine query type
    WeatherQueryType type = _determineQueryType(lowerMessage);
    if (type == WeatherQueryType.none) {
      return const WeatherIntent(type: WeatherQueryType.none);
    }

    // Check if forecast is requested
    bool wantsForecast = _checkWantsForecast(lowerMessage);
    int? forecastDays = _extractForecastDays(lowerMessage);

    // Extract location if mentioned
    String? location = _extractLocation(message);

    // Calculate confidence
    double confidence = _calculateConfidence(score, hasQuestionPattern, type);

    return WeatherIntent(
      type: type,
      location: location,
      wantsForecast: wantsForecast,
      forecastDays: forecastDays,
      confidence: confidence,
    );
  }

  WeatherQueryType _determineQueryType(String message) {
    // Check for specific conditions first
    if (_rainKeywords.any((k) => message.contains(k))) {
      return WeatherQueryType.rain;
    }
    
    if (message.contains('snow')) {
      return WeatherQueryType.snow;
    }
    
    if (message.contains('humidity') || message.contains('humid')) {
      return WeatherQueryType.humidity;
    }
    
    if (message.contains('wind') || message.contains('windy')) {
      return WeatherQueryType.wind;
    }
    
    if (message.contains('uv') || message.contains('uv index')) {
      return WeatherQueryType.uvIndex;
    }
    
    if (message.contains('forecast') || 
        message.contains('tomorrow') ||
        message.contains('next week') ||
        message.contains('weekend')) {
      return WeatherQueryType.forecast;
    }
    
    if (message.contains('temperature') || 
        message.contains('temp') ||
        message.contains('degrees') ||
        message.contains('how hot') ||
        message.contains('how cold')) {
      return WeatherQueryType.temperature;
    }
    
    if (message.contains('weather')) {
      return WeatherQueryType.currentWeather;
    }
    
    if (message.contains('sunny') ||
        message.contains('cloudy') ||
        message.contains('clear') ||
        message.contains('overcast') ||
        message.contains('storm')) {
      return WeatherQueryType.conditions;
    }

    return WeatherQueryType.none;
  }

  bool _checkWantsForecast(String message) {
    return _forecastKeywords.any((k) => message.contains(k));
  }

  int? _extractForecastDays(String message) {
    // Check for specific day counts
    final dayPatterns = [
      RegExp(r'(\d+)\s*day'),
      RegExp(r'(one|two|three|four|five|six|seven|ten)\s*day'),
    ];

    for (final pattern in dayPatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final numStr = match.group(1);
        if (numStr != null) {
          final number = int.tryParse(numStr);
          if (number != null && number > 0 && number <= 14) {
            return number;
          }
        }
        
        // Handle word numbers
        final wordNums = {
          'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
          'six': 6, 'seven': 7, 'ten': 10,
        };
        for (final entry in wordNums.entries) {
          if (message.contains(entry.key)) {
            return entry.value;
          }
        }
      }
    }

    // Check for specific time references
    if (message.contains('tomorrow')) return 1;
    if (message.contains('weekend')) return 3;
    if (message.contains('week')) return 7;

    return null;
  }

  String? _extractLocation(String message) {
    // Common location patterns
    final patterns = [
      RegExp(r'in\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)', caseSensitive: false),
      RegExp(r'at\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)', caseSensitive: false),
      RegExp(r'for\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)', caseSensitive: false),
      RegExp(r'near\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final location = match.group(1);
        if (location != null && location.length > 2) {
          return location;
        }
      }
    }

    return null;
  }

  double _calculateConfidence(int score, bool hasPattern, WeatherQueryType type) {
    double confidence = 0.0;
    
    // Base confidence from score
    confidence += (score / 10.0).clamp(0.0, 0.5);
    
    // Boost for pattern match
    if (hasPattern) {
      confidence += 0.3;
    }
    
    // Boost for specific query type
    if (type != WeatherQueryType.none) {
      confidence += 0.2;
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  /// Quick check if message might be weather-related
  /// Used for early filtering before full detection
  bool mightBeWeatherQuery(String message) {
    final lower = message.toLowerCase();
    return _weatherKeywords.keys.any((k) => lower.contains(k));
  }
}
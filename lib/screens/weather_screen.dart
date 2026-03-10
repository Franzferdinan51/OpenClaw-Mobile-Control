import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/weather_service.dart';
import '../widgets/weather_card.dart';
import '../widgets/forecast_card.dart';
import '../widgets/weather_icon.dart';

/// Full weather screen with beautiful UI
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with TickerProviderStateMixin {
  late WeatherService _weatherService;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    // Initialize weather service
    _weatherService = WeatherService();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    await _weatherService.fetchWeatherForCurrentLocation();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _weatherService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF00D4AA);
    
    return ChangeNotifierProvider.value(
      value: _weatherService,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF0D1117),
                      const Color(0xFF161B22),
                      const Color(0xFF0D1117),
                    ]
                  : [
                      const Color(0xFFF0F4F8),
                      const Color(0xFFFFFFFF),
                      const Color(0xFFF0F4F8),
                    ],
            ),
          ),
          child: SafeArea(
            child: Consumer<WeatherService>(
              builder: (context, weather, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // App bar with search
                      SliverToBoxAdapter(
                        child: _buildHeader(weather, accent, isDark),
                      ),
                      
                      // Weather card
                      SliverToBoxAdapter(
                        child: WeatherCard(
                          weather: weather.currentWeather,
                          isLoading: weather.isLoading,
                          error: weather.error,
                          onRefresh: _handleRefresh,
                          accentColor: accent,
                        ),
                      ),
                      
                      // Forecast
                      if (weather.forecast.isNotEmpty)
                        SliverToBoxAdapter(
                          child: ForecastCard(
                            forecast: weather.forecast,
                            isLoading: weather.isLoading,
                            accentColor: accent,
                          ),
                        ),
                      
                      // Additional info cards
                      if (weather.currentWeather != null)
                        SliverToBoxAdapter(
                          child: _buildAdditionalInfo(
                            weather.currentWeather!,
                            accent,
                            isDark,
                          ),
                        ),
                      
                      // Bottom padding
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 32),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(WeatherService weather, Color accent, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Title row
          Row(
            children: [
              Icon(
                Icons.wb_cloudy,
                color: accent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Weather',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              if (!weather.isLoading)
                IconButton(
                  onPressed: _handleRefresh,
                  icon: Icon(
                    Icons.refresh,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  tooltip: 'Refresh',
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isSearching
                    ? accent.withOpacity(0.5)
                    : Colors.transparent,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) => setState(() {}),
              onSubmitted: _handleSearch,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Search city...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: Icon(
                          Icons.clear,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          
          // Location info
          if (weather.lastLocation != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 4),
                Text(
                  weather.lastLocation!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo(WeatherData weather, Color accent, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          
          // Section title
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Info cards grid
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  Icons.thermostat,
                  'Feels Like',
                  '${weather.feelsLike.round()}°F',
                  'Temperature',
                  Colors.orange,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  Icons.water_drop,
                  'Humidity',
                  '${weather.humidity}%',
                  'Moisture',
                  Colors.blue,
                  isDark,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  Icons.air,
                  'Wind',
                  '${weather.windSpeed.round()} mph',
                  _getWindDirection(weather.windDirection),
                  Colors.cyan,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  Icons.visibility,
                  'Visibility',
                  '${weather.visibility} mi',
                  'Clear sky',
                  Colors.green,
                  isDark,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  Icons.compress,
                  'Pressure',
                  '${weather.pressure} mb',
                  'Atmospheric',
                  Colors.purple,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  Icons.wb_sunny,
                  'UV Index',
                  '${weather.uvIndex}',
                  _getUVLevel(weather.uvIndex),
                  Colors.amber,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    String value,
    String subtitle,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await _weatherService.refresh();
  }

  Future<void> _handleSearch(String city) async {
    if (city.trim().isEmpty) return;
    
    _searchFocusNode.unfocus();
    await _weatherService.fetchWeatherByCity(city.trim());
  }

  String _getWindDirection(int degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) ~/ 45) % 8;
    return directions[index];
  }

  String _getUVLevel(int uv) {
    if (uv <= 2) return 'Low';
    if (uv <= 5) return 'Moderate';
    if (uv <= 7) return 'High';
    if (uv <= 10) return 'Very High';
    return 'Extreme';
  }
}

/// Weather widget for embedding in other screens
class WeatherWidget extends StatelessWidget {
  final Color? accentColor;
  final bool compact;

  const WeatherWidget({
    super.key,
    this.accentColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WeatherService()..fetchWeatherForCurrentLocation(),
      child: Consumer<WeatherService>(
        builder: (context, weather, _) {
          return WeatherCard(
            weather: weather.currentWeather,
            isLoading: weather.isLoading,
            error: weather.error,
            onRefresh: weather.refresh,
            accentColor: accentColor,
            compact: compact,
          );
        },
      ),
    );
  }
}
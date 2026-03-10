import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'weather_icon.dart';
import '../services/weather_service.dart';

/// Beautiful weather card widget with ChatGPT-like UI
class WeatherCard extends StatefulWidget {
  final WeatherData? weather;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRefresh;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool compact;

  const WeatherCard({
    super.key,
    this.weather,
    this.isLoading = false,
    this.error,
    this.onRefresh,
    this.onTap,
    this.accentColor,
    this.compact = false,
  });

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(WeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weather != widget.weather && widget.weather != null) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? const Color(0xFF00D4AA);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (widget.isLoading) {
      return _buildLoadingCard(accent, isDark);
    }
    
    if (widget.error != null) {
      return _buildErrorCard(widget.error!, accent, isDark);
    }
    
    if (widget.weather == null) {
      return _buildEmptyCard(accent, isDark);
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: widget.compact
          ? _buildCompactCard(widget.weather!, accent, isDark)
          : _buildFullCard(widget.weather!, accent, isDark),
    );
  }

  /// Full weather card
  Widget _buildFullCard(WeatherData weather, Color accent, bool isDark) {
    final isNight = DateTime.now().hour < 6 || DateTime.now().hour > 20;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: _getBackgroundGradient(weather, isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accent.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _getShadowColor(weather, isDark),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background decoration
              _buildBackgroundDecoration(weather, isDark),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with location
                    _buildHeader(weather, accent, isDark),
                    
                    const SizedBox(height: 16),
                    
                    // Main weather display
                    Row(
                      children: [
                        // Temperature
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${weather.temperature.round()}',
                                    style: TextStyle(
                                      fontSize: 72,
                                      fontWeight: FontWeight.w200,
                                      color: isDark ? Colors.white : Colors.black87,
                                      height: 0.9,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '°F',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w300,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.7)
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Feels like ${weather.feelsLike.round()}°',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.6)
                                      : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Weather icon
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: WeatherIcon(
                            condition: weather.condition,
                            iconCode: weather.iconCode,
                            size: 90,
                            isNight: isNight,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Condition
                    Text(
                      weather.description.isNotEmpty
                          ? weather.description
                          : weather.condition,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Weather details grid
                    _buildDetailsGrid(weather, accent, isDark),
                    
                    const SizedBox(height: 16),
                    
                    // Footer
                    _buildFooter(weather, accent, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact weather card
  Widget _buildCompactCard(WeatherData weather, Color accent, bool isDark) {
    final isNight = DateTime.now().hour < 6 || DateTime.now().hour > 20;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E1E2E), const Color(0xFF2A2A3A)]
                : [Colors.white, const Color(0xFFF8F9FA)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Weather icon
            SizedBox(
              width: 48,
              height: 48,
              child: WeatherIcon(
                condition: weather.condition,
                size: 44,
                isNight: isNight,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Temperature & condition
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${weather.temperature.round()}°',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        weather.condition,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    weather.location,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // Quick stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.water_drop, size: 14, color: Colors.blue[400]),
                    const SizedBox(width: 2),
                    Text(
                      '${weather.humidity}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.air, size: 14, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(
                      '${weather.windSpeed.round()} mph',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build header with location and actions
  Widget _buildHeader(WeatherData weather, Color accent, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: 18,
          color: accent,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${weather.location}, ${weather.country}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black54,
            ),
          ),
        ),
        
        // Refresh button
        if (widget.onRefresh != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onRefresh,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.refresh,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black45,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build details grid
  Widget _buildDetailsGrid(WeatherData weather, Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDetailItem(
            Icons.water_drop,
            'Humidity',
            '${weather.humidity}%',
            Colors.blue[400]!,
            isDark,
          ),
          _buildDetailItem(
            Icons.air,
            'Wind',
            '${weather.windSpeed.round()} mph',
            Colors.cyan[400]!,
            isDark,
          ),
          _buildDetailItem(
            Icons.visibility,
            'Visibility',
            '${weather.visibility} mi',
            Colors.green[400]!,
            isDark,
          ),
          _buildDetailItem(
            Icons.compress,
            'Pressure',
            '${weather.pressure} mb',
            Colors.orange[400]!,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Build footer with last updated
  Widget _buildFooter(WeatherData weather, Color accent, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 14,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          'Updated ${_formatTimeAgo(weather.updatedAt)}',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Get background gradient based on weather condition
  LinearGradient _getBackgroundGradient(WeatherData weather, bool isDark) {
    final condition = weather.condition.toLowerCase();
    
    if (condition.contains('rain') || condition.contains('thunder')) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF2C3E50), const Color(0xFF1A252F)]
            : [const Color(0xFF607D8B), const Color(0xFF455A64)],
      );
    } else if (condition.contains('cloud') || condition.contains('overcast')) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF3E4E5C), const Color(0xFF263238)]
            : [const Color(0xFF78909C), const Color(0xFF546E7A)],
      );
    } else if (condition.contains('clear') || condition.contains('sunny')) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF1A237E), const Color(0xFF0D47A1)]
            : [const Color(0xFF42A5F5), const Color(0xFF1E88E5)],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF1E1E2E), const Color(0xFF2A2A3A)]
            : [Colors.white, const Color(0xFFF8F9FA)],
      );
    }
  }

  /// Get shadow color based on weather
  Color _getShadowColor(WeatherData weather, bool isDark) {
    final condition = weather.condition.toLowerCase();
    
    if (condition.contains('rain') || condition.contains('thunder')) {
      return Colors.blueGrey.withOpacity(0.3);
    } else if (condition.contains('cloud')) {
      return Colors.grey.withOpacity(0.2);
    } else if (condition.contains('clear') || condition.contains('sunny')) {
      return Colors.blue.withOpacity(0.2);
    }
    
    return Colors.black.withOpacity(0.15);
  }

  /// Build background decoration
  Widget _buildBackgroundDecoration(WeatherData weather, bool isDark) {
    return Positioned(
      right: -20,
      top: -20,
      child: Opacity(
        opacity: isDark ? 0.05 : 0.1,
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white,
                Colors.white.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Loading state card
  Widget _buildLoadingCard(Color accent, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1E2E), const Color(0xFF2A2A3A)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedLoadingIcon(accent: accent),
          const SizedBox(height: 20),
          Text(
            'Getting weather...',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Error state card
  Widget _buildErrorCard(String error, Color accent, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1E2E), const Color(0xFF2A2A3A)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load weather',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          if (widget.onRefresh != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: TextButton.styleFrom(
                foregroundColor: accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Empty state card
  Widget _buildEmptyCard(Color accent, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1E2E), const Color(0xFF2A2A3A)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wb_cloudy,
            size: 64,
            color: accent.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Check the weather',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to get weather for your location',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    
    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return 'yesterday';
    }
  }
}

/// Animated loading icon
class _AnimatedLoadingIcon extends StatefulWidget {
  final Color accent;

  const _AnimatedLoadingIcon({required this.accent});

  @override
  State<_AnimatedLoadingIcon> createState() => _AnimatedLoadingIconState();
}

class _AnimatedLoadingIconState extends State<_AnimatedLoadingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(widget.accent),
            ),
          ),
        );
      },
    );
  }
}

/// AnimatedBuilder helper (Flutter 3.x compatibility)
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
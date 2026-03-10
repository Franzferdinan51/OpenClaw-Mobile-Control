import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'weather_icon.dart';

/// 5-day forecast card widget
class ForecastCard extends StatelessWidget {
  final List<dynamic> forecast;
  final bool isLoading;
  final Color? accentColor;

  const ForecastCard({
    super.key,
    required this.forecast,
    this.isLoading = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF00D4AA);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isLoading) {
      return _buildLoadingState(accent, isDark);
    }
    
    if (forecast.isEmpty) {
      return _buildEmptyState(accent, isDark);
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E1E2E),
                  const Color(0xFF2A2A3A),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF8F9FA),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Text(
                  '5-Day Forecast',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          // Forecast items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: forecast.take(5).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                final isLast = index == forecast.length - 1;
                
                return _ForecastDayItem(
                  day: day,
                  isDark: isDark,
                  accent: accent,
                  showDivider: !isLast,
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color accent, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading forecast...',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color accent, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No forecast data available',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual forecast day item
class _ForecastDayItem extends StatelessWidget {
  final dynamic day;
  final bool isDark;
  final Color accent;
  final bool showDivider;

  const _ForecastDayItem({
    required this.day,
    required this.isDark,
    required this.accent,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              // Day name
              SizedBox(
                width: 60,
                child: Text(
                  _getDayName(day),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              
              // Weather icon
              SizedBox(
                width: 40,
                height: 40,
                child: WeatherIcon(
                  condition: _getCondition(day),
                  size: 36,
                  animate: false,
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Condition
              Expanded(
                child: Text(
                  _getCondition(day),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Chance of rain
              if (_getRainChance(day) > 0) ...[
                Icon(
                  Icons.water_drop,
                  size: 14,
                  color: Colors.blue[400],
                ),
                const SizedBox(width: 2),
                Text(
                  '${_getRainChance(day)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[400],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              
              // Temperature range
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_getMaxTemp(day).round()}°',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_getMinTemp(day).round()}°',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
      ],
    );
  }

  String _getDayName(dynamic day) {
    try {
      DateTime date;
      if (day is Map) {
        date = day['date'] is DateTime
            ? day['date']
            : DateTime.parse(day['date'].toString());
      } else {
        date = DateTime.now();
      }
      
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
        return DateFormat('EEE').format(date);
      }
    } catch (e) {
      return '---';
    }
  }

  String _getCondition(dynamic day) {
    if (day is Map) {
      return day['condition']?.toString() ?? 'Unknown';
    }
    return 'Unknown';
  }

  int _getRainChance(dynamic day) {
    if (day is Map) {
      return day['chanceOfRain'] ?? 0;
    }
    return 0;
  }

  double _getMaxTemp(dynamic day) {
    if (day is Map) {
      return (day['maxTemp'] ?? day['avgTemp'] ?? 0).toDouble();
    }
    return 0;
  }

  double _getMinTemp(dynamic day) {
    if (day is Map) {
      return (day['minTemp'] ?? day['avgTemp'] ?? 0).toDouble();
    }
    return 0;
  }
}

/// Horizontal forecast strip (compact view)
class ForecastStrip extends StatelessWidget {
  final List<dynamic> forecast;
  final Color? accentColor;

  const ForecastStrip({
    super.key,
    required this.forecast,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF00D4AA);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (forecast.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: forecast.take(5).map((day) {
          return Container(
            width: 72,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2A2A3A).withOpacity(0.8)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accent.withOpacity(0.15),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getDayName(day),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: WeatherIcon(
                    condition: _getCondition(day),
                    size: 28,
                    animate: false,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_getMaxTemp(day).round()}°',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '${_getMinTemp(day).round()}°',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getDayName(dynamic day) {
    try {
      DateTime date;
      if (day is Map) {
        date = day['date'] is DateTime
            ? day['date']
            : DateTime.parse(day['date'].toString());
      } else {
        date = DateTime.now();
      }
      
      return DateFormat('EEE').format(date);
    } catch (e) {
      return '---';
    }
  }

  String _getCondition(dynamic day) {
    if (day is Map) {
      return day['condition']?.toString() ?? 'Unknown';
    }
    return 'Unknown';
  }

  double _getMaxTemp(dynamic day) {
    if (day is Map) {
      return (day['maxTemp'] ?? 0).toDouble();
    }
    return 0;
  }

  double _getMinTemp(dynamic day) {
    if (day is Map) {
      return (day['minTemp'] ?? 0).toDouble();
    }
    return 0;
  }
}
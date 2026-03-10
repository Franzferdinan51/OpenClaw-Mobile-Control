/// Inline Weather Widget
/// 
/// Compact weather widget that appears inline in chat messages.
/// Displays current weather with optional forecast strip.
///
/// Used by ChatMessageWidget when weather data is attached to a message.

import 'package:flutter/material.dart';
import '../models/inline_widget.dart';
import 'weather_icon.dart';

/// Inline weather widget for chat messages
class InlineWeatherWidget extends StatefulWidget {
  final WeatherWidgetData data;
  final bool showForecast;
  final bool isNight;
  final VoidCallback? onTap;

  const InlineWeatherWidget({
    super.key,
    required this.data,
    this.showForecast = false,
    this.isNight = false,
    this.onTap,
  });

  @override
  State<InlineWeatherWidget> createState() => _InlineWeatherWidgetState();
}

class _InlineWeatherWidgetState extends State<InlineWeatherWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF00D4AA);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            gradient: _getGradient(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main weather display
                _buildMainSection(isDark, accent),
                
                // Forecast strip (if available)
                if (widget.showForecast && widget.data.forecast.isNotEmpty)
                  _buildForecastStrip(isDark, accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainSection(bool isDark, Color accent) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Weather icon
          SizedBox(
            width: 56,
            height: 56,
            child: WeatherIcon(
              condition: widget.data.condition,
              iconCode: widget.data.iconCode,
              size: 52,
              isNight: widget.isNight,
            ),
          ),

          const SizedBox(width: 12),

          // Temperature and condition
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${widget.data.temperature.round()}°',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'F',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.data.condition,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withOpacity(0.8)
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Quick stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatRow(
                Icons.water_drop,
                '${widget.data.humidity ?? 0}%',
                Colors.blue[400]!,
                isDark,
              ),
              const SizedBox(height: 4),
              _buildStatRow(
                Icons.air,
                '${(widget.data.windSpeed ?? 0).round()} mph',
                Colors.grey[400]!,
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String value, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildForecastStrip(bool isDark, Color accent) {
    final forecast = widget.data.forecast;
    if (forecast.isEmpty) return const SizedBox.shrink();
    
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: forecast.take(5).map((day) {
          return _buildForecastDay(day, isDark);
        }).toList(),
      ),
    );
  }

  Widget _buildForecastDay(ForecastDayWidgetData day, bool isDark) {
    final dayName = _getDayName(day.date);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dayName,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 24,
          height: 24,
          child: WeatherIcon(
            condition: day.condition,
            iconCode: day.iconCode,
            size: 22,
            animate: false,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${day.high.round()}°',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          '${day.low.round()}°',
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
      ],
    );
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

  LinearGradient _getGradient(bool isDark) {
    final condition = widget.data.condition.toLowerCase();
    
    if (condition.contains('rain') || condition.contains('thunder')) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF37474F), const Color(0xFF263238)]
            : [const Color(0xFF78909C), const Color(0xFF607D8B)],
      );
    } else if (condition.contains('cloud')) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF455A64), const Color(0xFF37474F)]
            : [const Color(0xFFB0BEC5), const Color(0xFF90A4AE)],
      );
    } else if (condition.contains('clear') || condition.contains('sunny')) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
            : [const Color(0xFF42A5F5), const Color(0xFF1E88E5)],
      );
    } else if (widget.isNight) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF1A237E), const Color(0xFF0D1B4D)]
            : [const Color(0xFF3949AB), const Color(0xFF303F9F)],
      );
    }

    // Default gradient
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [const Color(0xFF2A2A3A), const Color(0xFF1E1E2E)]
          : [const Color(0xFFF5F5F5), const Color(0xFFE8E8E8)],
    );
  }
}

/// Mini weather widget for very compact display
class MiniWeatherWidget extends StatelessWidget {
  final WeatherWidgetData data;
  final bool isNight;
  final VoidCallback? onTap;

  const MiniWeatherWidget({
    super.key,
    required this.data,
    this.isNight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: WeatherIcon(
                condition: data.condition,
                size: 24,
                isNight: isNight,
                animate: false,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${data.temperature.round()}°',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              data.condition,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weather loading widget for inline display
class InlineWeatherLoading extends StatelessWidget {
  const InlineWeatherLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxWidth: 200),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Getting weather...',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
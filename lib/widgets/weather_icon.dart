import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Dynamic weather icon widget with animations
class WeatherIcon extends StatefulWidget {
  final String condition;
  final String? iconCode;
  final double size;
  final Color? color;
  final bool animate;
  final bool isNight;

  const WeatherIcon({
    super.key,
    required this.condition,
    this.iconCode,
    this.size = 64,
    this.color,
    this.animate = true,
    this.isNight = false,
  });

  @override
  State<WeatherIcon> createState() => _WeatherIconState();
}

class _WeatherIconState extends State<WeatherIcon>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _rainController;
  late AnimationController _cloudController;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    
    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _rainController.dispose();
    _cloudController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFF00D4AA);
    
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _buildWeatherIcon(color),
    );
  }

  Widget _buildWeatherIcon(Color color) {
    final condition = widget.condition.toLowerCase();
    final isNight = widget.isNight;
    
    // Check for specific conditions
    if (condition.contains('rain') || condition.contains('drizzle')) {
      return _buildRainIcon(color);
    } else if (condition.contains('thunder') || condition.contains('storm')) {
      return _buildThunderIcon(color);
    } else if (condition.contains('snow')) {
      return _buildSnowIcon(color);
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return _buildFogIcon(color);
    } else if (condition.contains('cloud') || condition.contains('overcast')) {
      return _buildCloudyIcon(color, isNight);
    } else if (condition.contains('clear') || condition.contains('sunny')) {
      return isNight ? _buildMoonIcon(color) : _buildSunIcon(color);
    } else if (condition.contains('partly')) {
      return _buildPartlyCloudyIcon(color, isNight);
    } else if (condition.contains('wind')) {
      return _buildWindIcon(color);
    } else {
      // Default to sun/moon based on time
      return isNight ? _buildMoonIcon(color) : _buildSunIcon(color);
    }
  }

  /// Sunny icon with animated rays
  Widget _buildSunIcon(Color color) {
    if (!widget.animate) {
      return Icon(Icons.wb_sunny, size: widget.size, color: const Color(0xFFFFB300));
    }
    
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Sun rays
            ...List.generate(8, (index) {
              final angle = (index * 45 + _rotationController.value * 360) * math.pi / 180;
              return Transform.rotate(
                angle: angle,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 3,
                    height: widget.size * 0.15,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
            // Sun core
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: widget.size * 0.5 * (1 + _pulseController.value * 0.1),
                  height: widget.size * 0.5 * (1 + _pulseController.value * 0.1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFF176),
                        const Color(0xFFFFB300),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB300).withOpacity(0.5),
                        blurRadius: widget.size * 0.2,
                        spreadRadius: widget.size * 0.1,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// Moon icon with stars
  Widget _buildMoonIcon(Color color) {
    if (!widget.animate) {
      return Icon(Icons.nightlight_round, size: widget.size, color: const Color(0xFF90CAF9));
    }
    
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Stars
            Positioned(
              top: widget.size * 0.1,
              right: widget.size * 0.1,
              child: Transform.scale(
                scale: 0.8 + _pulseController.value * 0.2,
                child: Icon(
                  Icons.star,
                  size: widget.size * 0.15,
                  color: const Color(0xFFFFFFFF).withOpacity(0.8),
                ),
              ),
            ),
            Positioned(
              bottom: widget.size * 0.15,
              left: widget.size * 0.05,
              child: Transform.scale(
                scale: 0.6 + _pulseController.value * 0.2,
                child: Icon(
                  Icons.star,
                  size: widget.size * 0.12,
                  color: const Color(0xFFFFFFFF).withOpacity(0.6),
                ),
              ),
            ),
            // Moon
            Container(
              width: widget.size * 0.55,
              height: widget.size * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE3F2FD),
                    const Color(0xFF90CAF9),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF90CAF9).withOpacity(0.3),
                    blurRadius: widget.size * 0.15,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Moon craters
                  Positioned(
                    top: widget.size * 0.15,
                    left: widget.size * 0.15,
                    child: Container(
                      width: widget.size * 0.08,
                      height: widget.size * 0.08,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF64B5F6).withOpacity(0.5),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: widget.size * 0.2,
                    right: widget.size * 0.12,
                    child: Container(
                      width: widget.size * 0.06,
                      height: widget.size * 0.06,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF64B5F6).withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Rain icon with animated drops
  Widget _buildRainIcon(Color color) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Cloud
        Positioned(
          top: 0,
          child: _buildCloudShape(
            const Color(0xFF78909C),
            widget.size * 0.6,
          ),
        ),
        // Rain drops
        if (widget.animate)
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _rainController,
              builder: (context, child) {
                final delay = index * 0.33;
                final progress = (_rainController.value + delay) % 1.0;
                
                return Positioned(
                  left: widget.size * 0.2 + index * widget.size * 0.25,
                  top: widget.size * 0.45 + progress * widget.size * 0.4,
                  child: Opacity(
                    opacity: 1 - progress,
                    child: Container(
                      width: 2,
                      height: widget.size * 0.15,
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A5F5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
      ],
    );
  }

  /// Thunder icon with lightning
  Widget _buildThunderIcon(Color color) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Cloud
        Positioned(
          top: 0,
          child: _buildCloudShape(
            const Color(0xFF546E7A),
            widget.size * 0.6,
          ),
        ),
        // Lightning
        if (widget.animate)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Positioned(
                top: widget.size * 0.4,
                child: Opacity(
                  opacity: _pulseController.value > 0.5 ? 1 : 0.3,
                  child: Icon(
                    Icons.bolt,
                    size: widget.size * 0.35,
                    color: const Color(0xFFFFEB3B),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// Snow icon with animated flakes
  Widget _buildSnowIcon(Color color) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Cloud
        Positioned(
          top: 0,
          child: _buildCloudShape(
            const Color(0xFFB0BEC5),
            widget.size * 0.6,
          ),
        ),
        // Snowflakes
        if (widget.animate)
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _rainController,
              builder: (context, child) {
                final delay = index * 0.33;
                final progress = (_rainController.value + delay) % 1.0;
                
                return Positioned(
                  left: widget.size * 0.15 + index * widget.size * 0.28,
                  top: widget.size * 0.45 + progress * widget.size * 0.35,
                  child: Opacity(
                    opacity: 1 - progress,
                    child: Icon(
                      Icons.ac_unit,
                      size: widget.size * 0.12,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            );
          }),
      ],
    );
  }

  /// Fog icon
  Widget _buildFogIcon(Color color) {
    return AnimatedBuilder(
      animation: _cloudController,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: widget.size * 0.05),
              child: Transform.translate(
                offset: Offset(
                  math.sin(_cloudController.value * math.pi * 2 + index) * widget.size * 0.1,
                  0,
                ),
                child: Container(
                  width: widget.size * (0.6 + index * 0.1),
                  height: widget.size * 0.08,
                  decoration: BoxDecoration(
                    color: const Color(0xFF90A4AE).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(widget.size * 0.04),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// Cloudy icon with animated cloud
  Widget _buildCloudyIcon(Color color, bool isNight) {
    return AnimatedBuilder(
      animation: _cloudController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            math.sin(_cloudController.value * math.pi) * widget.size * 0.05,
            0,
          ),
          child: _buildCloudShape(
            isNight ? const Color(0xFF546E7A) : const Color(0xFF90A4AE),
            widget.size * 0.7,
          ),
        );
      },
    );
  }

  /// Partly cloudy with sun/moon
  Widget _buildPartlyCloudyIcon(Color color, bool isNight) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Sun/Moon behind cloud
        Positioned(
          top: 0,
          right: 0,
          child: SizedBox(
            width: widget.size * 0.5,
            height: widget.size * 0.5,
            child: isNight ? _buildMoonIcon(color) : _buildSunIcon(color),
          ),
        ),
        // Cloud in front
        Positioned(
          bottom: 0,
          left: 0,
          child: AnimatedBuilder(
            animation: _cloudController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  math.sin(_cloudController.value * math.pi) * widget.size * 0.03,
                  0,
                ),
                child: _buildCloudShape(
                  Colors.white,
                  widget.size * 0.55,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Wind icon
  Widget _buildWindIcon(Color color) {
    return AnimatedBuilder(
      animation: _cloudController,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildWindLine(0.7, _cloudController.value),
            SizedBox(height: widget.size * 0.1),
            _buildWindLine(0.9, 1 - _cloudController.value),
            SizedBox(height: widget.size * 0.1),
            _buildWindLine(0.5, _cloudController.value),
          ],
        );
      },
    );
  }

  Widget _buildWindLine(double widthFactor, double offset) {
    return Container(
      width: widget.size * widthFactor,
      height: widget.size * 0.06,
      decoration: BoxDecoration(
        color: const Color(0xFF90A4AE).withOpacity(0.7),
        borderRadius: BorderRadius.horizontal(
          left: const Radius.circular(10),
          right: Radius.circular(widget.size * 0.03),
        ),
      ),
    );
  }

  /// Cloud shape widget
  Widget _buildCloudShape(Color color, double size) {
    return SizedBox(
      width: size,
      height: size * 0.6,
      child: CustomPaint(
        painter: _CloudPainter(color),
      ),
    );
  }
}

/// Custom painter for cloud shape
class _CloudPainter extends CustomPainter {
  final Color color;

  _CloudPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Draw cloud shape
    final baseY = size.height * 0.7;
    final cloudHeight = size.height * 0.5;
    
    // Start from left
    path.moveTo(size.width * 0.1, baseY);
    
    // Left bump
    path.arcToPoint(
      Offset(size.width * 0.25, baseY - cloudHeight * 0.3),
      radius: Radius.circular(size.width * 0.12),
      clockwise: false,
    );
    
    // Top left bump
    path.arcToPoint(
      Offset(size.width * 0.45, baseY - cloudHeight * 0.7),
      radius: Radius.circular(size.width * 0.12),
      clockwise: false,
    );
    
    // Top bump
    path.arcToPoint(
      Offset(size.width * 0.55, baseY - cloudHeight * 0.75),
      radius: Radius.circular(size.width * 0.08),
      clockwise: false,
    );
    
    // Top right bump
    path.arcToPoint(
      Offset(size.width * 0.75, baseY - cloudHeight * 0.6),
      radius: Radius.circular(size.width * 0.12),
      clockwise: false,
    );
    
    // Right bump
    path.arcToPoint(
      Offset(size.width * 0.9, baseY - cloudHeight * 0.2),
      radius: Radius.circular(size.width * 0.1),
      clockwise: false,
    );
    
    // Bottom right
    path.arcToPoint(
      Offset(size.width * 0.85, baseY),
      radius: Radius.circular(size.width * 0.05),
      clockwise: false,
    );
    
    // Bottom line
    path.lineTo(size.width * 0.15, baseY);
    
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Helper for AnimatedBuilder (Flutter 3.x compatibility)
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
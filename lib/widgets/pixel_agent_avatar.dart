import 'dart:math' as math;

import 'package:flutter/material.dart';

const _agentColorPalette = <Color>[
  Color(0xFF4FC3F7),
  Color(0xFFFF7043),
  Color(0xFF66BB6A),
  Color(0xFFAB47BC),
  Color(0xFFFFCA28),
  Color(0xFFEF5350),
];

const _agentAvatarOptions = <String>[
  'glasses',
  'hoodie',
  'suit',
  'casual',
  'robot',
  'cat',
  'dog',
];

class PixelAgentAvatar extends StatelessWidget {
  final String seed;
  final String? emoji;
  final String? model;
  final String? kind;
  final String? identityTheme;
  final bool isActive;
  final bool isSubagent;
  final String? status;
  final double size;
  final bool showStatusDot;
  final bool showEmojiBadge;
  final Color? statusColor;

  const PixelAgentAvatar({
    super.key,
    required this.seed,
    this.emoji,
    this.model,
    this.kind,
    this.identityTheme,
    this.isActive = false,
    this.isSubagent = false,
    this.status,
    this.size = 48,
    this.showStatusDot = true,
    this.showEmojiBadge = false,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final spec = _PixelAgentAvatarSpec.fromSeed(
      seed: seed,
      emoji: emoji,
      model: model,
      kind: kind,
      identityTheme: identityTheme,
      isSubagent: isSubagent,
    );
    final dotColor = statusColor ?? _statusColorFromText(status, isActive);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: spec.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(math.max(10, size * 0.22)),
              border: Border.all(
                color: spec.accent.withValues(alpha: isActive ? 0.62 : 0.28),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: spec.accent.withValues(alpha: isActive ? 0.2 : 0.08),
                  blurRadius: isActive ? 12 : 8,
                  spreadRadius: isActive ? 1.5 : 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(math.max(10, size * 0.22)),
              child: CustomPaint(
                painter: _PixelAgentPainter(spec: spec, isActive: isActive),
                size: Size.square(size),
              ),
            ),
          ),
          if (showEmojiBadge && emoji != null && emoji!.isNotEmpty)
            Positioned(
              top: -3,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: spec.accent.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  emoji!,
                  style: TextStyle(fontSize: math.max(8, size * 0.18)),
                ),
              ),
            ),
          if (showStatusDot)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: math.max(12, size * 0.28),
                height: math.max(12, size * 0.28),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColorFromText(String? currentStatus, bool active) {
    final normalized = currentStatus?.toLowerCase() ?? '';
    if (normalized.contains('error') ||
        normalized.contains('fail') ||
        normalized.contains('abort')) {
      return Colors.red;
    }
    if (normalized.contains('idle') || normalized.contains('wait')) {
      return Colors.orange;
    }
    return active ? Colors.green : Colors.blueGrey;
  }
}

class _PixelAgentAvatarSpec {
  final String avatar;
  final Color accent;
  final _AvatarPalette palette;

  const _PixelAgentAvatarSpec({
    required this.avatar,
    required this.accent,
    required this.palette,
  });

  factory _PixelAgentAvatarSpec.fromSeed({
    required String seed,
    String? emoji,
    String? model,
    String? kind,
    String? identityTheme,
    required bool isSubagent,
  }) {
    final combined =
        '${seed.toLowerCase()}|${emoji ?? ''}|${model ?? ''}|${kind ?? ''}|${identityTheme ?? ''}';
    final lowered = combined.toLowerCase();
    final accent = _accentFromSeed(combined);
    final avatar = _resolveAvatarType(lowered, isSubagent);
    return _PixelAgentAvatarSpec(
      avatar: avatar,
      accent: accent,
      palette: _AvatarPalette.forAvatar(avatar, accent),
    );
  }

  static Color _accentFromSeed(String seed) {
    return _agentColorPalette[seed.hashCode.abs() % _agentColorPalette.length];
  }

  static String _resolveAvatarType(String lowered, bool isSubagent) {
    if (lowered.contains('duck') || lowered.contains('🦆')) {
      return 'duckbot';
    }
    if (isSubagent ||
        lowered.contains('subagent') ||
        lowered.contains('worker') ||
        lowered.contains('tool')) {
      return 'robot';
    }
    if (lowered.contains('cat') ||
        lowered.contains('kitty') ||
        lowered.contains('😺')) {
      return 'cat';
    }
    if (lowered.contains('dog') ||
        lowered.contains('pup') ||
        lowered.contains('🐶')) {
      return 'dog';
    }
    if (lowered.contains('boss') ||
        lowered.contains('manager') ||
        lowered.contains('director') ||
        lowered.contains('claude')) {
      return 'suit';
    }
    if (lowered.contains('hoodie') ||
        lowered.contains('builder') ||
        lowered.contains('coder') ||
        lowered.contains('gpt')) {
      return 'hoodie';
    }
    if (lowered.contains('glass') ||
        lowered.contains('search') ||
        lowered.contains('analyst')) {
      return 'glasses';
    }
    return _agentAvatarOptions[
        lowered.hashCode.abs() % _agentAvatarOptions.length];
  }
}

class _AvatarPalette {
  final Color skin;
  final Color skinShadow;
  final Color hair;
  final Color hairLight;
  final Color top;
  final Color topLight;
  final Color accent;
  final Color accentFrame;
  final Color pants;
  final Color shoes;
  final Color eyes;
  final Color beak;

  const _AvatarPalette({
    required this.skin,
    required this.skinShadow,
    required this.hair,
    required this.hairLight,
    required this.top,
    required this.topLight,
    required this.accent,
    required this.accentFrame,
    required this.pants,
    required this.shoes,
    required this.eyes,
    required this.beak,
  });

  factory _AvatarPalette.forAvatar(String avatar, Color accent) {
    switch (avatar) {
      case 'glasses':
        return _AvatarPalette(
          skin: const Color(0xFFFFDAB9),
          skinShadow: const Color(0xFFE8C4A0),
          hair: const Color(0xFF2D1B00),
          hairLight: const Color(0xFF4A2F10),
          top: const Color(0xFF2D2D3D),
          topLight: const Color(0xFF3D3D4D),
          accent: accent,
          accentFrame: const Color(0xFF333333),
          pants: const Color(0xFF37474F),
          shoes: const Color(0xFF5D4037),
          eyes: const Color(0xFF333333),
          beak: const Color(0xFFFFC107),
        );
      case 'hoodie':
        return _AvatarPalette(
          skin: const Color(0xFFFFDAB9),
          skinShadow: const Color(0xFFE8C4A0),
          hair: const Color(0xFF1A1A1A),
          hairLight: const Color(0xFF333333),
          top: accent,
          topLight: _AvatarPalette._lighten(accent, 0.14),
          accent: Colors.white,
          accentFrame: const Color(0xFFCCCCCC),
          pants: const Color(0xFF37474F),
          shoes: const Color(0xFF424242),
          eyes: const Color(0xFF333333),
          beak: const Color(0xFFFFC107),
        );
      case 'suit':
        return _AvatarPalette(
          skin: const Color(0xFFFFDAB9),
          skinShadow: const Color(0xFFE8C4A0),
          hair: const Color(0xFF3E2723),
          hairLight: const Color(0xFF5D4037),
          top: const Color(0xFF263238),
          topLight: const Color(0xFF37474F),
          accent: accent,
          accentFrame: accent,
          pants: const Color(0xFF1A237E),
          shoes: const Color(0xFF3E2723),
          eyes: const Color(0xFF333333),
          beak: const Color(0xFFFFC107),
        );
      case 'robot':
        return _AvatarPalette(
          skin: const Color(0xFFB0BEC5),
          skinShadow: const Color(0xFF90A4AE),
          hair: const Color(0xFF546E7A),
          hairLight: const Color(0xFF78909C),
          top: const Color(0xFF455A64),
          topLight: const Color(0xFF607D8B),
          accent: accent,
          accentFrame: accent,
          pants: const Color(0xFF37474F),
          shoes: const Color(0xFF263238),
          eyes: accent,
          beak: const Color(0xFFFFC107),
        );
      case 'cat':
        return _AvatarPalette(
          skin: const Color(0xFFFFE0B2),
          skinShadow: const Color(0xFFFFD180),
          hair: const Color(0xFFFF8A65),
          hairLight: const Color(0xFFFFAB91),
          top: accent,
          topLight: _AvatarPalette._lighten(accent, 0.14),
          accent: const Color(0xFFFF7043),
          accentFrame: const Color(0xFFE64A19),
          pants: const Color(0xFF5D4037),
          shoes: const Color(0xFF4E342E),
          eyes: const Color(0xFF333333),
          beak: const Color(0xFFFFC107),
        );
      case 'dog':
        return _AvatarPalette(
          skin: const Color(0xFFD7CCC8),
          skinShadow: const Color(0xFFBCAAA4),
          hair: const Color(0xFF795548),
          hairLight: const Color(0xFF8D6E63),
          top: accent,
          topLight: _AvatarPalette._lighten(accent, 0.14),
          accent: const Color(0xFF3E2723),
          accentFrame: const Color(0xFF4E342E),
          pants: const Color(0xFF455A64),
          shoes: const Color(0xFF37474F),
          eyes: const Color(0xFF333333),
          beak: const Color(0xFFFFC107),
        );
      case 'duckbot':
        return _AvatarPalette(
          skin: const Color(0xFFFFF176),
          skinShadow: const Color(0xFFFBC02D),
          hair: const Color(0xFF455A64),
          hairLight: const Color(0xFF78909C),
          top: accent,
          topLight: _AvatarPalette._lighten(accent, 0.14),
          accent: const Color(0xFF00BCD4),
          accentFrame: const Color(0xFF00838F),
          pants: const Color(0xFF455A64),
          shoes: const Color(0xFF263238),
          eyes: const Color(0xFF1B1B1B),
          beak: const Color(0xFFFFA000),
        );
      default:
        return _AvatarPalette(
          skin: const Color(0xFFFFDAB9),
          skinShadow: const Color(0xFFE8C4A0),
          hair: const Color(0xFF6D4C41),
          hairLight: const Color(0xFF8D6E63),
          top: accent,
          topLight: _AvatarPalette._lighten(accent, 0.16),
          accent: Colors.white,
          accentFrame: const Color(0xFFE0E0E0),
          pants: const Color(0xFF455A64),
          shoes: const Color(0xFF795548),
          eyes: const Color(0xFF333333),
          beak: const Color(0xFFFFC107),
        );
    }
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}

class _PixelAgentPainter extends CustomPainter {
  final _PixelAgentAvatarSpec spec;
  final bool isActive;

  const _PixelAgentPainter({
    required this.spec,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final origin =
        Offset(size.width / 2 - (6 * scale), size.height / 2 - (8.2 * scale));

    final glowPaint = Paint()
      ..color = spec.accent.withValues(alpha: isActive ? 0.16 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2 + scale),
      size.width * 0.28,
      glowPaint,
    );

    _drawShadow(canvas, size, scale);
    _drawHead(canvas, origin, scale, spec.palette);
    _drawAvatarFeatures(canvas, origin, scale, spec.avatar, spec.palette);
    _drawBody(canvas, origin, scale, spec.avatar, spec.palette);
  }

  void _drawShadow(Canvas canvas, Size size, double scale) {
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.86),
          width: size.width * 0.38,
          height: scale * 1.2,
        ),
        const Radius.circular(999),
      ),
      shadowPaint,
    );
  }

  void _drawHead(Canvas canvas, Offset origin, double scale, _AvatarPalette p) {
    for (var i = 3; i <= 8; i++) {
      _px(canvas, origin, scale, i, 2, p.hair);
    }
    for (var i = 2; i <= 9; i++) {
      _px(canvas, origin, scale, i, 3, p.hair);
    }
    for (var i = 3; i <= 8; i++) {
      _px(canvas, origin, scale, i, 4, p.skin);
      _px(canvas, origin, scale, i, 5, p.skin);
      _px(canvas, origin, scale, i, 6, p.skin);
    }
    for (var i = 4; i <= 7; i++) {
      _px(canvas, origin, scale, i, 7, p.skin);
    }
    _px(canvas, origin, scale, 5, 5, p.eyes);
    _px(canvas, origin, scale, 7, 5, p.eyes);
    _px(canvas, origin, scale, 5, 7, p.skinShadow);
    _px(canvas, origin, scale, 6, 7, p.skinShadow);
  }

  void _drawAvatarFeatures(
    Canvas canvas,
    Offset origin,
    double scale,
    String avatar,
    _AvatarPalette p,
  ) {
    switch (avatar) {
      case 'glasses':
        _px(canvas, origin, scale, 4, 5, p.accentFrame);
        _px(canvas, origin, scale, 5, 5, p.accent);
        _px(canvas, origin, scale, 6, 5, p.accentFrame);
        _px(canvas, origin, scale, 7, 5, p.accent);
        _px(canvas, origin, scale, 8, 5, p.accentFrame);
        break;
      case 'hoodie':
        _px(canvas, origin, scale, 2, 4, p.top);
        _px(canvas, origin, scale, 9, 4, p.top);
        _px(canvas, origin, scale, 2, 5, p.topLight);
        _px(canvas, origin, scale, 9, 5, p.topLight);
        break;
      case 'suit':
        _px(canvas, origin, scale, 5, 9, p.accent);
        _px(canvas, origin, scale, 5, 10, p.accent);
        _px(canvas, origin, scale, 6, 10, p.accentFrame);
        break;
      case 'robot':
        _px(canvas, origin, scale, 5, 1, p.accent);
        _px(canvas, origin, scale, 5, 0, p.accentFrame);
        _px(canvas, origin, scale, 4, 4, p.skinShadow);
        _px(canvas, origin, scale, 8, 4, p.skinShadow);
        break;
      case 'cat':
        _px(canvas, origin, scale, 3, 1, p.hairLight);
        _px(canvas, origin, scale, 4, 1, p.hair);
        _px(canvas, origin, scale, 7, 1, p.hair);
        _px(canvas, origin, scale, 8, 1, p.hairLight);
        break;
      case 'dog':
        _px(canvas, origin, scale, 2, 4, p.hair);
        _px(canvas, origin, scale, 2, 5, p.hairLight);
        _px(canvas, origin, scale, 9, 4, p.hair);
        _px(canvas, origin, scale, 9, 5, p.hairLight);
        break;
      case 'duckbot':
        _px(canvas, origin, scale, 4, 1, p.hair);
        _px(canvas, origin, scale, 5, 1, p.hairLight);
        _px(canvas, origin, scale, 6, 1, p.hairLight);
        _px(canvas, origin, scale, 7, 1, p.hair);
        _px(canvas, origin, scale, 5, 6, p.beak);
        _px(canvas, origin, scale, 6, 6, p.beak);
        _px(canvas, origin, scale, 4, 5, p.accentFrame);
        _px(canvas, origin, scale, 5, 5, p.accent);
        _px(canvas, origin, scale, 6, 5, p.accentFrame);
        _px(canvas, origin, scale, 7, 5, p.accent);
        break;
      default:
        break;
    }
  }

  void _drawBody(
    Canvas canvas,
    Offset origin,
    double scale,
    String avatar,
    _AvatarPalette p,
  ) {
    for (var row = 8; row <= 12; row++) {
      for (var i = 3; i <= 8; i++) {
        _px(canvas, origin, scale, i, row, row == 8 ? p.topLight : p.top);
      }
    }
    _px(canvas, origin, scale, 5, 10, p.topLight);
    _px(canvas, origin, scale, 6, 10, p.topLight);
    _px(canvas, origin, scale, 2, 9, p.top);
    _px(canvas, origin, scale, 2, 10, p.skin);
    _px(canvas, origin, scale, 9, 9, p.top);
    _px(canvas, origin, scale, 9, 10, p.skin);
    if (avatar == 'hoodie') {
      _px(canvas, origin, scale, 4, 8, p.top);
      _px(canvas, origin, scale, 7, 8, p.top);
    }
    if (avatar == 'suit') {
      _px(canvas, origin, scale, 4, 9, p.accentFrame);
      _px(canvas, origin, scale, 7, 9, p.accentFrame);
    }
    if (avatar == 'robot') {
      _px(canvas, origin, scale, 5, 9, p.accent);
      _px(canvas, origin, scale, 6, 9, p.accent);
    }
    for (var i = 4; i <= 7; i++) {
      _px(canvas, origin, scale, i, 13, p.pants);
    }
    _px(canvas, origin, scale, 4, 14, p.shoes);
    _px(canvas, origin, scale, 5, 14, p.shoes);
    _px(canvas, origin, scale, 6, 14, p.shoes);
    _px(canvas, origin, scale, 7, 14, p.shoes);
  }

  void _px(
    Canvas canvas,
    Offset origin,
    double scale,
    int x,
    int y,
    Color color,
  ) {
    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(
        origin.dx + (x * scale),
        origin.dy + (y * scale),
        scale,
        scale,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PixelAgentPainter oldDelegate) {
    return oldDelegate.spec != spec || oldDelegate.isActive != isActive;
  }
}

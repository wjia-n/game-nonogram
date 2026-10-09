import 'package:flutter/material.dart';
import 'press_themes.dart';

/// "Craft Letterpress Picross" widget system — the Stitch-derived design
/// language for Nonogram: inked type blocks, cotton paper, brass reglets,
/// cast-iron furniture, warm workshop lamplight from upper-left.
/// No neon, no flat Material look. Everything uses physical material
/// cues: deboss insets, raised plates, bevel highlights, contact shadows.
class Press {
  static const displayFont = 'serif';

  static TextStyle display(double size,
          {Color? color, PressThemeDef? theme}) =>
      TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.brassLight ?? const Color(0xFFE3C77E),
        letterSpacing: 1.0,
        shadows: const [
          Shadow(
              color: Color(0xFF140D06),
              offset: Offset(0, 2),
              blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, PressThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.paper ?? const Color(0xFFF4EFE6),
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, PressThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.brassLight ?? const Color(0xFFE3C77E),
        letterSpacing: 0.8,
      );

  /// Carved/engraved type on paper: dark ink with a paper-light offset for
  /// the debossed letterpress look.
  static TextStyle engraved(double size,
      {PressThemeDef? theme, FontWeight weight = FontWeight.w800}) {
    final t = theme;
    final ink = t?.paperText ?? const Color(0xFF2E2823);
    final light = t?.paper ?? const Color(0xFFF4EFE6);
    return TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      fontWeight: weight,
      color: ink,
      letterSpacing: 0.6,
      shadows: [
        Shadow(color: light.withValues(alpha: 0.85), offset: const Offset(0, 1), blurRadius: 0),
      ],
    );
  }

  static ThemeData theme([PressThemeDef? t]) {
    t ??= PressThemes.byId('classic');
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.benchDark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: t.brass,
        onPrimary: t.benchDeep,
        secondary: t.brassLight,
        onSecondary: t.benchDeep,
        surface: t.benchMid,
        onSurface: t.paper,
        error: t.vermilion,
        onError: t.paper,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.benchMid),
    );
  }
}

/// Oiled workbench backdrop: warm wood gradient, painted grain, lamplight
/// vignette from upper-left.
class WorkshopBackdrop extends StatelessWidget {
  final Widget child;
  final PressThemeDef? theme;
  const WorkshopBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PressThemes.byId('classic');
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.benchMid, t.benchDark, t.benchDeep],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _BenchGrainPainter(t),
        child: child,
      ),
    );
  }
}

class _BenchGrainPainter extends CustomPainter {
  final PressThemeDef t;
  _BenchGrainPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Warm lamplight vignette from upper-left.
    final lamp = RadialGradient(
      center: const Alignment(-0.7, -0.9),
      radius: 1.5,
      colors: [
        t.brassLight.withValues(alpha: 0.14),
        t.benchDark.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.45),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawRect(
        Offset.zero & size, Paint()..shader = lamp.createShader(Offset.zero & size));
    // Wood grain planks.
    final grain = Paint()
      ..color = t.benchDeep.withValues(alpha: 0.22)
      ..strokeWidth = 2.0;
    for (int i = 0; i < 12; i++) {
      final y = size.height * (i + 0.5) / 12;
      final wobble = (i % 3 - 1) * 10.0;
      canvas.drawLine(
          Offset(0, y + wobble), Offset(size.width, y - wobble), grain);
    }
    // Paper flecks.
    final fleck = Paint()..color = t.paper.withValues(alpha: 0.05);
    for (int i = 0; i < 40; i++) {
      final x = (i * 137.5) % size.width;
      final y = (i * 89.3) % size.height;
      canvas.drawCircle(Offset(x, y), 1.2, fleck);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A sheet of cotton paper with deckle edge and subtle grain.
class PaperSheet extends StatelessWidget {
  final Widget child;
  final PressThemeDef? theme;
  final EdgeInsets padding;
  const PaperSheet(
      {super.key,
      required this.child,
      this.theme,
      this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PressThemes.byId('classic');
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.paper, t.paperDeep],
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: const Offset(0, 6),
              blurRadius: 14),
          BoxShadow(
              color: t.brassLight.withValues(alpha: 0.25),
              offset: const Offset(-2, -3),
              blurRadius: 6),
        ],
        border: Border.all(color: t.umber.withValues(alpha: 0.5), width: 1),
      ),
      child: child,
    );
  }
}

/// An engraved brass plaque for titles.
class BrassPlaque extends StatelessWidget {
  final String title;
  final String? subtitle;
  final PressThemeDef? theme;
  final double fontSize;
  const BrassPlaque(
      {super.key,
      required this.title,
      this.subtitle,
      this.theme,
      this.fontSize = 30});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PressThemes.byId('classic');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.iron, t.benchDeep],
        ),
        border: Border.all(color: t.brass, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 6),
              blurRadius: 12),
          BoxShadow(
              color: t.brassLight.withValues(alpha: 0.55),
              offset: const Offset(0, -1),
              blurRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: Press.display(fontSize, theme: t),
              textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: Press.body(14,
                    theme: t, color: t.paper.withValues(alpha: 0.78)),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// Chunky printing-furniture block button: cast-iron face, brass rim,
/// physically presses down.
class BrassButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;
  final PressThemeDef? theme;
  final bool primary;

  const BrassButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 250,
    this.fontSize = 18,
    this.theme,
    this.primary = false,
  });

  @override
  State<BrassButton> createState() => _BrassButtonState();
}

class _BrassButtonState extends State<BrassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? PressThemes.byId('classic');
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 14),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.primary
                ? [t.vermilion, const Color(0xFF8E2F1D)]
                : enabled
                    ? [t.iron, t.benchDeep]
                    : [
                        t.benchDeep.withValues(alpha: 0.7),
                        t.benchDeep.withValues(alpha: 0.5)
                      ],
          ),
          border: Border.all(
              color: widget.primary ? t.brassLight : t.brass, width: 2.5),
          boxShadow: [
            if (!_pressed)
              BoxShadow(
                color: (widget.primary ? t.vermilion : t.brassLight)
                    .withValues(alpha: 0.25),
                offset: const Offset(0, -2),
                blurRadius: 2,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              offset: Offset(0, _pressed ? 2 : 6),
              blurRadius: _pressed ? 4 : 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: Press.display(widget.fontSize,
              theme: t,
              color: enabled
                  ? (widget.primary ? t.paper : t.brassLight)
                  : t.paper.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}

/// Brass press-lever toggle: recessed letterpress track with a sliding
/// woodblock peg. Never a flat iOS switch.
class PressLever extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final PressThemeDef? theme;
  const PressLever(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PressThemes.byId('classic');
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 68,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: value
                ? [t.brassDark, t.brass]
                : [t.benchDeep, t.iron],
          ),
          border: Border.all(color: t.brass, width: 2),
          boxShadow: [
            // Deboss: inset-look via dark top shadow + contact shadow.
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                offset: const Offset(0, 3),
                blurRadius: 4),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          curve: Curves.easeOutBack,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.brassLight, t.brass, t.brassDark],
              ),
              border: Border.all(color: t.benchDeep, width: 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A brass type slug: chunky selector chip that presses DOWN (deboss
/// shadow) when active, never just a color tint.
class TypeSlug extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final PressThemeDef? theme;
  final bool locked;
  const TypeSlug({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.theme,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PressThemes.byId('classic');
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: selected
                ? [t.brassDark, t.brass]
                : [t.iron, t.benchDeep],
          ),
          border: Border.all(
              color: selected ? t.brassLight : t.brass.withValues(alpha: 0.6),
              width: selected ? 2.5 : 1.5),
          boxShadow: selected
              ? [
                  // Pressed down: deboss shadow inside, no lift.
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(0, 1),
                      blurRadius: 3),
                ]
              : [
                  BoxShadow(
                      color: t.brassLight.withValues(alpha: 0.2),
                      offset: const Offset(0, -1),
                      blurRadius: 1),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      offset: const Offset(0, 4),
                      blurRadius: 6),
                ],
        ),
        child: Text(
          label,
          style: Press.label(14,
              theme: t,
              color: selected
                  ? t.benchDeep
                  : locked
                      ? t.paper.withValues(alpha: 0.45)
                      : t.brassLight),
        ),
      ),
    );
  }
}

/// Brass-rimmed paper card used for settings rows and menu cards.
class PressCard extends StatelessWidget {
  final String title;
  final Widget child;
  final PressThemeDef? theme;
  const PressCard(
      {super.key, required this.title, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PressThemes.byId('classic');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.paper, t.paperDeep],
        ),
        border: Border.all(color: t.brass, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 5),
              blurRadius: 10),
          BoxShadow(
              color: t.brassLight.withValues(alpha: 0.3),
              offset: const Offset(0, -1),
              blurRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: Press.engraved(21, theme: t)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A labeled row inside a PressCard (engraved label + control).
class EngravedRow extends StatelessWidget {
  final String label;
  final Widget control;
  final PressThemeDef? theme;
  const EngravedRow(
      {super.key, required this.label, required this.control, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PressThemes.byId('classic');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Press.engraved(15, theme: t))),
          control,
        ],
      ),
    );
  }
}

/// Wooden-bead volume slider on a brass rail.
class BeadSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final PressThemeDef? theme;
  const BeadSlider(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PressThemes.byId('classic');
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: t.brass,
        inactiveTrackColor: t.benchDeep,
        thumbShape: _BeadThumb(t),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _BeadThumb extends SliderComponentShape {
  final PressThemeDef t;
  const _BeadThumb(this.t);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(26, 26);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    canvas.drawCircle(center + const Offset(0, 2), 12,
        Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawCircle(
        center,
        11,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 1.0,
            colors: [t.brassLight, t.brass, t.brassDark],
          ).createShader(Rect.fromCircle(center: center, radius: 11)));
  }
}

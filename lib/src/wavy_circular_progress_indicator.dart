import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/semantics.dart';
import 'package:material_shapes/material_shapes.dart'
    show
        CornerRounding,
        Morph,
        MorphToPathExtension,
        RoundedPolygon,
        RoundedPolygonToPathExtension;
import 'package:material_wavy_progress_indicator/src/end_blocks.dart';
import 'package:material_wavy_progress_indicator/src/wavy_circular_progress_indicator_theme.dart';

const double _kFullAmplitudeProgressMin = 0.1;
const double _kFullAmplitudeProgressMax = 0.9;

const int _kIndeterminateDurationMilliseconds = 6000;

// The progress value below which the track gap is scaled proportionally to
// prevent a track gap from appearing at 0% progress.
const double _kTrackGapRampDownThreshold = 0.01;

// The remaining progress within which a segment is extended, so that the
// rounded ends of a complete ring overlap instead of meeting at a visible
// seam.
const double _kRoundCapRampDownThreshold = 0.01;

// The ring is drawn starting from 12 o'clock.
const int _kStartAngle = 270;

// The fewest wave cycles the ring is ever drawn with. A wave needs a handful of
// cycles to read as one, and this is what puts a ceiling of a third of the
// circumference on the wavelength: past that the cycle count stops falling and
// the wave stops growing.
const int _kMinVertexCount = 3;

// The inner radius of the star has to stay strictly between zero and its outer
// radius, so the amplitude is clamped into a range which always plots a shape.
const double _kMinInnerRadius = 0.05;
const double _kMaxInnerRadius = 0.99;

// The factor by which the depth of the wave is over asked for, to make up for
// the corner rounding of the star cutting its peaks and troughs short of its
// vertices.
const double _kRoundingDepthCompensation = 2.25;

/// A Material Design wavy circular progress indicator, which spins to indicate
/// that the application is busy.
///
/// There are two kinds of circular progress indicators:
///
///  * _Determinate_. Determinate progress indicators have a specific value at
///    each point in time, and the value should increase monotonically from 0.0
///    to 1.0, at which time the indicator is complete. To create a determinate
///    progress indicator, use a non-null [value] between 0.0 and 1.0.
///  * _Indeterminate_. Indeterminate progress indicators do not have a specific
///    value at each point in time and instead indicate that progress is being
///    made without indicating how much progress remains. To create an
///    indeterminate progress indicator, use a null [value].
class WavyCircularProgressIndicator extends StatefulWidget {
  /// Creates a Material Design wavy circular progress indicator.
  const WavyCircularProgressIndicator({
    this.value,
    this.color,
    this.trackColor,
    this.size,
    this.strokeWidth,
    this.cornerRadius,
    this.trackGap,
    this.amplitude,
    this.wavelength,
    this.waveSpeed,
    this.semanticsLabel,
    this.semanticsValue,
    super.key,
  }) : assert(
         size == null || size > 0,
         'size has to be greater than zero.',
       ),
       assert(
         strokeWidth == null || strokeWidth > 0,
         'strokeWidth has to be greater than zero.',
       ),
       assert(
         cornerRadius == null || cornerRadius >= 0,
         'cornerRadius must not be negative.',
       ),
       assert(
         trackGap == null || trackGap >= 0,
         'trackGap must not be negative.',
       ),
       assert(
         amplitude == null || amplitude >= 0,
         'amplitude must not be negative.',
       ),
       assert(
         wavelength == null || wavelength > 0,
         'wavelength has to be greater than zero.',
       ),
       assert(
         waveSpeed == null || waveSpeed >= 0,
         'waveSpeed must not be negative.',
       );

  /// {@template flutter.material.WavyCircularProgressIndicator.value}
  /// The value of this progress indicator.
  ///
  /// A value of 0.0 means no progress and 1.0 means that progress is complete.
  /// The value will be clamped to be in the range [0.0 - 1.0].
  ///
  /// If null, this progress indicator is indeterminate, which means the
  /// indicator displays a predetermined animation that does not indicate how
  /// much actual progress is being made.
  /// {@endtemplate}
  final double? value;

  /// {@template flutter.material.WavyCircularProgressIndicator.color}
  /// The color of the [WavyCircularProgressIndicator]'s active indicator.
  /// {@endtemplate}
  ///
  /// If null, then the [WavyCircularProgressIndicatorThemeData.color] will be
  /// used.
  /// If that is null, then the [ColorScheme.primary] will be used.
  final Color? color;

  /// {@template flutter.material.WavyCircularProgressIndicator.trackColor}
  /// The color of the [WavyCircularProgressIndicator]'s track.
  /// {@endtemplate}
  ///
  /// If null, then the [WavyCircularProgressIndicatorThemeData.trackColor]
  /// will be used.
  /// If that is null, then the [ColorScheme.secondaryContainer] will be used.
  final Color? trackColor;

  /// {@template flutter.material.WavyCircularProgressIndicator.size}
  /// The minimum width and height of the indicator.
  ///
  /// Under a loose constraint the indicator takes exactly this size. It only
  /// renders a larger ring when the parent imposes a larger minimum or a tight
  /// constraint of its own.
  /// {@endtemplate}
  ///
  /// If null, then the [WavyCircularProgressIndicatorThemeData.size] will be
  /// used.
  /// If that is null, then defaults to 48.
  final double? size;

  /// {@template flutter.material.WavyCircularProgressIndicator.strokeWidth}
  /// The width of the active indicator and track.
  /// {@endtemplate}
  ///
  /// If null, then the [WavyCircularProgressIndicatorThemeData.strokeWidth]
  /// will be used.
  /// If that is null, then defaults to 4.
  final double? strokeWidth;

  /// {@template flutter.material.WavyCircularProgressIndicator.cornerRadius}
  /// The radius of the rounded corners of the active indicator and the track.
  /// {@endtemplate}
  ///
  /// Clamped to `strokeWidth / 2`.
  ///
  /// If null, then the [WavyCircularProgressIndicatorThemeData.cornerRadius]
  /// will be used.
  /// If that is null, then defaults to `strokeWidth / 2`, which produces fully
  /// rounded ends.
  final double? cornerRadius;

  /// {@template flutter.material.WavyCircularProgressIndicator.trackGap}
  /// The size of the gap between active indicator and track.
  /// {@endtemplate}
  ///
  /// If null, then the [WavyCircularProgressIndicatorThemeData.trackGap] will
  /// be used.
  /// If that is null, then defaults to 4.
  final double? trackGap;

  /// {@template flutter.material.WavyCircularProgressIndicator.amplitude}
  /// The amplitude of the active indicator wave, measured from the resting
  /// position of the wave to its peak.
  ///
  /// The peaks of the wave sit on the track, and the troughs bulge inward by
  /// twice the amplitude. The peaks are rounded, so an amplitude beyond about an
  /// eighth of the ring radius barely deepens the wave any further.
  ///
  /// The rendered depth is approximate. How much the rounding of the peaks and
  /// the troughs cuts into the depth varies with the wavelength and the size of
  /// the ring, so the wave is drawn with between about 0.8 and 1.1 times the
  /// requested amplitude.
  /// {@endtemplate}
  ///
  /// If null, then the [WavyCircularProgressIndicatorThemeData.amplitude] will
  /// be used.
  /// If that is null, then defaults to 1.6.
  final double? amplitude;

  /// {@template flutter.material.WavyCircularProgressIndicator.wavelength}
  /// The wavelength (distance between two adjacent peaks) of the active
  /// indicator wave.
  ///
  /// The wave has to close seamlessly around the ring, so the rendered
  /// wavelength is rounded to the nearest one which fits a whole number of
  /// times. At least three cycles are always drawn, which caps the wavelength
  /// at a third of the ring's circumference. The rounding changes the shape of
  /// the wave and not the speed it travels at, which stays [waveSpeed] either
  /// way.
  /// {@endtemplate}
  ///
  /// If null, then the [WavyCircularProgressIndicatorThemeData.wavelength] will
  /// be used.
  /// If that is null, then defaults to 15.
  final double? wavelength;

  /// {@template flutter.material.WavyCircularProgressIndicator.waveSpeed}
  /// The speed of the active indicator wave in logical pixels per second,
  /// measured along the ring.
  ///
  /// The wave keeps this speed even where the rendered wavelength differs from
  /// the [wavelength] which was asked for.
  /// {@endtemplate}
  ///
  /// If null, then the [WavyCircularProgressIndicatorThemeData.waveSpeed] will
  /// be used.
  /// If that is null, then defaults to 15.
  final double? waveSpeed;

  /// {@template flutter.material.WavyCircularProgressIndicator.semanticsLabel}
  /// The [SemanticsProperties.label] for this progress indicator.
  ///
  /// This value indicates the purpose of the progress bar, and will be
  /// read out by screen readers to indicate the purpose of this progress
  /// indicator.
  /// {@endtemplate}
  final String? semanticsLabel;

  /// {@template flutter.material.WavyCircularProgressIndicator.semanticsValue}
  /// The [SemanticsProperties.value] for this progress indicator.
  ///
  /// This will be used in conjunction with the [semanticsLabel] by
  /// screen reading software to identify the widget, and is primarily
  /// intended for use with determinate progress indicators to announce
  /// how far along they are.
  ///
  /// For determinate progress indicators, this will be defaulted to
  /// [WavyCircularProgressIndicator.value] expressed as a percentage, i.e.
  /// `0.1` will become `10%`.
  /// {@endtemplate}
  final String? semanticsValue;

  @override
  State<WavyCircularProgressIndicator> createState() =>
      _WavyCircularProgressIndicatorState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      PercentProperty(
        'value',
        value,
        showName: false,
        ifNull: '<indeterminate>',
      ),
    );
  }
}

class _WavyCircularProgressIndicatorState
    extends State<WavyCircularProgressIndicator>
    with TickerProviderStateMixin {
  final _shapes = _WavyCircularProgressIndicatorShapes();

  final _drawingCache = _WavyCircularProgressIndicatorDrawingCache();

  /// Ticks for as long as the wave is in motion.
  ///
  /// The wave travels at a speed in logical pixels per second, so how long it
  /// takes to cover one cycle depends on the circumference of the ring and on
  /// how many cycles fit around it, neither of which is known before the
  /// indicator is painted. So this is kept as a plain clock and the painter
  /// turns the distance it accumulates into a phase, the same way the Android
  /// implementation derives its phase from the system clock while drawing.
  Ticker? _waveClock;

  /// How far the wave has traveled along the ring, in logical pixels.
  ///
  /// The distance is accumulated tick by tick rather than derived from the
  /// total elapsed time, so that a new speed only sets the pace of the wave
  /// from that point on, instead of repricing the ground it has already
  /// covered, which would teleport it to a different phase.
  late final _waveDistance = ValueNotifier<double>(0);

  /// The elapsed time of the previous tick of the current run of [_waveClock],
  /// which counts from zero again every time it is started.
  double _lastTickSeconds = 0;

  /// The speed the wave is currently traveling at, in logical pixels per
  /// second.
  double _currentWaveSpeed = 0;

  late final _amplitudeFractionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final _amplitudeFraction = CurvedAnimation(
    parent: _amplitudeFractionController,
    curve: const Cubic(0.2, 0, 0, 1),
    reverseCurve: const Cubic(0.3, 0, 0.8, 0.15),
  );

  late final _indeterminateValueController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _kIndeterminateDurationMilliseconds),
  );

  double? get _effectiveValue =>
      widget.value == null ? null : clampDouble(widget.value!, 0, 1);

  bool get _isWithinWaveAnimationRange {
    final effectiveValue = _effectiveValue;
    return effectiveValue != null &&
        effectiveValue >= _kFullAmplitudeProgressMin &&
        effectiveValue <= _kFullAmplitudeProgressMax;
  }

  @override
  void initState() {
    super.initState();

    final effectiveValue = _effectiveValue;

    if (effectiveValue == null) {
      unawaited(_indeterminateValueController.repeat());
      _amplitudeFractionController.value = 1;
    } else {
      if (_isWithinWaveAnimationRange) {
        _amplitudeFractionController.value = 1;
      } else {
        _amplitudeFractionController.value = 0;
      }
    }
  }

  @override
  void didUpdateWidget(WavyCircularProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.value != widget.value) {
      final effectiveValue = _effectiveValue;

      if (effectiveValue == null) {
        _indeterminateValueController.reset();
        unawaited(_indeterminateValueController.repeat());
        unawaited(_amplitudeFractionController.forward());
      } else {
        _indeterminateValueController.stop();

        if (_isWithinWaveAnimationRange) {
          unawaited(_amplitudeFractionController.forward());
        } else {
          unawaited(_amplitudeFractionController.reverse());
        }
      }
    }
  }

  @override
  void dispose() {
    _waveClock?.dispose();
    _waveDistance.dispose();
    _amplitudeFraction.dispose();
    _amplitudeFractionController.dispose();
    _indeterminateValueController.dispose();

    super.dispose();
  }

  void _onWaveTick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final delta = seconds - _lastTickSeconds;
    _lastTickSeconds = seconds;

    _waveDistance.value += delta * _currentWaveSpeed;
  }

  void _startWaveClock() {
    final clock = _waveClock ??= createTicker(_onWaveTick);

    if (!clock.isActive) {
      // The clock counts from zero again when it is restarted, so the first
      // tick of the new run has to be measured from zero rather than from
      // wherever the previous run left off.
      _lastTickSeconds = 0;
      unawaited(clock.start());
    }
  }

  void _stopWaveClock() {
    _waveClock?.stop();
  }

  /// Runs or pauses the wave's motion and its amplitude change animation to
  /// match the current configuration.
  void _maybeUpdateAnimations({
    required double amplitude,
    required double waveSpeed,
  }) {
    final effectiveValue = _effectiveValue;
    final isWaving = effectiveValue == null || _isWithinWaveAnimationRange;

    _currentWaveSpeed = waveSpeed;

    if (amplitude > 0 && waveSpeed > 0 && isWaving) {
      _startWaveClock();
    } else {
      _stopWaveClock();
    }

    if (amplitude == 0) {
      _amplitudeFractionController.stop();
      return;
    }

    // The indeterminate indicator waves at its full amplitude throughout, so
    // only the determinate one ramps.
    if (effectiveValue != null) {
      if (_isWithinWaveAnimationRange) {
        if (!_amplitudeFractionController.isAnimating &&
            !_amplitudeFractionController.isCompleted) {
          unawaited(_amplitudeFractionController.forward());
        }
      } else if (!_amplitudeFractionController.isDismissed) {
        unawaited(_amplitudeFractionController.reverse());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    late final indicatorTheme = WavyCircularProgressIndicatorTheme.of(context);
    late final defaults = _WavyCircularProgressIndicatorDefaults(context);

    final effectiveColor =
        widget.color ?? indicatorTheme?.color ?? defaults.color;
    final effectiveTrackColor =
        widget.trackColor ?? indicatorTheme?.trackColor ?? defaults.trackColor;
    final effectiveSize = widget.size ?? indicatorTheme?.size ?? defaults.size;
    final effectiveStrokeWidth =
        widget.strokeWidth ??
        indicatorTheme?.strokeWidth ??
        defaults.strokeWidth;
    final effectiveCornerRadius = math.min(
      widget.cornerRadius ??
          indicatorTheme?.cornerRadius ??
          effectiveStrokeWidth / 2,
      effectiveStrokeWidth / 2,
    );
    final effectiveTrackGap =
        widget.trackGap ?? indicatorTheme?.trackGap ?? defaults.trackGap;
    final effectiveAmplitude =
        widget.amplitude ?? indicatorTheme?.amplitude ?? defaults.amplitude;
    final effectiveWavelength =
        widget.wavelength ?? indicatorTheme?.wavelength ?? defaults.wavelength;
    final effectiveWaveSpeed =
        widget.waveSpeed ?? indicatorTheme?.waveSpeed ?? defaults.waveSpeed;

    _maybeUpdateAnimations(
      amplitude: effectiveAmplitude,
      waveSpeed: effectiveWaveSpeed,
    );

    var semanticsValue = widget.semanticsValue;
    if (semanticsValue == null && _effectiveValue != null) {
      semanticsValue = '${(_effectiveValue! * 100).round()}%';
    }

    return Semantics(
      label: widget.semanticsLabel,
      value: semanticsValue,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: effectiveSize,
          minHeight: effectiveSize,
        ),
        child: CustomPaint(
          painter: _WavyCircularProgressIndicatorPainter(
            cache: _drawingCache,
            shapes: _shapes,
            value: _effectiveValue,
            indeterminateValue: _indeterminateValueController.view,
            color: effectiveColor,
            trackColor: effectiveTrackColor,
            strokeWidth: effectiveStrokeWidth,
            cornerRadius: effectiveCornerRadius,
            trackGap: effectiveTrackGap,
            amplitude: effectiveAmplitude,
            amplitudeFraction: _amplitudeFraction,
            wavelength: effectiveWavelength,
            waveDistance: _waveDistance,
          ),
        ),
      ),
    );
  }
}

/// The circular indicator has no separate indeterminate defaults, as Material
/// specifies a single wavelength for both of its modes.
class _WavyCircularProgressIndicatorDefaults
    extends WavyCircularProgressIndicatorThemeData {
  _WavyCircularProgressIndicatorDefaults(this.context);

  final BuildContext context;

  late final ColorScheme _colorScheme = Theme.of(context).colorScheme;

  @override
  Color get color => _colorScheme.primary;

  @override
  Color get trackColor => _colorScheme.secondaryContainer;

  @override
  double get size => 48;

  @override
  double get strokeWidth => 4;

  @override
  double get trackGap => 4;

  @override
  double get amplitude => 1.6;

  @override
  double get wavelength => 15;

  @override
  double get waveSpeed => 15;
}

class _WavyCircularProgressIndicatorPainter extends CustomPainter {
  _WavyCircularProgressIndicatorPainter({
    required this.cache,
    required this.shapes,
    required this.value,
    required this.indeterminateValue,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.cornerRadius,
    required this.trackGap,
    required this.amplitude,
    required this.amplitudeFraction,
    required this.wavelength,
    required this.waveDistance,
  }) : super(
         repaint: Listenable.merge([
           indeterminateValue,
           amplitudeFraction,
           waveDistance,
         ]),
       );

  // The indeterminate animation spins the indicator three times per cycle,
  // on top of the stepped rotation below.
  static const _globalRotationDegrees = 1080.0;

  // The Material standard easing, which both the stepped rotation and the
  // sweep are eased with.
  static const _standardCurve = Cubic(0.2, 0, 0, 1);

  // On top of the constant spin, the indicator advances by a quarter turn four
  // times per cycle, resting in between.
  static const _rotationStepCount = 4;
  static const _rotationStepDegrees = 90.0;
  static const double _rotationStepDuration =
      500 / _kIndeterminateDurationMilliseconds;
  static const double _rotationStepInterval =
      1500 / _kIndeterminateDurationMilliseconds;

  // The indeterminate sweep grows and shrinks between these two values.
  static const _sweepMin = 0.1;
  static const _sweepMax = 0.87;

  // Where the indeterminate sweep begins, as an offset from the 12 o'clock
  // start of the path it is cut from. It opens a quarter turn further round,
  // at 3 o'clock.
  static const _startOffsetDegrees = 90.0;

  final _WavyCircularProgressIndicatorDrawingCache cache;

  /// The shapes the ring is drawn from. They are updated in [paint], which is
  /// where the size they depend on is known.
  final _WavyCircularProgressIndicatorShapes shapes;

  final double? value;

  final ValueListenable<double> indeterminateValue;

  final Color color;

  final Color trackColor;

  final double strokeWidth;

  final double cornerRadius;

  final double trackGap;

  final double amplitude;

  final ValueListenable<double> amplitudeFraction;

  final double wavelength;

  /// How far the wave has traveled along the ring, in logical pixels.
  /// Together with the circumference of the ring, this is what places the wave.
  final ValueListenable<double> waveDistance;

  late final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = usesStrokeCap(cornerRadius, strokeWidth)
        ? StrokeCap.round
        : StrokeCap.butt;

  late final Paint _fillPaint = Paint();

  /// The block which is stamped at the ends of the drawn segments to round
  /// their corners.
  late final RRect _endBlockRRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset.zero,
      width: cornerRadius * 2,
      height: strokeWidth,
    ),
    Radius.circular(cornerRadius),
  );

  static double _sweep(double t) {
    // Both halves of the cycle are eased forwards, so the segment retreats the
    // way it grew instead of retracing it backwards. Mirroring the time would
    // reverse the curve, which the standard easing is too front loaded to
    // survive.
    final growing = t <= 0.5;
    final eased = _standardCurve.transform(growing ? t * 2 : (t - 0.5) * 2);
    const range = _sweepMax - _sweepMin;

    return growing ? _sweepMin + range * eased : _sweepMax - range * eased;
  }

  static double _additionalRotation(double t) {
    final step = math.min(
      (t / _rotationStepInterval).floor(),
      _rotationStepCount - 1,
    );
    final fraction = clampDouble(
      (t - step * _rotationStepInterval) / _rotationStepDuration,
      0,
      1,
    );

    return (step + _standardCurve.transform(fraction)) * _rotationStepDegrees;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveValue = value;

    final double progress;
    final double rotation;

    if (effectiveValue != null) {
      progress = effectiveValue;
      rotation = 0;
    } else {
      final t = indeterminateValue.value;
      progress = _sweep(t);
      rotation =
          (t * _globalRotationDegrees +
              _additionalRotation(t) +
              _startOffsetDegrees) *
          math.pi /
          180;
    }

    final radius = (size.shortestSide - strokeWidth) / 2;

    if (radius <= 0) {
      // The stroke leaves no room for a ring, so there is nothing to plot and
      // nothing to draw.
      cache.clear();
      return;
    }

    shapes.update(
      radius: radius,
      wavelength: wavelength,
      amplitude: amplitude,
    );

    // The distance the wave has covered is turned into a fraction of a lap.
    // Whole cycles are dropped from it to keep it within the range the cache
    // accepts. The ring looks the same after each one of them, so nothing of
    // the motion is lost with them.
    final waveOffset =
        (waveDistance.value / (2 * math.pi * radius)) %
        (1 / shapes.vertexCount);

    cache.updatePaths(
      size: size,
      shapes: shapes,
      progress: progress,
      amplitude: amplitude,
      amplitudeFraction: amplitudeFraction.value,
      waveOffset: waveOffset,
      trackGap: trackGap,
      strokeWidth: strokeWidth,
      cornerRadius: cornerRadius,
    );

    if (rotation != 0) {
      final center = size.center(Offset.zero);
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(rotation)
        ..translate(-center.dx, -center.dy);
    }

    // Draw the track.
    canvas.drawPath(cache.trackPathToDraw, _strokePaint..color = trackColor);
    _drawEndBlocks(canvas, cache.trackBlocksToDraw, trackColor);

    // Draw the progress.
    canvas.drawPath(cache.progressPathToDraw, _strokePaint..color = color);
    _drawEndBlocks(canvas, cache.progressBlocksToDraw, color);

    if (rotation != 0) {
      canvas.restore();
    }
  }

  void _drawEndBlocks(Canvas canvas, EndBlocks blocks, Color color) {
    if (blocks.length == 0) {
      return;
    }

    _fillPaint.color = color;

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      canvas
        ..save()
        ..translate(block.x, block.y)
        ..rotate(block.rotation)
        ..scale(block.scale)
        ..drawRRect(_endBlockRRect, _fillPaint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_WavyCircularProgressIndicatorPainter oldDelegate) {
    return oldDelegate.cache != cache ||
        oldDelegate.shapes != shapes ||
        oldDelegate.value != value ||
        oldDelegate.indeterminateValue != indeterminateValue ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.trackGap != trackGap ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.amplitudeFraction != amplitudeFraction ||
        oldDelegate.wavelength != wavelength ||
        oldDelegate.waveDistance != waveDistance;
  }
}

/// The shapes which the circular indicator is drawn from, cached between the
/// updates.
///
/// Unlike the linear indicator, which plots its wave from hand rolled cubics,
/// the ring is a [Morph] from a circle to a star shapes. A ring has to close on
/// itself, which a polygon guarantees, and morphing between two shapes whose
/// curves were matched once up front turns an amplitude change into a cheap
/// interpolation instead of a path rebuild.
class _WavyCircularProgressIndicatorShapes {
  static const _rounding = CornerRounding(radius: 0.35, smoothing: 0.4);
  static const _innerRounding = CornerRounding(radius: 0.5);

  var _currentRadius = -1.0;

  var _currentWavelength = -1.0;

  var _currentAmplitude = -1.0;

  int _vertexCount = _kMinVertexCount;

  double _innerRadius = _kMaxInnerRadius;

  late RoundedPolygon _trackPolygon;

  Morph? _morph;

  /// The number of wave cycles around the ring. It is a whole number, which is
  /// what makes the wave close seamlessly.
  int get vertexCount => _vertexCount;

  /// Rebuilds the polygons and their [Morph] if the geometry they were built
  /// for has changed.
  void update({
    required double radius,
    required double wavelength,
    required double amplitude,
  }) {
    assert(radius > 0, 'radius has to be greater than zero.');
    assert(wavelength > 0, 'wavelength has to be greater than zero.');
    assert(amplitude >= 0, 'amplitude must not be negative.');

    if (_morph != null &&
        _currentRadius == radius &&
        _currentWavelength == wavelength &&
        _currentAmplitude == amplitude) {
      return;
    }

    _currentRadius = radius;
    _currentWavelength = wavelength;
    _currentAmplitude = amplitude;

    final vertexCount = math.max(
      _kMinVertexCount,
      (2 * math.pi * radius / wavelength).round(),
    );
    // The star's outer vertices sit on the ring while its inner vertices are
    // pulled towards the center, which would put the peak to trough depth of
    // the wave at twice the amplitude. The corner rounding rounds both extremes
    // off before the vertices are reached, so the inner radius is driven deeper
    // to land on the requested depth.
    final innerRadius = clampDouble(
      1 - 2 * _kRoundingDepthCompensation * amplitude / radius,
      _kMinInnerRadius,
      _kMaxInnerRadius,
    );

    if (_morph != null &&
        vertexCount == _vertexCount &&
        innerRadius == _innerRadius) {
      return;
    }

    _vertexCount = vertexCount;
    _innerRadius = innerRadius;

    // Both polygons are built from the same cycle count, which gives the circle
    // one vertex per wave cycle and the star two, an outer one for the peak and
    // an inner one for the trough. The morph matches the features of the two up
    // front, so the shapes it interpolates in between hold their form.
    //
    // They are left unnormalized, so that both are plotted around the origin
    // with an outer radius of one. Normalizing would fit each of them into the
    // unit square by its own bounding box, which is measured from the control
    // points rather than from the curves, and would leave the two shapes at
    // slightly different scales and centers.
    _trackPolygon = RoundedPolygon.circle(numVertices: vertexCount);

    final star = RoundedPolygon.star(
      numVerticesPerRadius: vertexCount,
      innerRadius: innerRadius,
      rounding: _rounding,
      innerRounding: _innerRounding,
    );
    // The corner rounding cuts the peaks of the star short of its vertices, by
    // a third of the radius at the deep end, which would leave the whole wave
    // floating inside the track. Scaling the star out until its outermost point
    // reaches the ring puts the peaks of the wave back on the track, which is
    // where Java keeps every full wavelength anchor of its wave.
    final maxBounds = star.calculateMaxBounds();
    final peak = (maxBounds[2] - maxBounds[0]) / 2;

    _morph = Morph(
      _trackPolygon,
      star.transformed((x, y) => (x / peak, y / peak)),
    );
  }

  /// The ring at the given morph [progress], where 0 is a plain circle and 1 is
  /// the wave at its full amplitude.
  Path progressPath({required double progress, required Path path}) {
    return _morph!.toPath(
      progress: progress,
      path: path,
      startAngle: _kStartAngle,
      repeatPath: true,
    );
  }

  /// The plain circle which the track is drawn along.
  Path trackPath({required Path path}) {
    return _trackPolygon.toPath(
      path: path,
      startAngle: _kStartAngle,
      repeatPath: true,
    );
  }
}

/// A drawing cache of [Path]s and [PathMetric]s to be used when drawing
/// circular progress indicators.
class _WavyCircularProgressIndicatorDrawingCache {
  var _currentSize = const Size(-1, -1);

  var _currentVertexCount = -1;

  var _currentProgress = -1.0;

  var _currentAmplitude = -1.0;

  var _currentAmplitudeFraction = -1.0;

  var _currentWaveOffset = -1.0;

  var _currentTrackGap = -1.0;

  var _currentStrokeWidth = -1.0;

  /// The current corner radius, which is also the inset of every segment end
  /// from the position it represents.
  var _currentCornerRadius = -1.0;

  /// A [Path] the shapes are plotted into before being placed.
  ///
  /// Plotting resets the [Path] it is given, so a scratch one keeps the placed
  /// paths, which the [PathMetric]s below measure, from being written to while
  /// their metrics are still in use.
  final _scratchPath = Path();

  /// A [Path] that represents the progress indicator when it's in a complete
  /// state.
  var _fullProgressPath = Path();

  /// A [Path] that represents the progress indicator's track when it's in a
  /// complete state.
  var _fullTrackPath = Path();

  PathMetric? _progressPathMetric;

  PathMetric? _trackPathMetric;

  /// The length of a single lap around the ring. Both full paths hold two laps,
  /// so that a segment can be extracted across the point where the ring closes.
  var _progressPathLength = 0.0;

  var _trackPathLength = 0.0;

  /// The center of the ring, which is the pivot of the wave's rotation.
  Offset _center = Offset.zero;

  /// The rotation which holds a segment still as the wave moves through it.
  ///
  /// Rewritten in place on every update, so that drawing allocates nothing.
  final _waveRotation = Matrix4.identity();

  /// A [Path] that represents the track and will be used to draw it.
  Path trackPathToDraw = Path();

  /// The blocks that round the ends of the track segment.
  final trackBlocksToDraw = EndBlocks();

  /// A [Path] that represents the current progress and will be used to draw it.
  Path progressPathToDraw = Path();

  /// The blocks that round the ends of the progress segment.
  final progressBlocksToDraw = EndBlocks();

  /// Creates or updates the full progress and track paths, and caches them to
  /// avoid redundant updates before updating the draw paths according to the
  /// progress.
  void updatePaths({
    required Size size,
    required _WavyCircularProgressIndicatorShapes shapes,
    required double progress,
    required double amplitude,
    required double amplitudeFraction,
    required double waveOffset,
    required double trackGap,
    required double strokeWidth,
    required double cornerRadius,
  }) {
    assert(
      progress >= 0 && progress <= 1,
      'progress has to be in range [0, 1].',
    );
    assert(amplitude >= 0, 'amplitude must not be negative.');
    assert(
      amplitudeFraction >= 0 && amplitudeFraction <= 1,
      'amplitudeFraction has to be in range [0, 1].',
    );
    assert(
      waveOffset >= 0 && waveOffset <= 1,
      'waveOffset has to be in range [0, 1].',
    );
    assert(trackGap >= 0, 'trackGap must not be negative.');
    assert(strokeWidth > 0, 'strokeWidth has to be greater than zero.');
    assert(cornerRadius >= 0, 'cornerRadius must not be negative.');
    assert(
      size.shortestSide > strokeWidth,
      'the stroke leaves no room for a ring.',
    );

    final forceUpdateDrawPaths = _updateFullPaths(
      size: size,
      shapes: shapes,
      amplitude: amplitude,
      amplitudeFraction: amplitudeFraction,
      trackGap: trackGap,
      strokeWidth: strokeWidth,
      cornerRadius: cornerRadius,
    );
    _updateDrawPaths(
      forceUpdate: forceUpdateDrawPaths,
      progress: progress,
      waveOffset: waveOffset,
    );
  }

  /// Drops everything that was cached, so that nothing is drawn until the next
  /// update plots the paths again.
  void clear() {
    _currentSize = const Size(-1, -1);
    trackPathToDraw.reset();
    progressPathToDraw.reset();
    trackBlocksToDraw.reset();
    progressBlocksToDraw.reset();
  }

  /// Creates or updates the full progress and track paths, and caches them to
  /// avoid redundant updates.
  ///
  /// Call this function before calling [_updateDrawPaths], which will cut
  /// segments of the full paths for drawing using the internal [PathMetric]s
  /// that this function updates.
  ///
  /// Returns true if the full paths were updated, or false otherwise.
  bool _updateFullPaths({
    required Size size,
    required _WavyCircularProgressIndicatorShapes shapes,
    required double amplitude,
    required double amplitudeFraction,
    required double trackGap,
    required double strokeWidth,
    required double cornerRadius,
  }) {
    final vertexCount = shapes.vertexCount;

    if (_currentSize == size &&
        _currentVertexCount == vertexCount &&
        _currentAmplitude == amplitude &&
        _currentAmplitudeFraction == amplitudeFraction &&
        _currentTrackGap == trackGap &&
        _currentStrokeWidth == strokeWidth &&
        _currentCornerRadius == cornerRadius) {
      // No update required.
      return false;
    }

    // The shapes are plotted around the origin with an outer radius of one, so
    // they are scaled up to the ring and moved to its center before being
    // measured. The amplitude is baked into the shape rather than applied to
    // the extracted segment, so the metrics are already in pixel space and the
    // tangents read from them need no correction.
    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = size.center(Offset.zero);

    _fullProgressPath = _placePath(
      shapes.progressPath(
        // A zero amplitude keeps the morph at the plain circle it starts from.
        progress: amplitude > 0 ? amplitudeFraction : 0,
        path: _scratchPath,
      ),
      radius,
      center,
    );
    _progressPathMetric = _fullProgressPath.computeMetrics().first;
    _progressPathLength = _progressPathMetric!.length / 2;

    _fullTrackPath = _placePath(
      shapes.trackPath(path: _scratchPath),
      radius,
      center,
    );
    _trackPathMetric = _fullTrackPath.computeMetrics().first;
    _trackPathLength = _trackPathMetric!.length / 2;

    _center = center;

    _currentSize = size;
    _currentVertexCount = vertexCount;
    _currentAmplitude = amplitude;
    _currentAmplitudeFraction = amplitudeFraction;
    _currentTrackGap = trackGap;
    _currentStrokeWidth = strokeWidth;
    _currentCornerRadius = cornerRadius;

    return true;
  }

  /// Scales the given [path], which is plotted around the origin with an outer
  /// radius of one, up to [radius] and moves it to [center].
  Path _placePath(Path path, double radius, Offset center) {
    return path.transform(
      (Matrix4.identity()
            ..translateByDouble(center.dx, center.dy, 0, 1)
            ..scaleByDouble(radius, radius, 1, 1))
          .storage,
    );
  }

  /// Updates and caches the draw paths according to the progress and the wave
  /// offset.
  ///
  /// It's important to call this function only after a call for
  /// [_updateFullPaths] was made.
  ///
  /// [forceUpdate] forces an update to the drawing paths. This flag will be set
  /// to true when the [_updateFullPaths] returns true to indicate that the base
  /// paths were updated.
  void _updateDrawPaths({
    required bool forceUpdate,
    required double progress,
    required double waveOffset,
  }) {
    assert(
      _progressPathMetric != null && _trackPathMetric != null,
      '_updateDrawPaths was called before _updateFullPaths',
    );

    // The track stands still while the wave travels, so it is only recut when
    // the progress or the geometry it is measured against has moved.
    final updateTrack = forceUpdate || _currentProgress != progress;

    if (!updateTrack && _currentWaveOffset == waveOffset) {
      // No update required.
      return;
    }

    final progressMetric = _progressPathMetric!;
    final trackMetric = _trackPathMetric!;

    final cornerRadius = _currentCornerRadius;
    final cornerDiameter = cornerRadius * 2;
    final roundedByStrokeCap = usesStrokeCap(cornerRadius, _currentStrokeWidth);
    // The end blocks are only needed when the round stroke cap can't round the
    // segment ends on its own.
    final needsEndBlocks = !roundedByStrokeCap && cornerRadius > 0;

    // The wave is moved by extracting the segment further along the repeated
    // path and rotating the result back by as much as the shift advanced it
    // around the ring.
    final waveAngle = -waveOffset * 2 * math.pi;
    final isRotated = waveAngle != 0;

    if (isRotated) {
      _waveRotation
        ..setIdentity()
        ..translateByDouble(_center.dx, _center.dy, 0, 1)
        ..rotateZ(waveAngle)
        ..translateByDouble(-_center.dx, -_center.dy, 0, 1);
    }

    // The extra length which is added to a segment that all but closes the
    // ring, so that its two rounded ends overlap instead of meeting at a
    // visible seam.
    double overshootFor(double fraction) {
      final excess = fraction - (1 - _kRoundCapRampDownThreshold);
      return excess > 0
          ? excess * cornerDiameter / _kRoundCapRampDownThreshold
          : 0.0;
    }

    // Adds a block to `blocks` at the given `distance` along the `metric`.
    void addBlock(
      PathMetric metric,
      EndBlocks blocks,
      double distance, {
      bool rotated = false,
      double scale = 1,
    }) {
      final tangent = metric.getTangentForOffset(distance)!;
      final position = rotated
          ? MatrixUtils.transformPoint(_waveRotation, tangent.position)
          : tangent.position;

      blocks.add(
        x: position.dx,
        y: position.dy,
        rotation:
            math.atan2(tangent.vector.dy, tangent.vector.dx) +
            (rotated ? waveAngle : 0),
        scale: scale,
      );
    }

    // Extracts the segment between the `tail` and the `head` distances along
    // the `metric`, and records the blocks which round its ends.
    //
    // Returns null when the segment collapses into a single block.
    Path? extractSegment({
      required PathMetric metric,
      required EndBlocks blocks,
      required double tail,
      required double head,
      bool rotated = false,
    }) {
      final length = head - tail;

      if (length < cornerDiameter) {
        if (length <= 0) {
          return null;
        }

        // The segment is too short to hold both of its end blocks, so a single
        // shrunken block is drawn instead. The block is used even where a round
        // stroke cap would otherwise round the ends, since the cap is drawn at
        // the full stroke width and so can only pop in and out, while the block
        // scales the segment the whole way down to nothing.
        final shrinkRatio = length / cornerDiameter;
        addBlock(
          metric,
          blocks,
          tail + cornerRadius * shrinkRatio,
          rotated: rotated,
          scale: shrinkRatio,
        );
        return null;
      }

      // The segment is drawn between the centers of its end blocks.
      final start = math.max<double>(tail + cornerRadius, 0);
      final end = math.min(head - cornerRadius, metric.length);

      final path = metric.extractPath(start, end);

      if (needsEndBlocks) {
        addBlock(metric, blocks, start, rotated: rotated);
        addBlock(metric, blocks, end, rotated: rotated);
      }

      return rotated ? path.transform(_waveRotation.storage) : path;
    }

    // Reset previously set paths and blocks.
    progressPathToDraw.reset();
    progressBlocksToDraw.reset();
    if (updateTrack) {
      trackPathToDraw.reset();
      trackBlocksToDraw.reset();
    }

    // Track.
    if (updateTrack && progress < 1) {
      // The gap is scaled down as the progress approaches zero, so that it
      // doesn't appear abruptly on an empty indicator.
      final gap =
          _currentTrackGap *
          clampDouble(progress, 0, _kTrackGapRampDownThreshold) /
          _kTrackGapRampDownThreshold;

      var tail = progress * _trackPathLength + gap;
      var head = _trackPathLength - gap;

      final overshoot = overshootFor((head - tail) / _trackPathLength);
      tail -= overshoot / 2;
      head += overshoot / 2;

      final path = extractSegment(
        metric: trackMetric,
        blocks: trackBlocksToDraw,
        tail: tail,
        head: head,
      );
      if (path != null) {
        trackPathToDraw = path;
      }
    }

    // Active indicator.
    if (progress > 0) {
      final shift = waveOffset * _progressPathLength;

      final path = extractSegment(
        metric: progressMetric,
        blocks: progressBlocksToDraw,
        tail: shift,
        head: shift + progress * _progressPathLength + overshootFor(progress),
        rotated: isRotated,
      );
      if (path != null) {
        progressPathToDraw = path;
      }
    }

    // Cache.
    _currentProgress = progress;
    _currentWaveOffset = waveOffset;
  }
}

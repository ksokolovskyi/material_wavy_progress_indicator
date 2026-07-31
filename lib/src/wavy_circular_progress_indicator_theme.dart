import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_wavy_progress_indicator/src/wavy_circular_progress_indicator.dart';

/// Defines the visual properties of [WavyCircularProgressIndicator] widgets.
///
/// Used by [WavyCircularProgressIndicatorTheme] to control the visual
/// properties of wavy circular progress indicators in a widget subtree.
///
/// To obtain this configuration, use [WavyCircularProgressIndicatorTheme.of] to
/// access the closest ancestor [WavyCircularProgressIndicatorTheme] of the
/// current [BuildContext].
///
/// See also:
///
///  * [WavyCircularProgressIndicatorTheme], an [InheritedWidget] that
/// propagates the theme down its subtree.
@immutable
class WavyCircularProgressIndicatorThemeData with Diagnosticable {
  /// Creates the set of properties used to configure
  /// [WavyCircularProgressIndicator] widgets.
  const WavyCircularProgressIndicatorThemeData({
    this.color,
    this.trackColor,
    this.size,
    this.strokeWidth,
    this.cornerRadius,
    this.trackGap,
    this.amplitude,
    this.wavelength,
    this.waveSpeed,
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

  /// {@macro flutter.material.WavyCircularProgressIndicator.color}
  final Color? color;

  /// {@macro flutter.material.WavyCircularProgressIndicator.trackColor}
  final Color? trackColor;

  /// {@macro flutter.material.WavyCircularProgressIndicator.size}
  final double? size;

  /// {@macro flutter.material.WavyCircularProgressIndicator.strokeWidth}
  final double? strokeWidth;

  /// {@macro flutter.material.WavyCircularProgressIndicator.cornerRadius}
  final double? cornerRadius;

  /// {@macro flutter.material.WavyCircularProgressIndicator.trackGap}
  final double? trackGap;

  /// {@macro flutter.material.WavyCircularProgressIndicator.amplitude}
  final double? amplitude;

  /// {@macro flutter.material.WavyCircularProgressIndicator.wavelength}
  final double? wavelength;

  /// {@macro flutter.material.WavyCircularProgressIndicator.waveSpeed}
  final double? waveSpeed;

  /// Creates a copy of this object but with the given fields replaced with the
  /// new values.
  WavyCircularProgressIndicatorThemeData copyWith({
    Color? color,
    Color? trackColor,
    double? size,
    double? strokeWidth,
    double? cornerRadius,
    double? trackGap,
    double? amplitude,
    double? wavelength,
    double? waveSpeed,
  }) {
    return WavyCircularProgressIndicatorThemeData(
      color: color ?? this.color,
      trackColor: trackColor ?? this.trackColor,
      size: size ?? this.size,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      trackGap: trackGap ?? this.trackGap,
      amplitude: amplitude ?? this.amplitude,
      wavelength: wavelength ?? this.wavelength,
      waveSpeed: waveSpeed ?? this.waveSpeed,
    );
  }

  /// Linearly interpolate between two wavy circular progress indicator themes.
  ///
  /// If both arguments are null, then null is returned.
  static WavyCircularProgressIndicatorThemeData? lerp(
    WavyCircularProgressIndicatorThemeData? a,
    WavyCircularProgressIndicatorThemeData? b,
    double t,
  ) {
    if (identical(a, b)) {
      return a;
    }
    return WavyCircularProgressIndicatorThemeData(
      color: Color.lerp(a?.color, b?.color, t),
      trackColor: Color.lerp(a?.trackColor, b?.trackColor, t),
      size: lerpDouble(a?.size, b?.size, t),
      strokeWidth: lerpDouble(a?.strokeWidth, b?.strokeWidth, t),
      cornerRadius: lerpDouble(a?.cornerRadius, b?.cornerRadius, t),
      trackGap: lerpDouble(a?.trackGap, b?.trackGap, t),
      amplitude: lerpDouble(a?.amplitude, b?.amplitude, t),
      wavelength: lerpDouble(a?.wavelength, b?.wavelength, t),
      waveSpeed: lerpDouble(a?.waveSpeed, b?.waveSpeed, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    color,
    trackColor,
    size,
    strokeWidth,
    cornerRadius,
    trackGap,
    amplitude,
    wavelength,
    waveSpeed,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is WavyCircularProgressIndicatorThemeData &&
        other.color == color &&
        other.trackColor == trackColor &&
        other.size == size &&
        other.strokeWidth == strokeWidth &&
        other.cornerRadius == cornerRadius &&
        other.trackGap == trackGap &&
        other.amplitude == amplitude &&
        other.wavelength == wavelength &&
        other.waveSpeed == waveSpeed;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('color', color, defaultValue: null))
      ..add(ColorProperty('trackColor', trackColor, defaultValue: null))
      ..add(DoubleProperty('size', size, defaultValue: null))
      ..add(DoubleProperty('strokeWidth', strokeWidth, defaultValue: null))
      ..add(DoubleProperty('cornerRadius', cornerRadius, defaultValue: null))
      ..add(DoubleProperty('trackGap', trackGap, defaultValue: null))
      ..add(DoubleProperty('amplitude', amplitude, defaultValue: null))
      ..add(DoubleProperty('wavelength', wavelength, defaultValue: null))
      ..add(DoubleProperty('waveSpeed', waveSpeed, defaultValue: null));
  }
}

/// An inherited widget that defines the configuration for
/// [WavyCircularProgressIndicator]s in this widget's subtree.
///
/// Values specified here are used for [WavyCircularProgressIndicator]
/// properties that are not given an explicit non-null value.
///
/// {@tool snippet}
///
/// Here is an example of a wavy circular progress indicator theme that applies
/// a red active indicator color.
///
/// ```dart
/// const WavyCircularProgressIndicatorTheme(
///   data: WavyCircularProgressIndicatorThemeData(
///     color: Colors.red,
///   ),
///   child: WavyCircularProgressIndicator(),
/// )
/// ```
/// {@end-tool}
class WavyCircularProgressIndicatorTheme extends InheritedTheme {
  /// Creates a theme that controls the configurations for
  /// [WavyCircularProgressIndicator] widgets.
  const WavyCircularProgressIndicatorTheme({
    required this.data,
    required super.child,
    super.key,
  });

  /// The properties for descendant [WavyCircularProgressIndicator] widgets.
  final WavyCircularProgressIndicatorThemeData data;

  /// Returns the [data] from the closest [WavyCircularProgressIndicatorTheme]
  /// ancestor. If there is no ancestor, it returns null.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// WavyCircularProgressIndicatorThemeData? theme = WavyCircularProgressIndicatorTheme.of(context);
  /// ```
  static WavyCircularProgressIndicatorThemeData? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<
          WavyCircularProgressIndicatorTheme
        >()
        ?.data;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return WavyCircularProgressIndicatorTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(WavyCircularProgressIndicatorTheme oldWidget) =>
      data != oldWidget.data;
}

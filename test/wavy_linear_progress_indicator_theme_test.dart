import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_wavy_progress_indicator/material_wavy_progress_indicator.dart';

void main() {
  group('$WavyLinearProgressIndicatorThemeData', () {
    const a = WavyLinearProgressIndicatorThemeData(
      color: Color(0xFF000000),
      trackColor: Color(0xFF000000),
      stopIndicatorColor: Color(0xFF000000),
      strokeWidth: 4,
      cornerRadius: 0,
      stopIndicatorWidth: 4,
      trackGap: 4,
      amplitude: 0,
      wavelength: 20,
      waveSpeed: 20,
    );
    const b = WavyLinearProgressIndicatorThemeData(
      color: Color(0xFFFFFFFF),
      trackColor: Color(0xFFFFFFFF),
      stopIndicatorColor: Color(0xFFFFFFFF),
      strokeWidth: 8,
      cornerRadius: 4,
      stopIndicatorWidth: 8,
      trackGap: 8,
      amplitude: 4,
      wavelength: 40,
      waveSpeed: 40,
    );

    // One copy of `a` per property, each differing in that property alone.
    final variants = <String, WavyLinearProgressIndicatorThemeData>{
      'color': a.copyWith(color: b.color),
      'trackColor': a.copyWith(trackColor: b.trackColor),
      'stopIndicatorColor': a.copyWith(
        stopIndicatorColor: b.stopIndicatorColor,
      ),
      'strokeWidth': a.copyWith(strokeWidth: b.strokeWidth),
      'cornerRadius': a.copyWith(cornerRadius: b.cornerRadius),
      'stopIndicatorWidth': a.copyWith(
        stopIndicatorWidth: b.stopIndicatorWidth,
      ),
      'trackGap': a.copyWith(trackGap: b.trackGap),
      'amplitude': a.copyWith(amplitude: b.amplitude),
      'wavelength': a.copyWith(wavelength: b.wavelength),
      'waveSpeed': a.copyWith(waveSpeed: b.waveSpeed),
    };

    group('copyWith', () {
      test('keeps the values when no argument is given', () {
        expect(a.copyWith(), a);
      });

      test('replaces every property', () {
        expect(
          a.copyWith(
            color: b.color,
            trackColor: b.trackColor,
            stopIndicatorColor: b.stopIndicatorColor,
            strokeWidth: b.strokeWidth,
            cornerRadius: b.cornerRadius,
            stopIndicatorWidth: b.stopIndicatorWidth,
            trackGap: b.trackGap,
            amplitude: b.amplitude,
            wavelength: b.wavelength,
            waveSpeed: b.waveSpeed,
          ),
          b,
        );
      });
    });

    group('lerp', () {
      test('returns the bounds at the ends', () {
        expect(WavyLinearProgressIndicatorThemeData.lerp(a, b, 0), a);
        expect(WavyLinearProgressIndicatorThemeData.lerp(a, b, 1), b);
      });

      test('interpolates every property', () {
        final middle = WavyLinearProgressIndicatorThemeData.lerp(a, b, 0.5)!;

        expect(middle.color, Color.lerp(a.color, b.color, 0.5));
        expect(middle.trackColor, Color.lerp(a.trackColor, b.trackColor, 0.5));
        expect(
          middle.stopIndicatorColor,
          Color.lerp(a.stopIndicatorColor, b.stopIndicatorColor, 0.5),
        );
        expect(middle.strokeWidth, 6);
        expect(middle.cornerRadius, 2);
        expect(middle.stopIndicatorWidth, 6);
        expect(middle.trackGap, 6);
        expect(middle.amplitude, 2);
        expect(middle.wavelength, 30);
        expect(middle.waveSpeed, 30);
      });

      test('returns the identical value when both sides are the same', () {
        expect(WavyLinearProgressIndicatorThemeData.lerp(a, a, 0.5), same(a));
        expect(
          WavyLinearProgressIndicatorThemeData.lerp(null, null, 0.5),
          isNull,
        );
      });
    });

    group('identity', () {
      test('is shared by equal instances', () {
        expect(a, a.copyWith());
        expect(a.hashCode, a.copyWith().hashCode);
      });

      for (final MapEntry(key: property, value: variant) in variants.entries) {
        test('is changed by $property', () {
          expect(a, isNot(variant));
          expect(a.hashCode, isNot(variant.hashCode));
        });
      }
    });

    test('exposes every property to the diagnostics', () {
      final properties = DiagnosticPropertiesBuilder();
      b.debugFillProperties(properties);

      expect(
        properties.properties.map((property) => property.toString()),
        containsAll([
          'color: ${b.color}',
          'trackColor: ${b.trackColor}',
          'stopIndicatorColor: ${b.stopIndicatorColor}',
          'strokeWidth: 8.0',
          'cornerRadius: 4.0',
          'stopIndicatorWidth: 8.0',
          'trackGap: 8.0',
          'amplitude: 4.0',
          'wavelength: 40.0',
          'waveSpeed: 40.0',
        ]),
      );
    });

    group('assertions', () {
      final constructors = <String, void Function(double value)>{
        'strokeWidth': (value) =>
            WavyLinearProgressIndicatorThemeData(strokeWidth: value),
        'cornerRadius': (value) =>
            WavyLinearProgressIndicatorThemeData(cornerRadius: value),
        'stopIndicatorWidth': (value) =>
            WavyLinearProgressIndicatorThemeData(stopIndicatorWidth: value),
        'trackGap': (value) =>
            WavyLinearProgressIndicatorThemeData(trackGap: value),
        'amplitude': (value) =>
            WavyLinearProgressIndicatorThemeData(amplitude: value),
        'wavelength': (value) =>
            WavyLinearProgressIndicatorThemeData(wavelength: value),
        'waveSpeed': (value) =>
            WavyLinearProgressIndicatorThemeData(waveSpeed: value),
      };

      for (final MapEntry(key: property, value: create)
          in constructors.entries) {
        test('$property must not be negative', () {
          expect(() => create(-1), throwsA(isA<AssertionError>()));
        });
      }
    });
  });

  group('$WavyLinearProgressIndicatorTheme', () {
    const data = WavyLinearProgressIndicatorThemeData(cornerRadius: 1);

    testWidgets('gives access to the closest data', (tester) async {
      late WavyLinearProgressIndicatorThemeData? resolved;

      await tester.pumpWidget(
        WavyLinearProgressIndicatorTheme(
          data: data,
          child: Builder(
            builder: (context) {
              resolved = WavyLinearProgressIndicatorTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, data);
    });

    testWidgets('resolves to null without an ancestor', (tester) async {
      late WavyLinearProgressIndicatorThemeData? resolved;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved = WavyLinearProgressIndicatorTheme.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolved, isNull);
    });

    test('notifies the dependents only when the data changes', () {
      const theme = WavyLinearProgressIndicatorTheme(
        data: data,
        child: SizedBox(),
      );

      expect(
        theme.updateShouldNotify(
          const WavyLinearProgressIndicatorTheme(
            data: data,
            child: SizedBox(),
          ),
        ),
        isFalse,
      );
      expect(
        theme.updateShouldNotify(
          const WavyLinearProgressIndicatorTheme(
            data: WavyLinearProgressIndicatorThemeData(cornerRadius: 2),
            child: SizedBox(),
          ),
        ),
        isTrue,
      );
    });
  });
}

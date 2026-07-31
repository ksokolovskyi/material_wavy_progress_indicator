import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_wavy_progress_indicator/material_wavy_progress_indicator.dart';

void main() {
  group('$WavyCircularProgressIndicatorThemeData', () {
    const a = WavyCircularProgressIndicatorThemeData(
      color: Color(0xFF000000),
      trackColor: Color(0xFF000000),
      size: 40,
      strokeWidth: 4,
      cornerRadius: 0,
      trackGap: 4,
      amplitude: 0,
      wavelength: 20,
      waveSpeed: 20,
    );
    const b = WavyCircularProgressIndicatorThemeData(
      color: Color(0xFFFFFFFF),
      trackColor: Color(0xFFFFFFFF),
      size: 80,
      strokeWidth: 8,
      cornerRadius: 4,
      trackGap: 8,
      amplitude: 4,
      wavelength: 40,
      waveSpeed: 40,
    );

    // One copy of `a` per property, each differing in that property alone.
    final variants = <String, WavyCircularProgressIndicatorThemeData>{
      'color': a.copyWith(color: b.color),
      'trackColor': a.copyWith(trackColor: b.trackColor),
      'size': a.copyWith(size: b.size),
      'strokeWidth': a.copyWith(strokeWidth: b.strokeWidth),
      'cornerRadius': a.copyWith(cornerRadius: b.cornerRadius),
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
            size: b.size,
            strokeWidth: b.strokeWidth,
            cornerRadius: b.cornerRadius,
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
        expect(WavyCircularProgressIndicatorThemeData.lerp(a, b, 0), a);
        expect(WavyCircularProgressIndicatorThemeData.lerp(a, b, 1), b);
      });

      test('interpolates every property', () {
        final middle = WavyCircularProgressIndicatorThemeData.lerp(a, b, 0.5)!;

        expect(middle.color, Color.lerp(a.color, b.color, 0.5));
        expect(middle.trackColor, Color.lerp(a.trackColor, b.trackColor, 0.5));
        expect(middle.size, 60);
        expect(middle.strokeWidth, 6);
        expect(middle.cornerRadius, 2);
        expect(middle.trackGap, 6);
        expect(middle.amplitude, 2);
        expect(middle.wavelength, 30);
        expect(middle.waveSpeed, 30);
      });

      test('returns the identical value when both sides are the same', () {
        expect(WavyCircularProgressIndicatorThemeData.lerp(a, a, 0.5), same(a));
        expect(
          WavyCircularProgressIndicatorThemeData.lerp(null, null, 0.5),
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
          'size: 80.0',
          'strokeWidth: 8.0',
          'cornerRadius: 4.0',
          'trackGap: 8.0',
          'amplitude: 4.0',
          'wavelength: 40.0',
          'waveSpeed: 40.0',
        ]),
      );
    });

    group('assertions', () {
      final constructors = <String, void Function(double value)>{
        'size': (value) => WavyCircularProgressIndicatorThemeData(size: value),
        'strokeWidth': (value) =>
            WavyCircularProgressIndicatorThemeData(strokeWidth: value),
        'cornerRadius': (value) =>
            WavyCircularProgressIndicatorThemeData(cornerRadius: value),
        'trackGap': (value) =>
            WavyCircularProgressIndicatorThemeData(trackGap: value),
        'amplitude': (value) =>
            WavyCircularProgressIndicatorThemeData(amplitude: value),
        'wavelength': (value) =>
            WavyCircularProgressIndicatorThemeData(wavelength: value),
        'waveSpeed': (value) =>
            WavyCircularProgressIndicatorThemeData(waveSpeed: value),
      };

      for (final MapEntry(key: property, value: create)
          in constructors.entries) {
        test('$property must not be negative', () {
          expect(() => create(-1), throwsA(isA<AssertionError>()));
        });
      }

      for (final property in ['size', 'strokeWidth', 'wavelength']) {
        test('$property must be greater than zero', () {
          expect(
            () => constructors[property]!(0),
            throwsA(isA<AssertionError>()),
          );
        });
      }
    });
  });

  group('$WavyCircularProgressIndicatorTheme', () {
    const data = WavyCircularProgressIndicatorThemeData(cornerRadius: 1);

    testWidgets('gives access to the closest data', (tester) async {
      late WavyCircularProgressIndicatorThemeData? resolved;

      await tester.pumpWidget(
        WavyCircularProgressIndicatorTheme(
          data: data,
          child: Builder(
            builder: (context) {
              resolved = WavyCircularProgressIndicatorTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, data);
    });

    testWidgets('resolves to null without an ancestor', (tester) async {
      late WavyCircularProgressIndicatorThemeData? resolved;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved = WavyCircularProgressIndicatorTheme.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolved, isNull);
    });

    test('notifies the dependents only when the data changes', () {
      const theme = WavyCircularProgressIndicatorTheme(
        data: data,
        child: SizedBox(),
      );

      expect(
        theme.updateShouldNotify(
          const WavyCircularProgressIndicatorTheme(
            data: data,
            child: SizedBox(),
          ),
        ),
        isFalse,
      );
      expect(
        theme.updateShouldNotify(
          const WavyCircularProgressIndicatorTheme(
            data: WavyCircularProgressIndicatorThemeData(cornerRadius: 2),
            child: SizedBox(),
          ),
        ),
        isTrue,
      );
    });
  });
}

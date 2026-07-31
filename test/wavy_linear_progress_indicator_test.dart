import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_wavy_progress_indicator/material_wavy_progress_indicator.dart';

void main() {
  group('$WavyLinearProgressIndicator', () {
    const goldenKey = ValueKey('scene');

    const sceneWidth = 200.0;

    const base = WavyLinearProgressIndicator(value: 0.5);

    final indicator = find.byType(WavyLinearProgressIndicator);

    Widget buildScene(
      Widget child, {
      TextDirection textDirection = TextDirection.ltr,
    }) {
      return MaterialApp(
        home: Directionality(
          textDirection: textDirection,
          child: Center(
            child: RepaintBoundary(
              key: goldenKey,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: SizedBox(width: sceneWidth, child: child),
              ),
            ),
          ),
        ),
      );
    }

    Future<Uint8List> capture(WidgetTester tester) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(goldenKey),
      );

      late Uint8List pixels;

      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        pixels = data!.buffer.asUint8List();
        image.dispose();
      });

      return pixels;
    }

    // Renders the given indicator and returns the raw pixels of the result.
    //
    // The UniqueKey gives every rendering a fresh state, so that the
    // animations are never carried over from the previous one.
    Future<Uint8List> render(
      WidgetTester tester,
      Widget child, {
      TextDirection textDirection = TextDirection.ltr,
    }) async {
      await tester.pumpWidget(
        buildScene(
          KeyedSubtree(key: UniqueKey(), child: child),
          textDirection: textDirection,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      return capture(tester);
    }

    // Flips the pixels horizontally, so that a rendering can be compared with
    // its counterpart from the opposite text direction.
    Uint8List flipped(Uint8List pixels) {
      const bytesPerPixel = 4;
      final width = sceneWidth.toInt();
      final stride = width * bytesPerPixel;
      final result = Uint8List(pixels.length);

      for (var row = 0; row < pixels.length; row += stride) {
        for (var x = 0; x < width; x++) {
          final source = row + x * bytesPerPixel;
          final target = row + (width - 1 - x) * bytesPerPixel;
          result.setRange(target, target + bytesPerPixel, pixels, source);
        }
      }

      return result;
    }

    // The largest color channel difference between two renderings.
    int difference(Uint8List a, Uint8List b) {
      expect(a, hasLength(b.length));

      var result = 0;

      for (var i = 0; i < a.length; i++) {
        final delta = (a[i] - b[i]).abs();

        if (delta > result) {
          result = delta;
        }
      }

      return result;
    }

    Widget themed(WavyLinearProgressIndicatorThemeData data, Widget child) {
      return WavyLinearProgressIndicatorTheme(data: data, child: child);
    }

    group('layout', () {
      testWidgets('takes all of the available width', (tester) async {
        await tester.pumpWidget(buildScene(base));

        expect(tester.getSize(indicator).width, 200);
      });

      testWidgets('is as tall as the wave and the stroke', (tester) async {
        for (final (amplitude, strokeWidth) in [
          (3.0, 4.0),
          (0.0, 4.0),
          (8.0, 20.0),
        ]) {
          await tester.pumpWidget(
            buildScene(
              WavyLinearProgressIndicator(
                value: 0.5,
                strokeWidth: strokeWidth,
                amplitude: amplitude,
              ),
            ),
          );

          expect(
            tester.getSize(indicator).height,
            amplitude * 2 + strokeWidth,
            reason: 'amplitude: $amplitude, strokeWidth: $strokeWidth',
          );
        }
      });

      testWidgets('grows to the given height', (tester) async {
        await tester.pumpWidget(
          buildScene(const SizedBox(height: 48, child: base)),
        );

        expect(tester.getSize(indicator).height, 48);
      });
    });

    group('semantics', () {
      testWidgets('exposes the given label and value', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          buildScene(
            const WavyLinearProgressIndicator(
              value: 0.5,
              semanticsLabel: 'Loading',
              semanticsValue: 'half way',
            ),
          ),
        );

        expect(tester.getSemantics(indicator).label, 'Loading');
        expect(tester.getSemantics(indicator).value, 'half way');

        handle.dispose();
      });

      testWidgets('falls back to the progress percentage', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          buildScene(const WavyLinearProgressIndicator(value: 0.42)),
        );

        expect(tester.getSemantics(indicator).value, '42%');

        handle.dispose();
      });

      testWidgets('has no value when indeterminate', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          buildScene(const WavyLinearProgressIndicator()),
        );

        expect(tester.getSemantics(indicator).value, isEmpty);

        handle.dispose();
      });
    });

    group('value', () {
      for (final textDirection in TextDirection.values) {
        final direction = textDirection.name.toUpperCase();

        testWidgets('is clamped to the [0, 1] range in $direction', (
          tester,
        ) async {
          Future<Uint8List> rendered(double value) {
            return render(
              tester,
              WavyLinearProgressIndicator(value: value),
              textDirection: textDirection,
            );
          }

          expect(listEquals(await rendered(2), await rendered(1)), isTrue);
          expect(listEquals(await rendered(-1), await rendered(0)), isTrue);
        });

        testWidgets(
          'hides the track and the stop indicator when complete in $direction',
          (tester) async {
            // The track and the stop indicator are the only parts painted with
            // these colors, so recoloring them can only change the rendering
            // while they are drawn.
            Future<Uint8List> rendered(double value, Color color) {
              return render(
                tester,
                WavyLinearProgressIndicator(
                  value: value,
                  trackColor: color,
                  stopIndicatorColor: color,
                ),
                textDirection: textDirection,
              );
            }

            expect(
              listEquals(
                await rendered(1, Colors.red),
                await rendered(1, Colors.green),
              ),
              isTrue,
            );
            expect(
              listEquals(
                await rendered(0.5, Colors.red),
                await rendered(0.5, Colors.green),
              ),
              isFalse,
            );
          },
        );
      }
    });

    group('animation', () {
      testWidgets('runs while indeterminate', (tester) async {
        await tester.pumpWidget(
          buildScene(const WavyLinearProgressIndicator()),
        );
        final first = await capture(tester);

        await tester.pump(const Duration(milliseconds: 500));
        final second = await capture(tester);

        expect(listEquals(first, second), isFalse);
      });

      testWidgets('stands still when the wave speed is zero', (tester) async {
        await tester.pumpWidget(
          buildScene(
            const WavyLinearProgressIndicator(value: 0.5, waveSpeed: 0),
          ),
        );
        final first = await capture(tester);

        await tester.pump(const Duration(milliseconds: 500));
        final second = await capture(tester);

        expect(listEquals(first, second), isTrue);
      });

      testWidgets('flattens the wave outside of the amplitude range', (
        tester,
      ) async {
        const flat = WavyLinearProgressIndicator(value: 0.95, waveSpeed: 0);

        await tester.pumpWidget(
          buildScene(
            const WavyLinearProgressIndicator(value: 0.5, waveSpeed: 0),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        // Keeps the state, so that the amplitude ramps down instead of
        // starting flat.
        await tester.pumpWidget(buildScene(flat));
        final rampingDown = await capture(tester);

        await tester.pump(const Duration(milliseconds: 600));
        final rampedDown = await capture(tester);

        final withoutRamp = await render(tester, flat);

        expect(listEquals(rampingDown, rampedDown), isFalse);
        expect(listEquals(rampedDown, withoutRamp), isTrue);
      });
    });

    group('text direction', () {
      // The rasterization of the curved edges is not perfectly symmetric, so
      // the mirrored renderings are only compared up to a fraction of a color
      // channel value. Anything drawn on the wrong side of the track is orders
      // of magnitude off.
      const antiAliasing = 8;

      // Every part of the indicator is mirrored in RTL, so each rendering has
      // to match the horizontally flipped LTR rendering of the same indicator.
      final indicators = <String, Widget>{
        'an empty indicator': const WavyLinearProgressIndicator(value: 0),
        'a barely started indicator': const WavyLinearProgressIndicator(
          value: 0.005,
        ),
        'a half filled indicator': base,
        'an almost complete indicator': const WavyLinearProgressIndicator(
          value: 0.995,
        ),
        'a complete indicator': const WavyLinearProgressIndicator(value: 1),
        'an indicator with square ends': const WavyLinearProgressIndicator(
          value: 0.5,
          cornerRadius: 0,
        ),
        'an indicator without a wave': const WavyLinearProgressIndicator(
          value: 0.5,
          amplitude: 0,
        ),
        'an indeterminate indicator': const WavyLinearProgressIndicator(),
      };

      for (final MapEntry(key: name, value: child) in indicators.entries) {
        testWidgets('$name is mirrored in RTL', (tester) async {
          final ltr = await render(tester, child);
          final rtl = await render(
            tester,
            child,
            textDirection: TextDirection.rtl,
          );

          expect(
            difference(flipped(ltr), rtl),
            lessThanOrEqualTo(antiAliasing),
          );
        });
      }
    });

    group('property resolution', () {
      const overriddenColor = Color(0xFFFF0000);

      final overrides =
          <
            String,
            ({Widget widget, WavyLinearProgressIndicatorThemeData theme})
          >{
            'color': (
              widget: const WavyLinearProgressIndicator(
                value: 0.5,
                color: overriddenColor,
              ),
              theme: const WavyLinearProgressIndicatorThemeData(
                color: overriddenColor,
              ),
            ),
            'trackColor': (
              widget: const WavyLinearProgressIndicator(
                value: 0.5,
                trackColor: overriddenColor,
              ),
              theme: const WavyLinearProgressIndicatorThemeData(
                trackColor: overriddenColor,
              ),
            ),
            'stopIndicatorColor': (
              widget: const WavyLinearProgressIndicator(
                value: 0.5,
                stopIndicatorColor: overriddenColor,
              ),
              theme: const WavyLinearProgressIndicatorThemeData(
                stopIndicatorColor: overriddenColor,
              ),
            ),
            'strokeWidth': (
              widget: const WavyLinearProgressIndicator(
                value: 0.5,
                strokeWidth: 10,
              ),
              theme: const WavyLinearProgressIndicatorThemeData(
                strokeWidth: 10,
              ),
            ),
            'cornerRadius': (
              widget: const WavyLinearProgressIndicator(
                value: 0.5,
                cornerRadius: 0,
              ),
              theme: const WavyLinearProgressIndicatorThemeData(
                cornerRadius: 0,
              ),
            ),
            'stopIndicatorWidth': (
              widget: const WavyLinearProgressIndicator(
                value: 0.5,
                stopIndicatorWidth: 2,
              ),
              theme: const WavyLinearProgressIndicatorThemeData(
                stopIndicatorWidth: 2,
              ),
            ),
            'trackGap': (
              widget: const WavyLinearProgressIndicator(
                value: 0.5,
                trackGap: 20,
              ),
              theme: const WavyLinearProgressIndicatorThemeData(trackGap: 20),
            ),
            'amplitude': (
              widget: const WavyLinearProgressIndicator(
                value: 0.5,
                amplitude: 8,
              ),
              theme: const WavyLinearProgressIndicatorThemeData(amplitude: 8),
            ),
            'wavelength': (
              widget: const WavyLinearProgressIndicator(
                value: 0.5,
                wavelength: 20,
              ),
              theme: const WavyLinearProgressIndicatorThemeData(wavelength: 20),
            ),
            'waveSpeed': (
              widget: const WavyLinearProgressIndicator(
                value: 0.5,
                waveSpeed: 100,
              ),
              theme: const WavyLinearProgressIndicatorThemeData(waveSpeed: 100),
            ),
          };

      for (final MapEntry(key: property, value: override)
          in overrides.entries) {
        testWidgets('$property is taken from the widget and from the theme', (
          tester,
        ) async {
          final fromWidget = await render(tester, override.widget);
          final fromTheme = await render(tester, themed(override.theme, base));
          final byDefault = await render(tester, base);

          expect(listEquals(fromWidget, fromTheme), isTrue);
          // Guards against an override which doesn't change the rendering.
          expect(listEquals(fromWidget, byDefault), isFalse);
        });
      }

      testWidgets('the widget takes precedence over the theme', (tester) async {
        const overridden = WavyLinearProgressIndicator(
          value: 0.5,
          color: overriddenColor,
        );

        final fromWidget = await render(tester, overridden);
        final overriddenTheme = await render(
          tester,
          themed(
            const WavyLinearProgressIndicatorThemeData(
              color: Color(0xFF00FF00),
            ),
            overridden,
          ),
        );

        expect(listEquals(fromWidget, overriddenTheme), isTrue);
      });
    });

    group('cornerRadius', () {
      testWidgets('is clamped to strokeWidth / 2', (tester) async {
        final clamped = await render(
          tester,
          const WavyLinearProgressIndicator(
            value: 0.5,
            strokeWidth: 4,
            cornerRadius: 100,
          ),
        );
        final halfStrokeWidth = await render(
          tester,
          const WavyLinearProgressIndicator(
            value: 0.5,
            strokeWidth: 4,
            cornerRadius: 2,
          ),
        );
        final square = await render(
          tester,
          const WavyLinearProgressIndicator(
            value: 0.5,
            strokeWidth: 4,
            cornerRadius: 0,
          ),
        );

        expect(listEquals(clamped, halfStrokeWidth), isTrue);
        // Guards against a comparison which holds for every corner radius.
        expect(listEquals(clamped, square), isFalse);
      });

      testWidgets('defaults to strokeWidth / 2', (tester) async {
        for (final strokeWidth in [4.0, 12.0]) {
          final byDefault = await render(
            tester,
            WavyLinearProgressIndicator(value: 0.5, strokeWidth: strokeWidth),
          );
          final explicit = await render(
            tester,
            WavyLinearProgressIndicator(
              value: 0.5,
              strokeWidth: strokeWidth,
              cornerRadius: strokeWidth / 2,
            ),
          );

          expect(
            listEquals(byDefault, explicit),
            isTrue,
            reason: 'strokeWidth: $strokeWidth',
          );
        }
      });
    });

    group('assertions', () {
      final constructors = <String, void Function(double value)>{
        'strokeWidth': (value) =>
            WavyLinearProgressIndicator(strokeWidth: value),
        'cornerRadius': (value) =>
            WavyLinearProgressIndicator(cornerRadius: value),
        'stopIndicatorWidth': (value) =>
            WavyLinearProgressIndicator(stopIndicatorWidth: value),
        'trackGap': (value) => WavyLinearProgressIndicator(trackGap: value),
        'amplitude': (value) => WavyLinearProgressIndicator(amplitude: value),
        'wavelength': (value) => WavyLinearProgressIndicator(wavelength: value),
        'waveSpeed': (value) => WavyLinearProgressIndicator(waveSpeed: value),
      };

      for (final MapEntry(key: property, value: create)
          in constructors.entries) {
        test('$property must not be negative', () {
          expect(() => create(-1), throwsA(isA<AssertionError>()));
        });
      }

      for (final property in [
        'strokeWidth',
        'stopIndicatorWidth',
        'wavelength',
      ]) {
        test('$property must be greater than zero', () {
          expect(
            () => constructors[property]!(0),
            throwsA(isA<AssertionError>()),
          );
        });
      }
    });
  });
}

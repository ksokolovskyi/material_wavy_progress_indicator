import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_wavy_progress_indicator/material_wavy_progress_indicator.dart';

void main() {
  group('$WavyCircularProgressIndicator', () {
    const goldenKey = ValueKey('scene');

    const sceneSize = 120.0;

    const base = WavyCircularProgressIndicator(value: 0.5);

    final indicator = find.byType(WavyCircularProgressIndicator);

    // The scene is a fixed square, so that the indicator is free to take its
    // own size and every rendering stays comparable to the next one.
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
                child: SizedBox.square(
                  dimension: sceneSize,
                  child: Center(child: child),
                ),
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

    // How many pixels the part of the indicator painted in `color` covers,
    // counted by recoloring that part and taking the pixels which follow it.
    Future<int> coverage(
      WidgetTester tester,
      Widget Function(Color color) build,
    ) async {
      final a = await render(tester, build(Colors.red));
      final b = await render(tester, build(Colors.green));

      expect(a, hasLength(b.length));

      var count = 0;

      for (var i = 0; i < a.length; i += 4) {
        if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) {
          count++;
        }
      }

      return count;
    }

    Future<int> activeCoverage(WidgetTester tester, double value) {
      return coverage(
        tester,
        (color) => WavyCircularProgressIndicator(value: value, color: color),
      );
    }

    Future<int> trackCoverage(WidgetTester tester, double value) {
      return coverage(
        tester,
        (color) =>
            WavyCircularProgressIndicator(value: value, trackColor: color),
      );
    }

    // The mean color channel difference between two renderings.
    double difference(Uint8List a, Uint8List b) {
      expect(a, hasLength(b.length));

      var total = 0;

      for (var i = 0; i < a.length; i++) {
        total += (a[i] - b[i]).abs();
      }

      return total / a.length;
    }

    Widget themed(WavyCircularProgressIndicatorThemeData data, Widget child) {
      return WavyCircularProgressIndicatorTheme(data: data, child: child);
    }

    group('layout', () {
      testWidgets('is as large as the size when unconstrained', (tester) async {
        await tester.pumpWidget(buildScene(base));
        expect(tester.getSize(indicator), const Size.square(48));
      });

      testWidgets('takes the given size', (tester) async {
        await tester.pumpWidget(
          buildScene(
            const WavyCircularProgressIndicator(value: 0.5, size: 72),
          ),
        );
        expect(tester.getSize(indicator), const Size.square(72));
      });

      testWidgets('grows to fill the available space', (tester) async {
        await tester.pumpWidget(
          buildScene(
            const SizedBox.square(dimension: 96, child: base),
          ),
        );
        expect(tester.getSize(indicator), const Size.square(96));
      });

      // The size is a minimum rather than a floor, so a parent which hands
      // down a tight constraint still wins, as it does for the Material
      // CircularProgressIndicator.
      testWidgets('obeys a tight constraint from the parent', (tester) async {
        await tester.pumpWidget(
          buildScene(
            const SizedBox.square(dimension: 24, child: base),
          ),
        );
        expect(tester.getSize(indicator), const Size.square(24));
      });

      testWidgets('fills a box which is not square', (tester) async {
        await tester.pumpWidget(
          buildScene(
            const SizedBox(width: 120, height: 80, child: base),
          ),
        );
        expect(tester.getSize(indicator), const Size(120, 80));
      });
    });

    // The ring is measured from the painted pixels rather than from the paths,
    // so that where the shapes land on the canvas is covered along with their
    // proportions.
    group('geometry', () {
      const measureKey = ValueKey('measure');

      // The capture is taken at four device pixels per logical pixel, which
      // puts the quantization of a measured edge at a quarter of a pixel.
      const measureRatio = 4.0;
      const measureTolerance = 0.25;

      // The indicators are measured one part at a time, by painting the other
      // part in a color which leaves no trace.
      const opaque = Color(0xFF000000);
      const invisible = Color(0x00000000);

      // The distance from the center of the scene to the nearest and to the
      // furthest painted pixel.
      Future<({double inner, double outer})> extent(
        WidgetTester tester,
        Widget child,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: measureKey,
                child: ColoredBox(
                  color: const Color(0xFFFFFFFF),
                  child: SizedBox.square(
                    dimension: 260,
                    child: Center(
                      child: KeyedSubtree(key: UniqueKey(), child: child),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(measureKey),
        );

        var inner = double.infinity;
        var outer = 0.0;

        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: measureRatio);
          final data = await image.toByteData();
          final pixels = data!.buffer.asUint8List();
          final width = image.width;
          final center = Offset(width / 2, image.height / 2);

          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < width; x++) {
              // A pixel counts as painted once it is at least half covered,
              // which puts the measured edge on the contour the antialiasing
              // is centered on.
              if (pixels[(y * width + x) * 4] > 127) {
                continue;
              }

              final distance =
                  (Offset(x + 0.5, y + 0.5) - center).distance / measureRatio;
              inner = math.min(inner, distance);
              outer = math.max(outer, distance);
            }
          }

          image.dispose();
        });

        return (inner: inner, outer: outer);
      }

      // The track is a plain circle at every amplitude, and the peaks of the
      // wave are scaled out onto the same circle, so both have to reach the ring
      // of `(size - strokeWidth) / 2` no matter how many wave cycles the
      // wavelength asks for. A ring placed by the bounding box of the plotted
      // shapes instead changes size with the vertex count, and a wave which is
      // not scaled out floats inside the track.
      testWidgets('draws the ring at the nominal radius', (tester) async {
        for (final size in [48.0, 200.0]) {
          for (final wavelength in [10.0, 15.0, 20.0, 30.0, 40.0]) {
            const strokeWidth = 4.0;

            Widget ring({required Color color, required Color trackColor}) {
              return WavyCircularProgressIndicator(
                value: 0.5,
                size: size,
                strokeWidth: strokeWidth,
                wavelength: wavelength,
                waveSpeed: 0,
                color: color,
                trackColor: trackColor,
              );
            }

            final track = await extent(
              tester,
              ring(color: invisible, trackColor: opaque),
            );
            final active = await extent(
              tester,
              ring(color: opaque, trackColor: invisible),
            );

            final reason = 'size $size, wavelength $wavelength';

            expect(
              track.outer,
              closeTo(size / 2, measureTolerance),
              reason: reason,
            );
            expect(
              track.inner,
              closeTo(size / 2 - strokeWidth, measureTolerance),
              reason: reason,
            );
            // The troughs of the wave bulge further in than the track, so only
            // its peaks are pinned to the ring.
            expect(
              active.outer,
              closeTo(size / 2, measureTolerance),
              reason: reason,
            );
          }
        }
      });

      // With the wave flat both the track and the active indicator are the
      // same circle, so the two have to be drawn on top of each other. They
      // drift apart if the morph and the track are placed by their own
      // bounding boxes, or rotated about different pivots.
      testWidgets(
        'places the active indicator on the track when the wave is flat',
        (tester) async {
          for (final wavelength in [10.0, 15.0, 20.0, 30.0]) {
            Widget flat({required Color color, required Color trackColor}) {
              return WavyCircularProgressIndicator(
                value: 0.5,
                size: 200,
                strokeWidth: 8,
                trackGap: 0,
                amplitude: 0,
                wavelength: wavelength,
                color: color,
                trackColor: trackColor,
              );
            }

            final track = await extent(
              tester,
              flat(color: invisible, trackColor: opaque),
            );
            final active = await extent(
              tester,
              flat(color: opaque, trackColor: invisible),
            );

            final reason = 'wavelength $wavelength';

            expect(
              active.outer,
              closeTo(track.outer, measureTolerance),
              reason: reason,
            );
            expect(
              active.inner,
              closeTo(track.inner, measureTolerance),
              reason: reason,
            );
            expect(
              active.outer,
              closeTo(100, measureTolerance),
              reason: reason,
            );
            expect(active.inner, closeTo(92, measureTolerance), reason: reason);
          }
        },
      );
    });

    group('semantics', () {
      testWidgets('exposes the given label and value', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          buildScene(
            const WavyCircularProgressIndicator(
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
          buildScene(const WavyCircularProgressIndicator(value: 0.42)),
        );

        expect(tester.getSemantics(indicator).value, '42%');

        handle.dispose();
      });

      testWidgets('has no value when indeterminate', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          buildScene(const WavyCircularProgressIndicator()),
        );

        expect(tester.getSemantics(indicator).value, isEmpty);

        handle.dispose();
      });
    });

    group('value', () {
      testWidgets('is clamped to the [0, 1] range', (tester) async {
        Future<Uint8List> rendered(double value) {
          return render(tester, WavyCircularProgressIndicator(value: value));
        }

        expect(listEquals(await rendered(2), await rendered(1)), isTrue);
        expect(listEquals(await rendered(-1), await rendered(0)), isTrue);
      });

      // A segment shorter than the blocks which cap it is drawn as a single
      // scaled down block, so that it grows in and shrinks away instead of
      // popping to and from the full stroke width.
      testWidgets('grows the active indicator in from nothing', (tester) async {
        // With the default geometry the whole active indicator is a single
        // block up to about 0.029.
        const values = [0.0, 0.005, 0.01, 0.02];

        final covered = [
          for (final value in values) await activeCoverage(tester, value),
        ];

        expect(covered.first, isZero);

        for (var i = 1; i < covered.length; i++) {
          expect(
            covered[i],
            greaterThan(covered[i - 1]),
            reason:
                'the active indicator at ${values[i]} has to cover more '
                'than at ${values[i - 1]}',
          );
        }
      });

      testWidgets('hides the track when complete', (tester) async {
        // The track is the only part painted with this color, so recoloring it
        // can only change the rendering while it is drawn.
        Future<Uint8List> rendered(double value, Color color) {
          return render(
            tester,
            WavyCircularProgressIndicator(value: value, trackColor: color),
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
      });

      // The same the other way round: the track shrinks away as the progress
      // takes the last of its room, rather than holding the full stroke width
      // and sliding up to the top of the ring before it goes.
      testWidgets('shrinks the track away to nothing', (tester) async {
        // With the default geometry the track is a single block from about
        // 0.91, and has no room left at all from about 0.95.
        const values = [0.92, 0.93, 0.94, 0.95];

        final covered = [
          for (final value in values) await trackCoverage(tester, value),
        ];

        expect(covered.last, isZero);

        for (var i = 1; i < covered.length; i++) {
          expect(
            covered[i],
            lessThan(covered[i - 1]),
            reason:
                'the track at ${values[i]} has to cover less than at '
                '${values[i - 1]}',
          );
        }
      });
    });

    group('animation', () {
      testWidgets('runs while indeterminate', (tester) async {
        await tester.pumpWidget(
          buildScene(const WavyCircularProgressIndicator()),
        );
        final first = await capture(tester);

        await tester.pump(const Duration(milliseconds: 500));
        final second = await capture(tester);

        expect(listEquals(first, second), isFalse);
      });

      testWidgets('stands still when the wave speed is zero', (tester) async {
        await tester.pumpWidget(
          buildScene(
            const WavyCircularProgressIndicator(value: 0.5, waveSpeed: 0),
          ),
        );
        final first = await capture(tester);

        await tester.pump(const Duration(milliseconds: 500));
        final second = await capture(tester);

        expect(listEquals(first, second), isTrue);
      });

      // The renderings are compared by their mean difference rather than for
      // equality, as a wave which traveled a whole cycle lands on the same
      // shape up to a fraction of a pixel.
      const settled = 0.5;
      const moved = 1.5;

      testWidgets('repeats itself after a single wave cycle', (tester) async {
        // The wave covers the wavelength it is rendered at, rather than the one
        // that was asked for, in a second of the wave speed.
        const size = 100.0;
        const strokeWidth = 4.0;
        const waveSpeed = 20.0;
        const wavelength = 20.0;

        const circumference = math.pi * (size - strokeWidth);
        final cycles = (circumference / wavelength).round();
        final cycle = Duration(
          milliseconds: (circumference / cycles / waveSpeed * 1000).round(),
        );

        await tester.pumpWidget(
          buildScene(
            const WavyCircularProgressIndicator(
              value: 0.5,
              size: size,
              strokeWidth: strokeWidth,
              wavelength: wavelength,
              waveSpeed: waveSpeed,
            ),
          ),
        );
        // The clock starts counting from the frame after the one it was started
        // on, so the wave stands at the beginning of a cycle here.
        await tester.pump();

        final first = await capture(tester);
        await tester.pump(cycle);
        final afterOneCycle = await capture(tester);
        await tester.pump(cycle * 0.5);
        final betweenCycles = await capture(tester);

        expect(difference(first, afterOneCycle), lessThan(settled));
        expect(difference(first, betweenCycles), greaterThan(moved));
      });

      // The wave speed is a speed along the ring, so the wave has to cover the
      // same ground per second whatever wavelength the ring ends up being drawn
      // with. Driving the phase by the requested wavelength instead slows the
      // wave down as the wavelength grows, even where the ring is drawn exactly
      // the same way.
      testWidgets('moves at the wave speed whatever wavelength is rendered', (
        tester,
      ) async {
        // Both of these wavelengths ask for fewer cycles than the ring is ever
        // drawn with, so they render the same wave.
        Widget wavy({required double wavelength, double waveSpeed = 20}) {
          return WavyCircularProgressIndicator(
            value: 0.5,
            size: 48,
            wavelength: wavelength,
            waveSpeed: waveSpeed,
          );
        }

        // A fresh state for every rendering, so that the clock is never carried
        // over from the previous one, followed by half a cycle of travel.
        Future<Uint8List> traveled(double wavelength) async {
          await tester.pumpWidget(
            buildScene(
              KeyedSubtree(
                key: UniqueKey(),
                child: wavy(wavelength: wavelength),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1200));

          return capture(tester);
        }

        final still = await render(tester, wavy(wavelength: 40, waveSpeed: 0));
        final short = await traveled(40);
        final long = await traveled(100);

        expect(difference(short, long), lessThan(settled));
        expect(difference(short, still), greaterThan(moved));
      });

      // A new speed sets the pace of the wave from the moment it is given,
      // rather than repricing the ground the wave has already covered, which
      // would teleport it to a different phase.
      testWidgets('keeps its phase when the wave speed changes', (
        tester,
      ) async {
        Widget wavy(double waveSpeed) {
          return WavyCircularProgressIndicator(
            value: 0.5,
            size: 120,
            waveSpeed: waveSpeed,
          );
        }

        await tester.pumpWidget(buildScene(wavy(15)));
        await tester.pump();
        // A travel time which leaves the wave part way through a cycle, so
        // that a repriced phase lands somewhere visibly different. A whole
        // number of seconds would happen to land near a cycle boundary and
        // hide the jump.
        await tester.pump(const Duration(milliseconds: 1500));
        final before = await capture(tester);

        // A single frame at the unchanged speed, as a baseline for how far the
        // wave travels between two frames.
        await tester.pump(const Duration(milliseconds: 16));
        final atTheSameSpeed = await capture(tester);

        // Keeps the state, so that the speed of a wave already in motion is
        // changed rather than a new wave being started at the new speed.
        await tester.pumpWidget(buildScene(wavy(30)));
        await tester.pump(const Duration(milliseconds: 16));
        final atDoubleTheSpeed = await capture(tester);

        expect(difference(before, atTheSameSpeed), lessThan(settled));
        // The wave covers twice as much ground in this frame as in the one
        // before it, which is still nothing next to a half wavelength jump.
        expect(difference(atTheSameSpeed, atDoubleTheSpeed), lessThan(moved));
      });

      testWidgets('flattens the wave outside of the amplitude range', (
        tester,
      ) async {
        const flat = WavyCircularProgressIndicator(value: 0.95, waveSpeed: 0);

        await tester.pumpWidget(
          buildScene(
            const WavyCircularProgressIndicator(value: 0.5, waveSpeed: 0),
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

    group('property changes', () {
      // The shapes and the drawing cache are mutated in place and reused
      // across builds, so every property has to invalidate them on its own. A
      // property is changed on a mounted indicator, the way a hot reload does,
      // and has to land on exactly what a fresh mount of it renders.
      Widget indicator({
        Color? color,
        Color? trackColor,
        double size = 80,
        double? strokeWidth,
        double? cornerRadius,
        double? trackGap,
        double? amplitude,
        double? wavelength,
        double value = 0.5,
      }) {
        return WavyCircularProgressIndicator(
          value: value,
          color: color,
          trackColor: trackColor,
          size: size,
          strokeWidth: strokeWidth,
          cornerRadius: cornerRadius,
          trackGap: trackGap,
          amplitude: amplitude,
          wavelength: wavelength,
          waveSpeed: 0,
        );
      }

      final changes = <String, (Widget, Widget)>{
        'color': (
          indicator(color: const Color(0xFF0000FF)),
          indicator(color: const Color(0xFF00FF00)),
        ),
        'trackColor': (
          indicator(trackColor: const Color(0xFFEEEEEE)),
          indicator(trackColor: const Color(0xFF999999)),
        ),
        'size': (indicator(), indicator(size: 110)),
        'strokeWidth': (
          indicator(strokeWidth: 4),
          indicator(strokeWidth: 12),
        ),
        'cornerRadius': (
          indicator(strokeWidth: 12, cornerRadius: 0),
          indicator(strokeWidth: 12, cornerRadius: 6),
        ),
        'trackGap': (indicator(trackGap: 2), indicator(trackGap: 14)),
        'amplitude': (indicator(amplitude: 1.6), indicator(amplitude: 6)),
        'wavelength': (indicator(wavelength: 15), indicator(wavelength: 50)),
        'value': (indicator(), indicator(value: 0.7)),
      };

      for (final MapEntry(key: property, value: (before, after))
          in changes.entries) {
        testWidgets('applies a $property change to a mounted indicator', (
          tester,
        ) async {
          await tester.pumpWidget(buildScene(before));
          await tester.pump(const Duration(milliseconds: 600));
          final rendered = await capture(tester);

          // Keeps the state, so that the indicator is updated rather than
          // rebuilt from scratch.
          await tester.pumpWidget(buildScene(after));
          await tester.pump(const Duration(milliseconds: 600));
          final updated = await capture(tester);

          expect(listEquals(rendered, updated), isFalse);
          expect(listEquals(updated, await render(tester, after)), isTrue);
        });
      }
    });

    group('text direction', () {
      // Unlike the linear indicator, the ring always starts at 12 o'clock and
      // runs clockwise, so nothing about it is mirrored.
      final indicators = <String, Widget>{
        'a half filled indicator': base,
        'a complete indicator': const WavyCircularProgressIndicator(value: 1),
        'an indeterminate indicator': const WavyCircularProgressIndicator(),
      };

      for (final MapEntry(key: name, value: child) in indicators.entries) {
        testWidgets('$name is not mirrored in RTL', (tester) async {
          final ltr = await render(tester, child);
          final rtl = await render(
            tester,
            child,
            textDirection: TextDirection.rtl,
          );

          expect(listEquals(ltr, rtl), isTrue);
        });
      }
    });

    group('property resolution', () {
      const overriddenColor = Color(0xFFFF0000);

      final overrides =
          <
            String,
            ({Widget widget, WavyCircularProgressIndicatorThemeData theme})
          >{
            'color': (
              widget: const WavyCircularProgressIndicator(
                value: 0.5,
                color: overriddenColor,
              ),
              theme: const WavyCircularProgressIndicatorThemeData(
                color: overriddenColor,
              ),
            ),
            'trackColor': (
              widget: const WavyCircularProgressIndicator(
                value: 0.5,
                trackColor: overriddenColor,
              ),
              theme: const WavyCircularProgressIndicatorThemeData(
                trackColor: overriddenColor,
              ),
            ),
            'size': (
              widget: const WavyCircularProgressIndicator(
                value: 0.5,
                size: 80,
              ),
              theme: const WavyCircularProgressIndicatorThemeData(size: 80),
            ),
            'strokeWidth': (
              widget: const WavyCircularProgressIndicator(
                value: 0.5,
                strokeWidth: 10,
              ),
              theme: const WavyCircularProgressIndicatorThemeData(
                strokeWidth: 10,
              ),
            ),
            'cornerRadius': (
              widget: const WavyCircularProgressIndicator(
                value: 0.5,
                cornerRadius: 0,
              ),
              theme: const WavyCircularProgressIndicatorThemeData(
                cornerRadius: 0,
              ),
            ),
            'trackGap': (
              widget: const WavyCircularProgressIndicator(
                value: 0.5,
                trackGap: 20,
              ),
              theme: const WavyCircularProgressIndicatorThemeData(trackGap: 20),
            ),
            'amplitude': (
              widget: const WavyCircularProgressIndicator(
                value: 0.5,
                amplitude: 8,
              ),
              theme: const WavyCircularProgressIndicatorThemeData(amplitude: 8),
            ),
            'wavelength': (
              widget: const WavyCircularProgressIndicator(
                value: 0.5,
                wavelength: 40,
              ),
              theme: const WavyCircularProgressIndicatorThemeData(
                wavelength: 40,
              ),
            ),
            'waveSpeed': (
              widget: const WavyCircularProgressIndicator(
                value: 0.5,
                waveSpeed: 100,
              ),
              theme: const WavyCircularProgressIndicatorThemeData(
                waveSpeed: 100,
              ),
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
        const overridden = WavyCircularProgressIndicator(
          value: 0.5,
          color: overriddenColor,
        );

        final fromWidget = await render(tester, overridden);
        final overriddenTheme = await render(
          tester,
          themed(
            const WavyCircularProgressIndicatorThemeData(
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
          const WavyCircularProgressIndicator(
            value: 0.5,
            strokeWidth: 8,
            cornerRadius: 100,
          ),
        );
        final halfStrokeWidth = await render(
          tester,
          const WavyCircularProgressIndicator(
            value: 0.5,
            strokeWidth: 8,
            cornerRadius: 4,
          ),
        );
        final square = await render(
          tester,
          const WavyCircularProgressIndicator(
            value: 0.5,
            strokeWidth: 8,
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
            WavyCircularProgressIndicator(value: 0.5, strokeWidth: strokeWidth),
          );
          final explicit = await render(
            tester,
            WavyCircularProgressIndicator(
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
        'size': (value) => WavyCircularProgressIndicator(size: value),
        'strokeWidth': (value) =>
            WavyCircularProgressIndicator(strokeWidth: value),
        'cornerRadius': (value) =>
            WavyCircularProgressIndicator(cornerRadius: value),
        'trackGap': (value) => WavyCircularProgressIndicator(trackGap: value),
        'amplitude': (value) => WavyCircularProgressIndicator(amplitude: value),
        'wavelength': (value) =>
            WavyCircularProgressIndicator(wavelength: value),
        'waveSpeed': (value) => WavyCircularProgressIndicator(waveSpeed: value),
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
}

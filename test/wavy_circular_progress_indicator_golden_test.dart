import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_wavy_progress_indicator/material_wavy_progress_indicator.dart';

void main() {
  group('$WavyCircularProgressIndicator', () {
    const goldenKey = ValueKey('scene');

    // The colors are pinned, so that the goldens only depend on the geometry.
    const color = Color(0xFF6750A4);
    const trackColor = Color(0xFFE8DEF8);

    Widget buildScene(List<Widget> children) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: goldenKey,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final child in children)
                      Padding(padding: const EdgeInsets.all(8), child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Builds an indicator with the default geometry.
    Widget buildIndicator({
      double? cornerRadius,
      double? value,
      double? amplitude,
    }) {
      return WavyCircularProgressIndicator(
        value: value,
        color: color,
        trackColor: trackColor,
        cornerRadius: cornerRadius,
        amplitude: amplitude,
      );
    }

    // Builds an indicator which is scaled up, so that the shape of the segment
    // ends is visible in the goldens.
    Widget buildLargeIndicator({
      required double cornerRadius,
      double? value,
      double? amplitude,
      double wavelength = 40,
    }) {
      return WavyCircularProgressIndicator(
        value: value,
        color: color,
        trackColor: trackColor,
        size: 140,
        strokeWidth: 20,
        cornerRadius: cornerRadius,
        trackGap: 10,
        amplitude: amplitude ?? 8,
        wavelength: wavelength,
      );
    }

    Future<void> expectGolden(WidgetTester tester, String name) {
      return expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('goldens/circular_$name.png'),
      );
    }

    group('determinate', () {
      // The progress values around which the ramp, the collapse and the seam
      // logic matter most.
      final values = {0.0, 0.005, 0.1, 0.5, 0.9, 0.995, 1.0};

      for (final cornerRadius in [0.0, 1.0, 2.0]) {
        testWidgets('with cornerRadius of $cornerRadius', (tester) async {
          await tester.pumpWidget(
            buildScene([
              for (final value in values)
                buildIndicator(cornerRadius: cornerRadius, value: value),
            ]),
          );
          await tester.pump(const Duration(milliseconds: 600));

          await expectGolden(tester, 'determinate_corner_radius_$cornerRadius');
        });
      }

      for (final cornerRadius in [0.0, 5.0, 10.0]) {
        testWidgets(
          'with a large stroke and cornerRadius of $cornerRadius',
          (tester) async {
            await tester.pumpWidget(
              buildScene([
                for (final value in [0.005, 0.5, 0.995])
                  buildLargeIndicator(cornerRadius: cornerRadius, value: value),
              ]),
            );
            await tester.pump(const Duration(milliseconds: 600));

            await expectGolden(
              tester,
              'determinate_large_corner_radius_$cornerRadius',
            );
          },
        );
      }

      testWidgets('without a wave', (tester) async {
        await tester.pumpWidget(
          buildScene([
            for (final value in values)
              buildIndicator(value: value, amplitude: 0),
          ]),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await expectGolden(tester, 'determinate_flat');
      });

      // The ring is sized by the shortest side and centered, so it stays
      // circular whichever way the box is stretched.
      testWidgets('in a box which is not square', (tester) async {
        await tester.pumpWidget(
          buildScene([
            for (final size in [
              const Size(140, 90),
              const Size(90, 140),
              const Size(140, 140),
            ])
              SizedBox.fromSize(
                size: size,
                child: buildLargeIndicator(cornerRadius: 10, value: 0.5),
              ),
          ]),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await expectGolden(tester, 'determinate_stretched');
      });

      // The cycle count is rounded to the nearest whole number which fits the
      // ring and never falls below three, so these render as 25, 9, 4 and 3
      // cycles. The 140 wide ring is 377 around, so the floor of three cycles
      // takes over above a wavelength of about 151 and holds the rendered
      // wavelength at 126 from there on.
      testWidgets('with wavelengths up to the cap', (tester) async {
        await tester.pumpWidget(
          buildScene([
            for (final wavelength in [15.0, 40.0, 100.0, 200.0])
              buildLargeIndicator(
                cornerRadius: 10,
                value: 0.5,
                wavelength: wavelength,
              ),
          ]),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await expectGolden(tester, 'determinate_wavelengths');
      });

      testWidgets('with an amplitude beyond the clamp', (tester) async {
        await tester.pumpWidget(
          buildScene([
            for (final amplitude in [0.0, 4.0, 40.0])
              buildLargeIndicator(
                cornerRadius: 10,
                value: 0.5,
                amplitude: amplitude,
              ),
          ]),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await expectGolden(tester, 'determinate_amplitudes');
      });
    });

    group('indeterminate', () {
      // The end of the first step, and the starts and the end of the ones
      // which follow it.
      for (final milliseconds in [500, 1500, 3000, 5000]) {
        testWidgets('at $milliseconds ms', (tester) async {
          await tester.pumpWidget(buildScene([buildIndicator()]));
          await tester.pump(Duration(milliseconds: milliseconds));

          await expectGolden(tester, 'indeterminate_${milliseconds}ms');
        });
      }

      for (final cornerRadius in [0.0, 5.0]) {
        testWidgets(
          'with a large stroke and cornerRadius of $cornerRadius',
          (tester) async {
            await tester.pumpWidget(
              buildScene([buildLargeIndicator(cornerRadius: cornerRadius)]),
            );
            await tester.pump(const Duration(milliseconds: 1500));

            await expectGolden(
              tester,
              'indeterminate_large_corner_radius_$cornerRadius',
            );
          },
        );
      }
    });
  });
}

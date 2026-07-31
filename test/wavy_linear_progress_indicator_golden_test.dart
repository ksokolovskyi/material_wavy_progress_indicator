import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_wavy_progress_indicator/material_wavy_progress_indicator.dart';

void main() {
  group('$WavyLinearProgressIndicator', () {
    const goldenKey = ValueKey('scene');

    // The colors are pinned, so that the goldens only depend on the geometry.
    const color = Color(0xFF6750A4);
    const trackColor = Color(0xFFE8DEF8);

    Widget buildScene(
      List<Widget> children, {
      TextDirection textDirection = TextDirection.ltr,
    }) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Directionality(
          textDirection: textDirection,
          child: Center(
            child: RepaintBoundary(
              key: goldenKey,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: SizedBox(
                  width: 240,
                  child: Column(
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
        ),
      );
    }

    // Builds an indicator with the default geometry.
    Widget buildIndicator({
      double? cornerRadius,
      double? value,
      double? amplitude,
    }) {
      return WavyLinearProgressIndicator(
        value: value,
        color: color,
        trackColor: trackColor,
        stopIndicatorColor: color,
        cornerRadius: cornerRadius,
        amplitude: amplitude,
      );
    }

    // Builds an indicator which is scaled up, so that the shape of the segment
    // ends is visible in the goldens.
    Widget buildLargeIndicator({
      required double cornerRadius,
      double? value,
    }) {
      return WavyLinearProgressIndicator(
        value: value,
        color: color,
        trackColor: trackColor,
        stopIndicatorColor: color,
        strokeWidth: 20,
        cornerRadius: cornerRadius,
        stopIndicatorWidth: 8,
        trackGap: 10,
        amplitude: 8,
        wavelength: 70,
      );
    }

    Future<void> expectGolden(WidgetTester tester, String name) {
      return expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    group('determinate', () {
      // The progress values around which the corner radius logic matters most.
      final values = {0.0, 0.005, 0.5, 0.995, 1.0};

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
                for (final value in values)
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

      testWidgets('in RTL', (tester) async {
        await tester.pumpWidget(
          buildScene(
            [for (final value in values) buildIndicator(value: value)],
            textDirection: TextDirection.rtl,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await expectGolden(tester, 'determinate_rtl');
      });

      testWidgets('with a large stroke in RTL', (tester) async {
        await tester.pumpWidget(
          buildScene(
            [
              for (final cornerRadius in [0.0, 5.0, 10.0])
                buildLargeIndicator(cornerRadius: cornerRadius, value: 0.6),
            ],
            textDirection: TextDirection.rtl,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await expectGolden(tester, 'determinate_large_rtl');
      });
    });

    group('indeterminate', () {
      for (final milliseconds in [300, 900, 1500]) {
        testWidgets('at $milliseconds ms', (tester) async {
          await tester.pumpWidget(buildScene([buildIndicator()]));
          await tester.pump(Duration(milliseconds: milliseconds));

          await expectGolden(tester, 'indeterminate_${milliseconds}ms');
        });
      }

      for (final cornerRadius in [0.0, 5.0]) {
        for (final milliseconds in [300, 900, 1500]) {
          testWidgets(
            'with a large stroke and cornerRadius of $cornerRadius '
            'at $milliseconds ms',
            (tester) async {
              await tester.pumpWidget(
                buildScene([buildLargeIndicator(cornerRadius: cornerRadius)]),
              );
              await tester.pump(Duration(milliseconds: milliseconds));

              await expectGolden(
                tester,
                'indeterminate_large_corner_radius_'
                '${cornerRadius}_${milliseconds}ms',
              );
            },
          );
        }
      }

      testWidgets('with a large stroke in RTL at 900 ms', (tester) async {
        await tester.pumpWidget(
          buildScene(
            [buildLargeIndicator(cornerRadius: 5)],
            textDirection: TextDirection.rtl,
          ),
        );
        await tester.pump(const Duration(milliseconds: 900));

        await expectGolden(tester, 'indeterminate_large_rtl_900ms');
      });
    });
  });
}

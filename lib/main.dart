import 'package:flutter/material.dart';
import 'package:material_wavy_progress_indicator/wavy_linear_progress_indicator.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800 * 3),
  );

  late final _animation = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: 0.33,
      ).chain(CurveTween(curve: Curves.ease)),
      weight: 1020,
    ),
    TweenSequenceItem(tween: ConstantTween(0.33), weight: 320),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.33,
        end: 0.80,
      ).chain(CurveTween(curve: Curves.ease)),
      weight: 720,
    ),
    TweenSequenceItem(tween: ConstantTween(0.80), weight: 520),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.80,
        end: 1,
      ).chain(CurveTween(curve: Curves.linear)),
      weight: 720,
    ),
    TweenSequenceItem(tween: ConstantTween(1), weight: 300),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0,
      ).chain(CurveTween(curve: Curves.ease.flipped)),
      weight: 1600,
    ),
    TweenSequenceItem(tween: ConstantTween(0), weight: 200),
  ]).animate(_controller);

  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();

    _controller.repeat();

    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    _themeMode = platformBrightness == Brightness.light
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: _themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                spacing: 60,
                children: [
                  const WavyLinearProgressIndicator(),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return WavyLinearProgressIndicator(
                        value: _animation.value,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: _ThemeModePicker(
          themeMode: _themeMode,
          onChanged: (themeMode) {
            setState(() {
              _themeMode = themeMode;
            });
          },
        ),
      ),
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({
    required this.themeMode,
    required this.onChanged,
  });

  final ThemeMode themeMode;

  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: IconButton.outlined(
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        onPressed: () {
          onChanged(
            themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
          );
        },
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final isEntering = animation.status == AnimationStatus.forward;
            final isLight = child.key == const ValueKey(ThemeMode.light);

            final startOffset = isEntering
                ? (isLight ? const Offset(0, 1) : const Offset(0, -1))
                : (isLight ? const Offset(0, -1) : const Offset(0, 1));

            return SlideTransition(
              position: Tween<Offset>(
                begin: startOffset,
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: Icon(
            key: ValueKey(themeMode),
            themeMode == ThemeMode.light ? Icons.dark_mode : Icons.light_mode,
          ),
        ),
      ),
    );
  }
}

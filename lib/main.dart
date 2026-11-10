import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'streak.dart';

void main() => runApp(const SlothApp());

class SlothApp extends StatelessWidget {
  const SlothApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'Sloth',
      theme: CupertinoThemeData(
        scaffoldBackgroundColor: Color(0xFFF8F8F6),
      ),
      home: RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool loaded = false;
  bool onboarded = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loaded = false;
      loadError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        onboarded = prefs.getBool('onboarded') ?? false;
        loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loaded = true;
        loadError = 'Sloth could not load your saved data.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (loadError case final error?) {
      return CupertinoPageScaffold(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                CupertinoButton.filled(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return onboarded ? const HabitScreen() : const OnboardingScreen();
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = TextEditingController(text: 'Did I walk today?');
  bool saving = false;
  String? saveError;

  Future<void> _continue() async {
    if (saving) return;
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'question',
          controller.text.trim().isEmpty
              ? 'Did I walk today?'
              : controller.text.trim());
      await prefs.setBool('onboarded', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const HabitScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        saving = false;
        saveError = 'Could not save your habit. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Welcome to Sloth'),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'What is your one thing?',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  CupertinoTextField(
                    controller: controller,
                    placeholder: 'Did I call my mom today?',
                    padding: const EdgeInsets.all(16),
                    enabled: !saving,
                  ),
                  if (saveError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      saveError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: CupertinoColors.systemRed),
                    ),
                  ],
                  const SizedBox(height: 24),
                  CupertinoButton.filled(
                    onPressed: saving ? null : _continue,
                    child: saving
                        ? const CupertinoActivityIndicator()
                        : const Text('Start'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen>
    with SingleTickerProviderStateMixin {
  static const Color defaultColor = Color(0xFFFFD60A);
  static const Color completedColor = Color(0xFF34C759);

  String question = 'Did I walk today?';
  bool completed = false;
  bool completing = false;
  bool loading = true;
  String? loadError;
  int streak = 0;
  String lastDate = '';

  late final AnimationController controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350))
    ..value = 1.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String today() {
    return dateKey(DateTime.now());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        question = prefs.getString('question') ?? question;
        streak = prefs.getInt('streak') ?? 0;
        lastDate = prefs.getString('lastCompletedDate') ?? '';
        completed = lastDate == today();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = 'Sloth could not load your saved habit.';
      });
    }
  }

  Future<void> _markCompleted() async {
    if (completed || completing || loading || loadError != null) return;
    setState(() => completing = true);
    try {
      HapticFeedback.mediumImpact();
      await controller.forward(from: 0.92);
      final completionDate = today();
      final nextStreak = streakAfterCompletion(
        currentStreak: streak,
        lastCompletedDate: lastDate,
        today: DateTime.now(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('question', question);
      await prefs.setInt('streak', nextStreak);
      await prefs.setString('lastCompletedDate', completionDate);
      if (!mounted) return;
      setState(() {
        completed = true;
        streak = nextStreak;
        lastDate = completionDate;
        completing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => completing = false);
      await _showError('Could not save today’s completion. Please try again.');
    }
  }

  Future<void> _editQuestion() async {
    final textController = TextEditingController(text: question);
    var savingQuestion = false;
    String? editError;
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submitQuestion() async {
            final nextQuestion = textController.text.trim();
            if (nextQuestion.isEmpty) {
              setSheetState(() {
                editError = 'Enter a question to save.';
              });
              return;
            }
            setSheetState(() {
              savingQuestion = true;
              editError = null;
            });
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('question', nextQuestion);
              if (!mounted || !context.mounted) return;
              setState(() => question = nextQuestion);
              Navigator.pop(context);
            } catch (_) {
              setSheetState(() {
                savingQuestion = false;
                editError = 'Could not save your question. Please try again.';
              });
            }
          }

          return CupertinoActionSheet(
            title: const Text('Edit Question'),
            message: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoTextField(
                  controller: textController,
                  padding: const EdgeInsets.all(12),
                  enabled: !savingQuestion,
                ),
                if (editError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    editError!,
                    style: const TextStyle(color: CupertinoColors.systemRed),
                  ),
                ],
              ],
            ),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  if (!savingQuestion) submitQuestion();
                },
                child: savingQuestion
                    ? const CupertinoActivityIndicator()
                    : const Text('Save'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () {
                if (!savingQuestion) Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          );
        },
      ),
    );
    textController.dispose();
  }

  Future<void> _logout() async {
    final shouldReset = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Reset Sloth?'),
        content:
            const Text('This clears your habit question and local streak.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (shouldReset != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => const RootScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      await _showError('Could not reset Sloth. Your saved data is unchanged.');
    }
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Something went wrong'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = completed ? completedColor : defaultColor;

    if (loading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (loadError case final error?) {
      return CupertinoPageScaffold(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                CupertinoButton.filled(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: _editQuestion,
                    child: const Icon(CupertinoIcons.back),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: _logout,
                    child: const Icon(CupertinoIcons.square_arrow_right),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ringSize = math.min(
                    290.0,
                    math.max(160.0, constraints.maxHeight - 135),
                  );
                  final ringGap = ringSize >= 280
                      ? 60.0
                      : math.max(
                          16.0,
                          math.min(
                              36.0, constraints.maxHeight - ringSize - 100),
                        );
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ScaleTransition(
                            scale: CurvedAnimation(
                              parent: controller,
                              curve: Curves.easeOutBack,
                            ),
                            child: Semantics(
                              button: true,
                              enabled: !completed && !completing,
                              label: completed
                                  ? 'Habit completed today'
                                  : completing
                                      ? 'Saving habit completion'
                                      : 'Complete habit',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: completed || completing
                                    ? null
                                    : _markCompleted,
                                child: SizedBox(
                                  width: ringSize,
                                  height: ringSize,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CustomPaint(
                                        size: Size(ringSize, ringSize),
                                        painter: RingPainter(color: ringColor),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: ringSize * 0.19,
                                        ),
                                        child: Text(
                                          question,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: math.max(
                                              16.0,
                                              math.min(24.0, ringSize * 0.082),
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (completed)
                                        Positioned(
                                          bottom: ringSize * 0.1,
                                          child: Container(
                                            width: ringSize * 0.18,
                                            height: ringSize * 0.18,
                                            decoration: BoxDecoration(
                                              color: completedColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: CupertinoColors.white,
                                                width: 4,
                                              ),
                                            ),
                                            child: Icon(
                                              CupertinoIcons.check_mark,
                                              color: CupertinoColors.white,
                                              size: ringSize * 0.09,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: ringGap),
                          Text(
                            '$streak',
                            style: TextStyle(
                              fontSize: math.min(56.0, ringSize * 0.193),
                              fontWeight: FontWeight.bold,
                              color: completed
                                  ? completedColor
                                  : CupertinoColors.black,
                            ),
                          ),
                          Text(
                            'day streak',
                            style: TextStyle(
                              fontSize: math.min(24.0, ringSize * 0.083),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  final Color color;
  RingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const strokeWidth = 18.0;
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant RingPainter oldDelegate) =>
      oldDelegate.color != color;
}

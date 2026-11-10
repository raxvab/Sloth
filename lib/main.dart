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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    onboarded = prefs.getBool('onboarded') ?? false;
    setState(() => loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
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

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'question',
        controller.text.trim().isEmpty
            ? 'Did I walk today?'
            : controller.text.trim());
    await prefs.setBool('onboarded', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const HabitScreen()),
      );
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
                  ),
                  const SizedBox(height: 24),
                  CupertinoButton.filled(
                    onPressed: _continue,
                    child: const Text('Start'),
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
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      question = prefs.getString('question') ?? question;
      streak = prefs.getInt('streak') ?? 0;
      lastDate = prefs.getString('lastCompletedDate') ?? '';
      completed = lastDate == today();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('question', question);
    await prefs.setInt('streak', streak);
    await prefs.setString('lastCompletedDate', lastDate);
  }

  Future<void> _markCompleted() async {
    if (completed) return;
    HapticFeedback.mediumImpact();
    await controller.forward(from: 0.92);
    if (!mounted) return;
    setState(() {
      completed = true;
      streak = streakAfterCompletion(
        currentStreak: streak,
        lastCompletedDate: lastDate,
        today: DateTime.now(),
      );
      lastDate = today();
    });
    await _save();
  }

  Future<void> _editQuestion() async {
    final textController = TextEditingController(text: question);
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Edit Question'),
        message: CupertinoTextField(
          controller: textController,
          padding: const EdgeInsets.all(12),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              question = textController.text.trim().isEmpty
                  ? question
                  : textController.text.trim();
              await _save();
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const RootScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = completed ? completedColor : defaultColor;

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
                      label: completed
                          ? 'Habit completed today'
                          : 'Complete habit',
                      child: GestureDetector(
                        onTap: _markCompleted,
                        child: SizedBox(
                          width: 290,
                          height: 290,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(290, 290),
                                painter: RingPainter(color: ringColor),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 55,
                                ),
                                child: Text(
                                  question,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (completed)
                                Positioned(
                                  bottom: 28,
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: completedColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: CupertinoColors.white,
                                        width: 4,
                                      ),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.check_mark,
                                      color: CupertinoColors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  Text(
                    '$streak',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: completed ? completedColor : CupertinoColors.black,
                    ),
                  ),
                  const Text(
                    'day streak',
                    style: TextStyle(fontSize: 24),
                  ),
                ],
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

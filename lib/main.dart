import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'date_labels.dart';
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
                    inputFormatters: [LengthLimitingTextInputFormatter(64)],
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Color defaultColor = Color(0xFFF0B94B);
  static const Color completedColor = Color(0xFFA8C3A0);
  static const Color skippedColor = Color(0xFFD89085);

  String question = 'Did I walk today?';
  bool completed = false;
  bool skipped = false;
  bool completing = false;
  bool skipping = false;
  bool loading = true;
  String? loadError;
  int streak = 0;
  String lastDate = '';
  Timer? dayBoundaryTimer;

  late final AnimationController controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350))
    ..value = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _scheduleNextDayRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _scheduleNextDayRefresh();
    } else {
      dayBoundaryTimer?.cancel();
    }
  }

  void _scheduleNextDayRefresh() {
    dayBoundaryTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    dayBoundaryTimer = Timer(nextDay.difference(now), () {
      if (!mounted) return;
      _load();
      _scheduleNextDayRefresh();
    });
  }

  String today() {
    return dateKey(DateTime.now());
  }

  int get visibleStreak {
    if (completed) return streak;
    if (skipped) return 0;
    final yesterday = dateKey(DateTime.now().subtract(const Duration(days: 1)));
    return lastDate == yesterday ? streak : 0;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final progress = CompletionRecord.fromStored(
        json: prefs.getString('completionRecord'),
        legacyStreak: prefs.getInt('streak') ?? 0,
        legacyLastCompletedDate: prefs.getString('lastCompletedDate') ?? '',
      );
      final loadedSkippedDate = prefs.getString('lastSkippedDate') ?? '';
      final status = dailyHabitStatus(
        lastCompletedDate: progress.lastCompletedDate,
        lastSkippedDate: loadedSkippedDate,
        today: DateTime.now(),
      );
      setState(() {
        question = prefs.getString('question') ?? question;
        streak = progress.streak;
        lastDate = progress.lastCompletedDate;
        completed = status == DailyHabitStatus.completed;
        skipped = status == DailyHabitStatus.skipped;
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
      unawaited(controller.forward(from: 0.92));
      final now = DateTime.now();
      final completionDate = dateKey(now);
      final nextStreak = streakAfterCompletion(
        currentStreak: streak,
        lastCompletedDate: lastDate,
        today: now,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'completionRecord',
        CompletionRecord(
          streak: nextStreak,
          lastCompletedDate: completionDate,
        ).toJson(),
      );
      if (!mounted) return;
      setState(() {
        completed = true;
        skipped = false;
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

  Future<void> _skipToday() async {
    if (completed || skipped || skipping || loading || loadError != null) {
      return;
    }
    setState(() => skipping = true);
    try {
      final skippedOn = today();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastSkippedDate', skippedOn);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        skipped = true;
        skipping = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => skipping = false);
      await _showError('Could not save today’s skip. Please try again.');
    }
  }

  Future<void> _undoSkip() async {
    if (!skipped || skipping || loading || loadError != null) return;
    setState(() => skipping = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastSkippedDate');
      if (!mounted) return;
      setState(() {
        skipped = false;
        skipping = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => skipping = false);
      await _showError('Could not undo today’s skip. Please try again.');
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
                  inputFormatters: [LengthLimitingTextInputFormatter(64)],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Examples: “Did I call my mom today?” or “Did I avoid sugar today?”',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6E6E73),
                  ),
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    dayBoundaryTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = completed
        ? completedColor
        : skipped
            ? skippedColor
            : defaultColor;
    final ringFill = completed
        ? completedColor
        : skipped
            ? skippedColor
            : CupertinoColors.white;

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
                  Semantics(
                    button: true,
                    label: 'Edit habit question',
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      onPressed: _editQuestion,
                      child: const Icon(CupertinoIcons.back),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Reset Sloth',
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      onPressed: _logout,
                      child: const Icon(CupertinoIcons.square_arrow_right),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ringSize = math.min(
                    286.0,
                    math.min(
                      math.max(152.0, (constraints.maxWidth - 32) * 0.72),
                      math.max(152.0, constraints.maxHeight - 220),
                    ),
                  );
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 22),
                            child: Column(
                              children: [
                                Text(
                                  '${greetingFor(DateTime.now())}, Vaibhav',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1C1C1E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  friendlyDate(DateTime.now()),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6E6E73),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            button: true,
                            enabled: !completing && !skipping,
                            label: completed
                                ? '$question. Completed today.'
                                : skipped
                                    ? '$question. Skipped today.'
                                    : completing
                                        ? '$question. Saving completion.'
                                        : question,
                            hint:
                                'Tap to mark this habit complete. Long press to edit the question.',
                            onTap: completed ? null : _markCompleted,
                            onLongPress: _editQuestion,
                            excludeSemantics: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              excludeFromSemantics: true,
                              onTap: completed || completing || skipping
                                  ? null
                                  : _markCompleted,
                              onLongPress: _editQuestion,
                              child: ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: controller,
                                  curve: Curves.easeOutBack,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 450),
                                  curve: Curves.easeInOutCubic,
                                  width: ringSize,
                                  height: ringSize,
                                  decoration: BoxDecoration(
                                    color: ringFill,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ringColor,
                                      width: 16,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            ringColor.withValues(alpha: 0.22),
                                        blurRadius: 30,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          ringSize * 0.18,
                                          ringSize * 0.18,
                                          ringSize * 0.18,
                                          ringSize * 0.28,
                                        ),
                                        child: Text(
                                          question,
                                          textAlign: TextAlign.center,
                                          maxLines: 5,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: math.max(
                                              16.0,
                                              math.min(24.0, ringSize * 0.082),
                                            ),
                                            height: 1.2,
                                            fontWeight: FontWeight.w700,
                                            color: completed || skipped
                                                ? CupertinoColors.white
                                                : const Color(0xFF1C1C1E),
                                          ),
                                        ),
                                      ),
                                      if (completing ||
                                          skipping ||
                                          completed ||
                                          skipped)
                                        Positioned(
                                          bottom: ringSize * 0.1,
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                                milliseconds: 220),
                                            transitionBuilder:
                                                (child, animation) =>
                                                    ScaleTransition(
                                              scale: animation,
                                              child: child,
                                            ),
                                            child: completing || skipping
                                                ? CupertinoActivityIndicator(
                                                    key: const ValueKey(
                                                        'saving'),
                                                    color: completed || skipped
                                                        ? CupertinoColors.white
                                                        : const Color(
                                                            0xFF6E6E73),
                                                  )
                                                : Icon(
                                                    skipped
                                                        ? CupertinoIcons.xmark
                                                        : CupertinoIcons
                                                            .check_mark,
                                                    key: ValueKey(
                                                      skipped
                                                          ? 'skipped'
                                                          : 'done',
                                                    ),
                                                    color:
                                                        CupertinoColors.white,
                                                    size: ringSize * 0.1,
                                                  ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: ringSize >= 250 ? 28 : 14),
                          Text(
                            '$visibleStreak',
                            style: TextStyle(
                              fontSize: math.min(56.0, ringSize * 0.193),
                              fontWeight: FontWeight.bold,
                              color: completed || skipped
                                  ? ringColor
                                  : const Color(0xFF1C1C1E),
                            ),
                          ),
                          Text(
                            'day streak',
                            style: TextStyle(
                              fontSize: math.min(24.0, ringSize * 0.083),
                              color: const Color(0xFF6E6E73),
                            ),
                          ),
                          if (!completed)
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              onPressed: skipping
                                  ? null
                                  : skipped
                                      ? _undoSkip
                                      : _skipToday,
                              child: Text(
                                skipping
                                    ? 'Saving…'
                                    : skipped
                                        ? 'Undo skip'
                                        : 'Skip today',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6E6E73),
                                ),
                              ),
                            ),
                          const Padding(
                            padding: EdgeInsets.only(top: 2, bottom: 14),
                            child: Text(
                              'SLOW DOWN. DO ONE THING. KEEP GOING.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6E6E73),
                              ),
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

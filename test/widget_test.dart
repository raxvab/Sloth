import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sloth/date_labels.dart';
import 'package:sloth/main.dart';
import 'package:sloth/streak.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  CompletionRecord storedProgress(SharedPreferences prefs) {
    return CompletionRecord.fromStored(
      json: prefs.getString('completionRecord'),
      legacyStreak: prefs.getInt('streak') ?? 0,
      legacyLastCompletedDate: prefs.getString('lastCompletedDate') ?? '',
    );
  }

  testWidgets('onboarding saves the one thing and opens the habit screen',
      (tester) async {
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    expect(find.text('What is your one thing?'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField), 'Read ten pages');
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Read ten pages'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(
      find.text('${greetingFor(DateTime.now())}, Vaibhav'),
      findsOneWidget,
    );
    expect(
        (await SharedPreferences.getInstance()).getBool('onboarded'), isTrue);
  });

  testWidgets(
      'onboarding remains usable when the keyboard reduces the viewport',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });

  testWidgets('habit screen fits a compact Android viewport without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 420);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    expect(find.text('Did I walk today?'), findsOneWidget);
    expect(find.text('day streak'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('habit home adapts across narrow, standard, and wide screens',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
    });

    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(600, 960),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SlothApp());
      await tester.pumpAndSettle();

      expect(find.text('Did I walk today?'), findsOneWidget);
      expect(find.text('day streak'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('the completion circle exposes its question and actions',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
    });
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    final node =
        tester.getSemantics(find.bySemanticsLabel('Did I walk today?'));
    final data = node.getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.longPress), isTrue);
    semantics.dispose();
  });

  testWidgets('completing the habit turns the ring green and increments streak',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Did I walk today?'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(storedProgress(prefs).streak, 1);
    expect(storedProgress(prefs).lastCompletedDate, isNotEmpty);
  });

  testWidgets('rapid repeated taps only record one completion', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Did I walk today?'));
    await tester.tap(find.text('Did I walk today?'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(
      storedProgress(await SharedPreferences.getInstance()).streak,
      1,
    );
  });

  testWidgets('the question can be edited and saved', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.back));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'Did I stretch?');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Did I stretch?'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('question'),
        'Did I stretch?');
  });

  testWidgets('long pressing the question opens the edit sheet',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Did I walk today?'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Question'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('system Back dismisses the edit sheet without saving',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Did I walk today?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(CupertinoTextField),
      'Changed temporarily',
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Edit Question'), findsNothing);
    expect(find.text('Did I walk today?'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('question'),
        'Did I walk today?');
  });

  testWidgets('skipping today shows the coral X state and survives restart',
      (tester) async {
    final yesterday = dateKey(DateTime.now().subtract(const Duration(days: 1)));
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
      'streak': 4,
      'lastCompletedDate': yesterday,
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip today'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Undo skip'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('lastSkippedDate'),
      dateKey(DateTime.now()),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    expect(find.text('Undo skip'), findsOneWidget);
  });

  testWidgets('a skipped habit can still be completed later that day',
      (tester) async {
    final yesterday = dateKey(DateTime.now().subtract(const Duration(days: 1)));
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
      'streak': 4,
      'lastCompletedDate': yesterday,
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Did I walk today?'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.xmark), findsNothing);
    expect(find.text('5'), findsOneWidget);
    final progress = storedProgress(prefs);
    expect(progress.lastCompletedDate, dateKey(DateTime.now()));
    expect(progress.streak, 5);
    expect(
      dailyHabitStatus(
        lastCompletedDate: progress.lastCompletedDate,
        lastSkippedDate: prefs.getString('lastSkippedDate') ?? '',
        today: DateTime.now(),
      ),
      DailyHabitStatus.completed,
    );
  });

  testWidgets('canceling question editing keeps the original question',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.back));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(CupertinoTextField), 'Changed temporarily');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Did I walk today?'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('question'),
        'Did I walk today?');
  });

  testWidgets('editing rejects an empty question without losing the old one',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.back));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a question to save.'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('question'),
        'Did I walk today?');
  });

  testWidgets('saved question and completion survive an app restart',
      (tester) async {
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'Read ten pages');
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read ten pages'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    expect(find.text('Read ten pages'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
  });

  testWidgets('refreshes habit state when the app resumes', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I stretch?',
      'streak': 2,
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Did I stretch?'), findsOneWidget);
  });

  testWidgets('logout clears progress and returns to onboarding',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
      'streak': 4,
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.square_arrow_right));
    await tester.pumpAndSettle();
    expect(find.text('Reset Sloth?'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('What is your one thing?'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  testWidgets('canceling reset keeps the habit and its saved progress',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'question': 'Did I walk today?',
      'streak': 4,
    });
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.square_arrow_right));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Did I walk today?'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('question'),
        'Did I walk today?');
    expect((await SharedPreferences.getInstance()).getInt('streak'), 4);
  });

  testWidgets('fresh install completes the main journey through reset',
      (tester) async {
    await tester.pumpWidget(const SlothApp());
    await tester.pumpAndSettle();
    expect(find.text('What is your one thing?'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), 'Read ten pages');
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read ten pages'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
    expect(
      storedProgress(await SharedPreferences.getInstance()).streak,
      1,
    );

    await tester.tap(find.byIcon(CupertinoIcons.back));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'Did I stretch?');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Did I stretch?'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.square_arrow_right));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('What is your one thing?'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
}

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sloth/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
    expect(prefs.getInt('streak'), 1);
    expect(prefs.getString('lastCompletedDate'), isNotEmpty);
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
    expect((await SharedPreferences.getInstance()).getInt('streak'), 1);
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
}

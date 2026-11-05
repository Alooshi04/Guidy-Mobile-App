import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/widgets/marquee_text.dart';

// Long line names keep their size and slide through their slot instead of
// shrinking (owner, 2026-10-14), and never spill onto the buttons beside them.
void main() {
  setUp(() => MarqueeText.animate = true);
  tearDown(() => MarqueeText.animate = false);

  const style = TextStyle(fontSize: 15);
  const long = 'Cairo LRT: Adly Mansour - Arts and Culture City';

  Future<void> pump(WidgetTester tester, String text, {TextDirection dir = TextDirection.ltr}) =>
      tester.pumpWidget(Directionality(
        textDirection: dir,
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 120, child: MarqueeText(text, style: style)),
            const SizedBox(key: ValueKey('button'), width: 40, height: 40),
          ]),
        ),
      ));

  double textLeft(WidgetTester tester) => tester.getTopLeft(find.text(long)).dx;

  testWidgets('text that fits is plain and still', (tester) async {
    await pump(tester, 'LRT');
    expect(find.byType(ClipRect), findsNothing);
    final before = tester.getTopLeft(find.text('LRT'));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(find.text('LRT')), before);
  });

  testWidgets('a long line keeps its size and slides to its end', (tester) async {
    await pump(tester, long);
    await tester.pump();
    final text = tester.widget<Text>(find.text(long));
    expect(text.style?.fontSize, 15);
    expect(find.byType(FittedBox), findsNothing);

    final start = textLeft(tester);
    // Rests at the start first, so the beginning is read.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(textLeft(tester), start);
    // Then slides left, towards the end of the text.
    await tester.pump(const Duration(milliseconds: 3000));
    expect(textLeft(tester), lessThan(start - 50));
    // The end reaches the slot's right edge, not further.
    await tester.pump(const Duration(seconds: 10));
    final slotRight = tester.getTopRight(find.byType(MarqueeText)).dx;
    expect(tester.getTopRight(find.text(long)).dx, greaterThanOrEqualTo(slotRight - 1));
  });

  testWidgets('it is clipped to its slot, clear of the button beside it', (tester) async {
    await pump(tester, long);
    await tester.pump(const Duration(seconds: 4));
    final clip = tester.getRect(find.byType(ClipRect));
    final button = tester.getRect(find.byKey(const ValueKey('button')));
    expect(clip.right, lessThanOrEqualTo(button.left));
  });

  testWidgets('right-to-left text starts at the right and slides right', (tester) async {
    await pump(tester, long, dir: TextDirection.rtl);
    await tester.pump();
    final slotRight = tester.getTopRight(find.byType(MarqueeText)).dx;
    expect(tester.getTopRight(find.text(long)).dx, closeTo(slotRight, 1));
    await tester.pump(const Duration(milliseconds: 4000));
    expect(tester.getTopRight(find.text(long)).dx, greaterThan(slotRight + 50));
  });
}

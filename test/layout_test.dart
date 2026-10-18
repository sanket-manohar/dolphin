import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphin/dolphin.dart';

Future<(Rect tooltip, Rect pointer, PointerPlacement? placement)> layoutWith(
  WidgetTester tester, {
  required Rect hole,
  TooltipPosition position = TooltipPosition.auto,
  PointerMode mode = PointerMode.auto,
  double? manualFraction,
  Size screen = const Size(400, 800),
  Size tooltipSize = const Size(300, 120),
}) async {
  final placement = ValueNotifier<PointerPlacement?>(null);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox.fromSize(
        size: screen,
        child: CustomMultiChildLayout(
          delegate: TooltipLayoutDelegate(
            hole: hole,
            position: position,
            margin: const EdgeInsets.all(12),
            gap: 4,
            pointer: const PointerStyle(),
            maxWidth: 340,
            placement: placement,
            pointerMode: mode,
            manualFraction: manualFraction,
          ),
          children: [
            LayoutId(
                id: TooltipSlot.tooltip,
                child: SizedBox.fromSize(
                    key: const Key('tip'), size: tooltipSize)),
            LayoutId(
                id: TooltipSlot.pointer,
                child: const SizedBox.expand(key: Key('ptr'))),
          ],
        ),
      ),
    ),
  ));
  final origin = tester.getTopLeft(find.byType(CustomMultiChildLayout));
  return (
    tester.getRect(find.byKey(const Key('tip'))).shift(-origin),
    tester.getRect(find.byKey(const Key('ptr'))).shift(-origin),
    placement.value,
  );
}

void main() {
  testWidgets('pointer is centred on the target, below it', (tester) async {
    final hole = const Rect.fromLTWH(60, 100, 40, 40);
    final (tip, ptr, placement) = await layoutWith(tester, hole: hole);
    expect(placement!.direction, AxisDirection.up);
    expect(ptr.center.dx, closeTo(hole.center.dx, 0.01));
    expect(tip.top, greaterThan(hole.bottom));
    expect(ptr.bottom, closeTo(tip.top, 0.01));
    // The tooltip is clamped into the screen margins.
    expect(tip.left, greaterThanOrEqualTo(12));
  });

  testWidgets('target at the far right edge: pointer clamped inside tooltip',
      (tester) async {
    final hole = const Rect.fromLTWH(380, 300, 20, 20);
    final (tip, ptr, _) = await layoutWith(tester, hole: hole);
    expect(tip.right, lessThanOrEqualTo(400 - 12 + 0.01));
    expect(ptr.left, greaterThanOrEqualTo(tip.left));
    expect(ptr.right, lessThanOrEqualTo(tip.right));
    // As close to the target as the rounded corner allows.
    expect(ptr.center.dx, closeTo(tip.right - 18 - 9, 0.01));
  });

  testWidgets('no room below: tooltip goes above and points down',
      (tester) async {
    final hole = const Rect.fromLTWH(100, 740, 50, 40);
    final (tip, ptr, placement) = await layoutWith(tester, hole: hole);
    expect(placement!.direction, AxisDirection.down);
    expect(tip.bottom, lessThan(hole.top));
    expect(ptr.center.dx, closeTo(hole.center.dx, 0.01));
  });

  testWidgets('manual pointer position is used when asked', (tester) async {
    final hole = const Rect.fromLTWH(60, 100, 40, 40);
    final (tip, ptr, _) = await layoutWith(tester,
        hole: hole, mode: PointerMode.manual, manualFraction: 0.5);
    expect(ptr.center.dx, closeTo(tip.left + tip.width / 2, 0.01));
  });

  testWidgets('non-finite hole never throws and centres the tooltip',
      (tester) async {
    final (tip, ptr, placement) = await layoutWith(tester,
        hole: const Rect.fromLTRB(double.nan, 0, 10, 10));
    expect(placement, isNull);
    expect(ptr.isEmpty, isTrue);
    expect(tip.center.dx, closeTo(200, 0.01));
  });

  testWidgets('left / right positions point sideways', (tester) async {
    final hole = const Rect.fromLTWH(10, 300, 40, 40);
    final (tip, ptr, placement) = await layoutWith(tester,
        hole: hole,
        position: TooltipPosition.right,
        tooltipSize: const Size(200, 100));
    expect(placement!.direction, AxisDirection.left);
    expect(tip.left, greaterThan(hole.right));
    expect(ptr.center.dy, closeTo(hole.center.dy, 0.01));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:traversal2/src/directional_resolver.dart';

class TraversalDebugger extends StatelessWidget {
  final Widget child;

  const TraversalDebugger({Key key, @required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _TraversalPainter(),
      child: child,
    );
  }
}

class _TraversalPainter extends CustomPainter {
  _TraversalPainter() : super(repaint: FocusManager.instance.rootScope);

  @override
  void paint(Canvas canvas, Size size) {
    final list = <FocusNode>[];
    FocusManager.instance.rootScope.collectChildren(list);

    final focusable = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke;

    final nonFocusable = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke;

    final skipTraversal = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke;

    final nodeBlue = Paint()..color = Colors.blueGrey.withAlpha(60);

    final black = Paint();

    for (final node in list) {
      canvas.drawRect(
          node.rect,
          node.canRequestFocus
              ? (node.skipTraversal ? skipTraversal : focusable)
              : nonFocusable);

      if (node is! FocusScopeNode &&
          !node.skipTraversal &&
          node.canRequestFocus) {
        canvas.drawRect(node.rect, nodeBlue);

        if (node.hasPrimaryFocus) {
          void drawLines(Offset origin, List<FocusCandidate> candidates) {
            for (final candidate in candidates) {
              canvas.drawLine(origin, candidate.node.rect.center, black);
            }
          }

          for (final resolver in [
            const LeftDirectionResolver(),
            const RightDirectionResolver(),
            const TopDirectionResolver(),
            const BottomDirectionResolver(),
          ]) {
            drawLines(
              resolver.biasedCenter(node.rect, Directionality.of(node.context)),
              resolver.resolveCandidates(node),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

extension on FocusNode {
  void collectChildren(List<FocusNode> list) {
    children.forEach((child) {
      child.collectChildren(list);
      list.add(child);
    });
  }
}

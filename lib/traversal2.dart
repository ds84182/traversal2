library traversal2;

import 'package:flutter/widgets.dart';
import 'package:traversal2/src/candidates.dart';

export 'package:traversal2/src/debug.dart' show TraversalDebugger;

mixin Traversal2Mixin on FocusTraversalPolicy {
  FocusNode _computeFocus(FocusNode node, TraversalDirection direction,
      {Rect rect}) {
    final candidates = FocusCandidates(node, rect: rect);

    final selected = candidates.select(direction);

    return selected.isEmpty ? null : selected.first.node;
  }

  @override
  bool inDirection(FocusNode node, TraversalDirection direction) {
    final originalRect = node?.rect;

    while (node != null) {
      if (node.context == null) {
        node = node.parent;
        continue;
      }

      final target = _computeFocus(node, direction, rect: originalRect);

      if (target != null) {
        target.requestFocus();
        return true;
      }

      node = node.parent;
    }
    return true;
  }
}

class Traversal2Policy = ReadingOrderTraversalPolicy with Traversal2Mixin;

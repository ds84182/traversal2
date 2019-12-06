import 'package:flutter/cupertino.dart';

/// Keeps a history of traversed FocusNodes.
///
/// This lets focus stay consistent with user actions.
///
/// For example if there's one large button above two small buttons (with equal
/// flex), without traversal history going up from the second small button (on
/// the right side) to the large button and back down will always end up on the
/// first small button.
///
/// For now, the depth of the traversal stack is fixed to 1.
class TraversalHistory {
  TraversalDirection _lastDirection;
  FocusNode _sourceNode;
  FocusNode _lastNode;

  void clearHistory() {
    _lastNode = _sourceNode = _lastDirection = null;
  }

  void clearHistoryFor(FocusNode node) {
    if (identical(_lastNode, node) || identical(_sourceNode, node)) {
      clearHistory();
    }
  }

  void track(
      FocusNode source, TraversalDirection targetDirection, FocusNode target) {
    // Going from source to target in targetDirection.
    _sourceNode = source;
    _lastDirection = targetDirection;
    _lastNode = target;
  }

  FocusNode pop(FocusNode current, TraversalDirection direction) {
    if (identical(current, _lastNode) &&
        _sourceNode.context != null &&
        direction.inverse == _lastDirection) {
      final nextNode = _sourceNode;

      // Swap nodes:
      _lastNode = nextNode;
      _lastDirection = direction;
      _sourceNode = current;

      return nextNode;
    }

    return null;
  }
}

extension on TraversalDirection {
  // Assumes that up is 0, right is 1, down is 2, left is 3:
  TraversalDirection get inverse => TraversalDirection.values[index ^ 2];
}

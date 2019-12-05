import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:traversal2/src/directional_resolver.dart';

// Focus resolution:
// Resolve candidates in all directions (DONE)
// Remove each other's best candidates from other directions (to make sure
// that multiple directions don't contain the same top candidate)  (DONE)

// For horizontal movement, if two candidates are almost the same, prefer
// the candidate towards the top of the screen.
// For vertical movement, if two candidates are almost the same, prefer
// the candidate the opposite of reading order.
// (Left for LTR, Right for RTL)
// If there is no good candidate in that direction, combine candidate
// results with the focus parent's computed candidates (so we don't get
// trapped in a container).

class FocusCandidates {
  final Rect rect;
  final List<FocusCandidate> left, right, top, bottom;

  void debugDumpCandidates(String title) {
    if (kDebugMode) {
      print(title);
      print("left: $left");
      print("right: $right");
      print("top: $top");
      print("bottom: $bottom");
    }
  }

  void normalizeRanks(List<FocusCandidate> candidate) {
    double min = double.infinity;
    double max = 0.0;

    candidate.forEach((c) {
      min = c.rank < min ? c.rank : min;
      max = c.rank > max ? c.rank : max;
    });

    // Normalize ranks from 0.0 to 1.0 inside of our range.

    for (int i = 0; i < candidate.length; i++) {
      final newRank =
          min == max ? 0.0 : (candidate[i].rank - min) / (max - min);

      candidate[i] = candidate[i].withRank(newRank);
    }
  }

  FocusCandidates(FocusNode node, {Rect rect})
      : rect = rect ?? node.rect,
        left =
            const LeftDirectionResolver().resolveCandidates(node, rect: rect),
        right =
            const RightDirectionResolver().resolveCandidates(node, rect: rect),
        top = const TopDirectionResolver().resolveCandidates(node, rect: rect),
        bottom = const BottomDirectionResolver()
            .resolveCandidates(node, rect: rect) {
    debugDumpCandidates("Initial candidates:");

    normalizeRanks(left);
    normalizeRanks(right);
    normalizeRanks(top);
    normalizeRanks(bottom);

    debugDumpCandidates("Normalized candidates:");

    final candidateSet = Map<FocusNode, FocusCandidate>.identity();

    void addToSet(FocusCandidate c) {
      candidateSet.update(
        c.node,
        (other) => other.rank < c.rank ? other : c,
        ifAbsent: () => c,
      );
    }

    left.forEach(addToSet);
    right.forEach(addToSet);
    top.forEach(addToSet);
    bottom.forEach(addToSet);

    void deduplicate(List<FocusCandidate> list) {
      list.retainWhere((c) => identical(c, candidateSet[c.node]));
    }

    deduplicate(left);
    deduplicate(right);
    deduplicate(top);
    deduplicate(bottom);

    debugDumpCandidates("New candidates:");
  }

  List<FocusCandidate> select(TraversalDirection direction) {
    assert(direction != null);

    switch (direction) {
      case TraversalDirection.up:
        return top;
      case TraversalDirection.right:
        return right;
      case TraversalDirection.down:
        return bottom;
      case TraversalDirection.left:
        return left;
    }

    assert(false);
    return const [];
  }
}

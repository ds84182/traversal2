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
      final c = candidate[i];
      final newRank = min == max ? 0.0 : (c.rank - min) / (max - min);

      final newCandidate = candidate[i].withRank(newRank, c.rank);

      candidate[i] = newCandidate;
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

    // Candidates with their initial ranks:
    final initialCandidateSet = _CandidateSet();

    left.forEach(initialCandidateSet.add);
    right.forEach(initialCandidateSet.add);
    top.forEach(initialCandidateSet.add);
    bottom.forEach(initialCandidateSet.add);

    normalizeRanks(left);
    normalizeRanks(right);
    normalizeRanks(top);
    normalizeRanks(bottom);

    debugDumpCandidates("Normalized candidates:");

    // Candidates with their normalized ranks:
    final normalizedCandidateSet = _CandidateSet();

    left.forEach(normalizedCandidateSet.add);
    right.forEach(normalizedCandidateSet.add);
    top.forEach(normalizedCandidateSet.add);
    bottom.forEach(normalizedCandidateSet.add);

    final candidateSet = normalizedCandidateSet;

    void deduplicate(List<FocusCandidate> list) {
      list.retainWhere((c) => identical(c, candidateSet[c.node]));
    }

    // TODO: Try to avoid deduplication getting rid of the most likely
    // candidate, when both candidates have similar initial ranks and
    // normalized ranks.

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

class _CandidateSet {
  final set = Map<FocusNode, FocusCandidate>.identity();

  void add(FocusCandidate c) {
    set.update(
      c.node,
      (other) {
        if ((other.rank - c.rank).abs() < 0.05 && other.rank2 < c.rank2) {
          return other;
        }

        return other.rank < c.rank ? other : c;
      },
      ifAbsent: () => c,
    );
  }

  FocusCandidate operator [](FocusNode node) => set[node];

  _CandidateSet combine(
      _CandidateSet other,
      FocusCandidate Function(FocusNode, FocusCandidate a, FocusCandidate b)
          func) {
    final out = _CandidateSet();

    // We expect that all keys in A are also in B, otherwise this will not work.
    set.forEach((node, a) {
      out.set[node] = func(node, a, other[node]);
    });

    return out;
  }
}

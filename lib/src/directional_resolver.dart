import 'package:flutter/widgets.dart';

class FocusCandidate {
  final FocusNode node;
  final double rank;

  const FocusCandidate(this.node, this.rank);

  FocusCandidate withRank(double rank) => FocusCandidate(node, rank);

  @override
  String toString() => "$node - $rank";
}

abstract class DirectionResolver {
  const DirectionResolver();

  /// Computes an offset that is at the start of the main axis and the center
  /// of the cross axis from the given [rect].
  Offset biasedCenter(Rect rect);

  /// Creates a rect from a [biasedCenter] offset that stretches into infinity
  /// in all directions except the start of the main axis.
  Rect infiniteRectFor(Offset center);

  /// Creates a rect from an [infiniteRectFor] and [originalRect] that starts
  /// at the main axis and only stretches onto infinity on the main axis.
  Rect matchDimen(Rect infiniteRect, Rect originalRect);

  /// Tests whether the given rect intersects the main axis determined by the
  /// [biasedCenter].
  bool intersectsMainAxis(Rect rect, Offset center);

  /// Determines the distance from the rect from the nearest main axis point.
  double crossAxisDist(Rect rect, Offset center);

  /// Determines the distance from the rect to the start of the main axis.
  double mainAxisDist(Rect rect, Offset center);

  // Main axis = the axis we are looking for candidates in
  // Cross axis = the other axis
  List<FocusCandidate> resolveCandidates(FocusNode node, {Rect rect}) {
    rect ??= node.rect;

    final cl = biasedCenter(rect);

    // Cast a line from the center to focus direction + infinity
    final infiniteRect = infiniteRectFor(cl);

    // Constrain the infinite rect to the cross axis span of the node's rect
    final dimenRect = matchDimen(infiniteRect, rect);

    /// Rank the given focus node on how close it is to the center line.
    ///
    /// For now, we return the manhattan distance to the node.
    double rank(FocusNode node) {
      final rect = node.rect;

      // Get the distance from the closest point on the rect to the main axis
      final dist = mainAxisDist(rect, cl);

      // Heavy penalty for items that aren't along the "ray" we calculated
      // TODO: Boost items by the amount of item intersected within the "ray"
      final penalty = dimenRect.overlaps(rect) ? 0.0 : 10000.0;

      print("$node ($rect, $cl) $dist ${crossAxisDist(rect, cl)}");

      // If we intersect the main axis (we lie along the ray with a width of 0
      // ignore any cross axis distances, since they'll be incorrect.
      if (intersectsMainAxis(rect, cl)) {
        return dist + penalty;
      } else {
        return dist + penalty + crossAxisDist(rect, cl).abs();
      }
    }

    // Find all children that lay out along the infinite line at  various
    // distances.
    final candidates = node.parent._arenaChildren
        .where((n) => !identical(node, n) && !n.hasFocus)
        .where((n) => n.rect.overlaps(infiniteRect))
        .map((n) => FocusCandidate(n, rank(n)))
        .toList();

    candidates.sort((a, b) => a.rank.compareTo(b.rank));

    print(candidates);

    return candidates;
  }
}

extension on FocusNode {
  Iterable<FocusNode> get _arenaChildren {
    return children.expand((node) {
      if (!node.skipTraversal && node.canRequestFocus) {
        return [node];
      } else {
        if (node is FocusScopeNode && !node.canRequestFocus) {
          return const [];
        }

        return node._arenaChildren;
      }
    });
  }
}

// TODO: Opposite reading direction bias, and up directional bias for horizontal
// TODO: Limited interaction stack between two widgets as long as the list of candidates hasn't changed since last computed (otherwise, teleports occur)

mixin HorizontalDirectionResolver on DirectionResolver {
  bool intersectsMainAxis(Rect rect, Offset center) =>
      rect.top <= center.dy && rect.bottom >= center.dy;
  double crossAxisDist(Rect rect, Offset center) =>
      rect.bottom < center.dy ? center.dy - rect.bottom : rect.top - center.dy;
}

class LeftDirectionResolver extends DirectionResolver
    with HorizontalDirectionResolver {
  const LeftDirectionResolver();

  Offset biasedCenter(Rect rect) => rect.centerLeft;
  Rect infiniteRectFor(Offset center) => Rect.fromLTRB(double.negativeInfinity,
      double.negativeInfinity, center.dx, double.infinity);
  Rect matchDimen(Rect infiniteRect, Rect originalRect) => Rect.fromLTRB(
        double.negativeInfinity,
        originalRect.top,
        infiniteRect.right,
        originalRect.bottom,
      );

  double mainAxisDist(Rect rect, Offset center) => center.dx - rect.right;
}

// TODO: Update the biased centers:
// Most of the time when a user presses the "up" button, they expect to
// focus the item to the "start" (left in ltr order, right otherwise).
// And when a user presses left or right:
// If LTR, left has an upwards bias and right has a downwards bias.
// If RTL, right has an upwards bias and left has a downwards bias.
// This roughly follows their general reading order. The first word in a
// paragraph starts on the top left for an LTR layout, and the top right for
// a RTL layout.

class RightDirectionResolver extends DirectionResolver
    with HorizontalDirectionResolver {
  const RightDirectionResolver();

  Offset biasedCenter(Rect rect) => rect.centerRight;
  Rect infiniteRectFor(Offset center) => Rect.fromLTRB(
      center.dx, double.negativeInfinity, double.infinity, double.infinity);
  Rect matchDimen(Rect infiniteRect, Rect originalRect) => Rect.fromLTRB(
        infiniteRect.left,
        originalRect.top,
        double.infinity,
        originalRect.bottom,
      );

  double mainAxisDist(Rect rect, Offset center) => rect.left - center.dx;
}

mixin VerticalDirectionResolver on DirectionResolver {
  bool intersectsMainAxis(Rect rect, Offset center) =>
      rect.left <= center.dx && rect.right >= center.dx;
  double crossAxisDist(Rect rect, Offset center) =>
      rect.right < center.dx ? center.dx - rect.right : rect.left - center.dx;
}

class TopDirectionResolver extends DirectionResolver
    with VerticalDirectionResolver {
  const TopDirectionResolver();

  Offset biasedCenter(Rect rect) => rect.topCenter;
  Rect infiniteRectFor(Offset center) => Rect.fromLTRB(double.negativeInfinity,
      double.negativeInfinity, double.infinity, center.dy);
  Rect matchDimen(Rect infiniteRect, Rect originalRect) => Rect.fromLTRB(
        originalRect.left,
        double.negativeInfinity,
        originalRect.right,
        infiniteRect.bottom,
      );

  double mainAxisDist(Rect rect, Offset center) => center.dy - rect.bottom;
}

class BottomDirectionResolver extends DirectionResolver
    with VerticalDirectionResolver {
  const BottomDirectionResolver();

  Offset biasedCenter(Rect rect) => rect.bottomCenter;
  Rect infiniteRectFor(Offset center) => Rect.fromLTRB(
      double.negativeInfinity, center.dy, double.infinity, double.infinity);
  Rect matchDimen(Rect infiniteRect, Rect originalRect) => Rect.fromLTRB(
        originalRect.left,
        infiniteRect.top,
        originalRect.right,
        double.infinity,
      );

  double mainAxisDist(Rect rect, Offset center) => rect.top - center.dy;
}

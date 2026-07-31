import 'dart:ui';

/// Whether the ends of the drawn segments can be rendered with a round
/// [StrokeCap] instead of the [EndBlocks].
bool usesStrokeCap(double cornerRadius, double strokeWidth) =>
    cornerRadius >= strokeWidth / 2;

/// A rounded block which is drawn at an end of a progress or a track segment
/// to round its corners.
class EndBlock {
  double x = 0;

  double y = 0;

  /// The rotation in radians, matching the direction of the segment at this
  /// end.
  double rotation = 0;

  /// The uniform scale of the block, used to shrink the segments which are too
  /// short to hold two blocks.
  double scale = 1;
}

/// A pool of [EndBlock]s which reuses its entries between the updates to keep
/// the drawing updates allocation free.
class EndBlocks {
  final _blocks = <EndBlock>[];

  var _length = 0;

  int get length => _length;

  EndBlock operator [](int index) {
    assert(index < _length, 'index is out of range.');
    return _blocks[index];
  }

  void add({
    required double x,
    required double y,
    double rotation = 0,
    double scale = 1,
  }) {
    if (_length == _blocks.length) {
      _blocks.add(EndBlock());
    }

    _blocks[_length++]
      ..x = x
      ..y = y
      ..rotation = rotation
      ..scale = scale;
  }

  void reset() {
    _length = 0;
  }
}

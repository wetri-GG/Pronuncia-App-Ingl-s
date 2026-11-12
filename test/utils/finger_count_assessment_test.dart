import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:pronuncia/utils/finger_count_assessment.dart';

void main() {
  test('cuenta los dedos extendidos aunque la mano esté girada', () {
    final landmarks = _handLandmarks(rotateBy: math.pi / 2);

    expect(countRaisedFingers(landmarks), 5);
  });

  test('no cuenta los dedos plegados', () {
    expect(countRaisedFingers(_handLandmarks(extendedFingers: {})), 0);
  });

  test('cuenta solo los dedos extendidos', () {
    expect(countRaisedFingers(_handLandmarks(extendedFingers: {0, 2, 4})), 3);
  });

  test('ignora una lista de landmarks incompleta', () {
    expect(countRaisedFingers(const []), 0);
  });
}

List<Landmark> _handLandmarks({
  Set<int> extendedFingers = const {0, 1, 2, 3, 4},
  double rotateBy = 0,
}) {
  final points = List<Offset>.filled(21, Offset.zero);
  points[0] = const Offset(0.5, 0.9);
  points[1] = const Offset(0.32, 0.82);
  points[2] = const Offset(0.26, 0.79);
  points[3] = const Offset(0.2, 0.78);
  points[4] = extendedFingers.contains(0)
      ? const Offset(0.13, 0.77)
      : const Offset(0.42, 0.76);

  final fingers = [
    (
      5,
      6,
      7,
      8,
      const Offset(0.39, 0.62),
      const Offset(0.38, 0.52),
      const Offset(0.37, 0.44),
      const Offset(0.36, 0.34),
    ),
    (
      9,
      10,
      11,
      12,
      const Offset(0.49, 0.58),
      const Offset(0.49, 0.46),
      const Offset(0.49, 0.36),
      const Offset(0.49, 0.25),
    ),
    (
      13,
      14,
      15,
      16,
      const Offset(0.59, 0.61),
      const Offset(0.60, 0.51),
      const Offset(0.61, 0.43),
      const Offset(0.62, 0.34),
    ),
    (
      17,
      18,
      19,
      20,
      const Offset(0.67, 0.66),
      const Offset(0.69, 0.58),
      const Offset(0.71, 0.52),
      const Offset(0.73, 0.45),
    ),
  ];

  for (var index = 0; index < fingers.length; index++) {
    final (mcp, pip, dip, tip, base, joint, distal, extendedTip) =
        fingers[index];
    points[mcp] = base;
    points[pip] = joint;
    points[dip] = distal;
    points[tip] = extendedFingers.contains(index + 1)
        ? extendedTip
        : Offset.lerp(base, points[0], 0.2)!;
  }

  return points.map((point) {
    final dx = point.dx - 0.5;
    final dy = point.dy - 0.9;
    final rotatedX = dx * math.cos(rotateBy) - dy * math.sin(rotateBy);
    final rotatedY = dx * math.sin(rotateBy) + dy * math.cos(rotateBy);
    return Landmark(0.5 + rotatedX, 0.9 + rotatedY, 0);
  }).toList();
}

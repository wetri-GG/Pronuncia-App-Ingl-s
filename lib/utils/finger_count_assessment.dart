import 'dart:math' as math;

import 'package:hand_landmarker/hand_landmarker.dart';

/// Estimates the number of extended fingers from one hand's 21 landmarks.
int countRaisedFingers(List<Landmark> landmarks) {
  if (landmarks.length < 21) return 0;

  final wrist = landmarks[0];
  final palmLength = _distance(wrist, landmarks[9]);
  if (palmLength < 0.001) return 0;

  var count = 0;
  final thumbExtension =
      _distance(landmarks[4], landmarks[5]) -
      _distance(landmarks[3], landmarks[5]);
  if (thumbExtension > palmLength * 0.12) count++;

  for (final (mcp, tip) in [(5, 8), (9, 12), (13, 16), (17, 20)]) {
    final base = landmarks[mcp];
    final fingertip = landmarks[tip];
    final axisX = base.x - wrist.x;
    final axisY = base.y - wrist.y;
    final axisLength = math.sqrt(axisX * axisX + axisY * axisY);
    if (axisLength < 0.001) continue;

    final extension =
        ((fingertip.x - base.x) * axisX + (fingertip.y - base.y) * axisY) /
        axisLength;
    if (extension > palmLength * 0.18) count++;
  }

  return count;
}

double _distance(Landmark first, Landmark second) {
  final dx = first.x - second.x;
  final dy = first.y - second.y;
  return math.sqrt(dx * dx + dy * dy);
}

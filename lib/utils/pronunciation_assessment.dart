int pronunciationMatchScore(String expected, String recognized) {
  final target = _normalize(expected);
  final answer = _normalize(recognized);
  if (target.isEmpty || answer.isEmpty) return 0;
  if (target == answer) return 100;

  var previous = List<int>.generate(answer.length + 1, (index) => index);
  for (var row = 1; row <= target.length; row++) {
    final current = List<int>.filled(answer.length + 1, 0)..[0] = row;
    for (var column = 1; column <= answer.length; column++) {
      final substitutionCost =
          target.codeUnitAt(row - 1) == answer.codeUnitAt(column - 1) ? 0 : 1;
      current[column] = [
        current[column - 1] + 1,
        previous[column] + 1,
        previous[column - 1] + substitutionCost,
      ].reduce((left, right) => left < right ? left : right);
    }
    previous = current;
  }

  final length = target.length > answer.length ? target.length : answer.length;
  return ((length - previous.last) * 100 / length)
      .round()
      .clamp(0, 100)
      .toInt();
}

String _normalize(String value) => value
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
    .replaceAll(RegExp(r'\s+'), ' ');

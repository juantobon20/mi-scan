import 'dart:math';

typedef IdGenerator = String Function();

final _random = Random();

String generateId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';

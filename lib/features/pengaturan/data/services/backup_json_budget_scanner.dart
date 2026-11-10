part of 'backup_input_limits.dart';

/// Walks syntax without constructing the value tree. Only bounded object keys
/// are decoded to recognize tables and logo paths, including escaped keys.
/// The standard decoder remains responsible for final JSON validation.
class _BackupJsonBudgetScanner {
  _BackupJsonBudgetScanner(this.raw);

  final String raw;
  var offset = 0;
  var units = 0;
  var rows = 0;

  void scan() {
    _value(0, const []);
    _whitespace();
    if (offset != raw.length) throw const FormatException();
  }

  void _whitespace() {
    while (offset < raw.length) {
      final c = raw.codeUnitAt(offset);
      if (c != 32 && c != 9 && c != 10 && c != 13) break;
      offset++;
    }
  }

  int get _peek {
    _whitespace();
    if (offset >= raw.length) throw const FormatException();
    return raw.codeUnitAt(offset);
  }

  void _take(int expected) {
    if (_peek != expected) throw const FormatException();
    offset++;
    if (++units > BackupInputLimits.maxTokens) {
      BackupInputLimits.exceeded('kompleksitas JSON');
    }
  }

  void _value(int depth, List<String> path) {
    final c = _peek;
    if (c == 123 || c == 91) {
      if (depth >= BackupInputLimits.maxDepth) {
        BackupInputLimits.exceeded('kedalaman 12 tingkat');
      }
      _take(c);
      final end = c == 123 ? 125 : 93;
      if (_peek != end) {
        while (true) {
          if (c == 123) {
            final key = _string(BackupInputLimits.maxStringLength, key: true)!;
            _take(58);
            _value(depth + 1, [...path, key]);
          } else {
            if (path.length == 2 && path.first == 'tables') {
              if (++rows > BackupInputLimits.maxRows) {
                BackupInputLimits.exceeded('jumlah 50.000 baris');
              }
            }
            _value(depth + 1, [...path, '[]']);
          }
          if (_peek == end) break;
          _take(44);
        }
      }
      _take(end);
    } else if (c == 34) {
      final logo =
          path.length == 3 &&
          path[0] == 'assets' &&
          path[1] == 'business_logo' &&
          path[2] == 'data_base64';
      _string(
        logo
            ? BackupInputLimits.maxLogoLength
            : BackupInputLimits.maxStringLength,
      );
    } else {
      final start = offset;
      while (offset < raw.length) {
        final c = raw.codeUnitAt(offset);
        if (c == 44 ||
            c == 93 ||
            c == 125 ||
            c == 32 ||
            c == 9 ||
            c == 10 ||
            c == 13) {
          break;
        }
        _take(c);
      }
      if (offset == start) throw const FormatException();
    }
  }

  String? _string(int limit, {bool key = false}) {
    final start = offset;
    _take(34);
    var length = 0;
    while (offset < raw.length) {
      final c = raw.codeUnitAt(offset++);
      if (c == 34) {
        return key ? jsonDecode(raw.substring(start, offset)) as String : null;
      }
      if (c == 92) {
        if (offset >= raw.length) throw const FormatException();
        final escape = raw.codeUnitAt(offset++);
        if (escape == 117) offset += 4;
      }
      // Each escape is one decoded UTF-16 unit, including surrogate halves.
      if (++length > limit) {
        BackupInputLimits.exceeded(key ? 'panjang kunci' : 'panjang nilai');
      }
    }
    throw const FormatException();
  }
}

import 'package:flutter/widgets.dart';

/// Small, forgiving JSON readers. Every reader returns `null` instead of
/// throwing when the value has an unexpected type, so a typo in a remote
/// config never crashes a page.
class WJson {
  const WJson._();

  static String? str(Object? v) => v?.toString();

  static double? dbl(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? integer(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static bool? boolean(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return null;
  }

  static Map<String, dynamic>? map(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return null;
  }

  static List<String>? strList(Object? v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) {
      return v
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return null;
  }

  static List<double>? dblList(Object? v) {
    if (v is List) {
      final out = <double>[];
      for (final e in v) {
        final d = dbl(e);
        if (d != null) out.add(d);
      }
      return out;
    }
    return null;
  }

  static DateTime? date(Object? v) {
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static Duration? millis(Object? v) {
    final i = integer(v);
    return i == null ? null : Duration(milliseconds: i);
  }

  /// Accepts `#RGB`, `#RRGGBB`, `#AARRGGBB`, `0xAARRGGBB` or an int.
  static Color? color(Object? v) {
    if (v is int) return Color(v);
    if (v is! String) return null;
    var s = v.trim().toLowerCase();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.startsWith('0x')) s = s.substring(2);
    if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
    if (s.length == 6) s = 'ff$s';
    if (s.length != 8) return null;
    final value = int.tryParse(s, radix: 16);
    return value == null ? null : Color(value);
  }

  /// Accepts `[dx, dy]` or `{x, y}` / `{dx, dy}`.
  static Offset? offset(Object? v) {
    if (v is List) {
      final l = dblList(v) ?? const [];
      return l.length == 2 ? Offset(l[0], l[1]) : null;
    }
    final m = map(v);
    if (m == null) return null;
    final x = dbl(m['x'] ?? m['dx']);
    final y = dbl(m['y'] ?? m['dy']);
    return x == null && y == null ? null : Offset(x ?? 0, y ?? 0);
  }

  /// Accepts a list of colours (`["#f00", "#00f"]`, left to right) or
  /// `{"colors": [...], "begin": "topLeft", "end": "bottomRight"}`.
  static Gradient? gradient(Object? v) {
    final m = map(v);
    final raw = m == null ? v : m['colors'];
    if (raw is! List) return null;
    final colors = [for (final c in raw) color(c)].whereType<Color>().toList();
    if (colors.length < 2) return null;
    Alignment align(Object? a, Alignment d) {
      switch (a?.toString()) {
        case 'topLeft':
          return Alignment.topLeft;
        case 'topCenter':
          return Alignment.topCenter;
        case 'topRight':
          return Alignment.topRight;
        case 'centerLeft':
          return Alignment.centerLeft;
        case 'center':
          return Alignment.center;
        case 'centerRight':
          return Alignment.centerRight;
        case 'bottomLeft':
          return Alignment.bottomLeft;
        case 'bottomCenter':
          return Alignment.bottomCenter;
        case 'bottomRight':
          return Alignment.bottomRight;
      }
      return d;
    }

    return LinearGradient(
      colors: colors,
      begin: align(m?['begin'], Alignment.centerLeft),
      end: align(m?['end'], Alignment.centerRight),
    );
  }

  /// Accepts a number (all sides), `[h, v]`, `[l, t, r, b]` or
  /// `{left, top, right, bottom}`.
  static EdgeInsets? insets(Object? v) {
    final n = dbl(v);
    if (n != null) return EdgeInsets.all(n);
    if (v is List) {
      final l = dblList(v) ?? const [];
      if (l.length == 2) {
        return EdgeInsets.symmetric(horizontal: l[0], vertical: l[1]);
      }
      if (l.length == 4) return EdgeInsets.fromLTRB(l[0], l[1], l[2], l[3]);
      return null;
    }
    final m = map(v);
    if (m != null) {
      return EdgeInsets.fromLTRB(
        dbl(m['left']) ?? 0,
        dbl(m['top']) ?? 0,
        dbl(m['right']) ?? 0,
        dbl(m['bottom']) ?? 0,
      );
    }
    return null;
  }

  static T? enumByName<T extends Enum>(List<T> values, Object? v) {
    if (v == null) return null;
    final s =
        v.toString().toLowerCase().replaceAll('_', '').replaceAll('-', '');
    for (final e in values) {
      if (e.name.toLowerCase() == s) return e;
    }
    return null;
  }

  static String colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';
}

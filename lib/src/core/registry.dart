import 'package:flutter/widgets.dart';

import '../models/dolphin_config.dart';
import '../models/dolphin_step.dart';

/// A mounted `DolphinTarget`.
class TargetHandle {
  TargetHandle({
    required this.id,
    required this.scope,
    required this.key,
    required this.serial,
    this.inline,
    this.onTapped,
  });

  final String id;
  final String scope;
  final GlobalKey key;

  /// Registration order; used as the natural order of inline-only steps.
  final int serial;
  DolphinStep? inline;
  VoidCallback? onTapped;

  BuildContext? get context => key.currentContext;
}

/// A mounted `DolphinScope` (page).
abstract class ScopeHandle {
  String get id;
  BuildContext get context;
  bool get mounted;

  /// True when the page is the current route, finished animating, not
  /// covered by another route and not in an inactive tab.
  bool get isVisible;

  /// Per-widget settings (inline steps, sequence, exclude, theme, autoStart).
  ScopeConfig get inlineConfig;
}

/// A complete app-guide / walkthrough / showcase toolkit for Flutter.
library;

export 'src/core/registry.dart' show TargetHandle, ScopeHandle;
export 'src/core/scope_summary.dart';
export 'src/core/target_geometry.dart';
export 'src/core/dolphin_controller.dart';
export 'src/core/dolphin_event.dart';
export 'src/models/dolphin_config.dart';
export 'src/models/dolphin_progress.dart';
export 'src/models/dolphin_step.dart';
export 'src/storage/default_store.dart';
export 'src/storage/shared_preferences_store.dart';
export 'src/storage/sqflite_store_web.dart'
    if (dart.library.io) 'src/storage/sqflite_store.dart';
export 'src/storage/dolphin_store.dart';
export 'src/ui/highlight_shape.dart';
export 'src/ui/pointer_style.dart';
export 'src/ui/tooltip_layout.dart'
    show TooltipLayoutDelegate, PointerPainter, PointerPlacement, TooltipSlot;
export 'src/ui/tooltip_presets.dart' show DolphinCounter, DolphinButtons;
export 'src/ui/dolphin_theme.dart';
export 'src/widgets/dolphin_widgets.dart';

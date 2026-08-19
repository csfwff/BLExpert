part of 'home_screen.dart';

Map<ShortcutActivator, VoidCallback> _appShortcutBindings({
  required FocusNode inputFocusNode,
  required VoidCallback onSend,
  required VoidCallback onClearLogs,
  required VoidCallback onToggleInspector,
}) {
  return <ShortcutActivator, VoidCallback>{
    const SingleActivator(LogicalKeyboardKey.keyL, control: true):
        inputFocusNode.requestFocus,
    const SingleActivator(LogicalKeyboardKey.enter, control: true): onSend,
    const SingleActivator(LogicalKeyboardKey.keyK, control: true, shift: true):
        onClearLogs,
    const SingleActivator(LogicalKeyboardKey.keyI, control: true, shift: true):
        onToggleInspector,
  };
}

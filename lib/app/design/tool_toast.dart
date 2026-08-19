import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app_theme.dart';

void showToolToast(BuildContext context, String message) {
  shad.showToast(
    context: context,
    location: shad.ToastLocation.bottomCenter,
    entryDuration: AppMotion.resolve(context, AppMotion.overlay),
    showDuration: const Duration(milliseconds: 1800),
    builder: (BuildContext context, shad.ToastOverlay overlay) => shad.Card(
      filled: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(message),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:premium_force_driver/common_widgets/button.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/services/app_update_service.dart';

/// Shown in place of the app when this build is below the minimum supported
/// one.
///
/// It is a dead end on purpose: back is swallowed and there is nothing to
/// navigate to. The only way forward is the store.
class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF303030), Color(0xFF1A1A1A)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.system_update,
                  color: Color(0xFFE4A46B),
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.updateRequiredTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.updateRequiredMessage,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                PremiumButton(
                  text: l10n.updateNow,
                  fontsize: 16,
                  showLoader: false,
                  onTap: AppUpdateService.openStore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Offer a newer build without forcing it. Resolves once the dialog closes,
/// whichever button was used.
Future<void> showUpdateAvailableDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        l10n.updateAvailableTitle,
        style: const TextStyle(color: Colors.white),
      ),
      content: Text(
        l10n.updateAvailableMessage,
        style: const TextStyle(color: Colors.grey),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            l10n.updateLater,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            AppUpdateService.openStore();
          },
          child: Text(
            l10n.updateNow,
            style: const TextStyle(color: Color(0xFFE4A46B)),
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:premium_force_driver/account/manage_profile.dart';
import 'package:premium_force_driver/authentication/login.dart';
import 'package:premium_force_driver/common_widgets/button.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/providers/auth_provider.dart';
import 'package:premium_force_driver/providers/trips_provider.dart';
import 'package:premium_force_driver/main.dart';

import 'package:premium_force_driver/common_widgets/snackbar.dart';
import 'package:premium_force_driver/utils/smooth_navigation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    debugPrint("Driver UID: ${authProvider.driver?.uid}");
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF303030),
            Color(0xFF303030),
            Color(0xFF1A1A1A),
            Color(0xFF1A1A1A),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buidAppBar(context, loc),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageProfilePage(),
                    ),
                  );
                },
                child: profileTile(
                  loc: loc,
                  title: loc.manageProfile,
                  icon: Icons.person_outline,
                  isSvg: false,
                  svgPath: "",
                ),
              ),

              GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse('https://premiumforcegroup.com/terms-and-conditions');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Could not launch terms URL: $e');
                  }
                },
                child: profileTile(
                  loc: loc,
                  isSvg: false,
                  title: loc.termsAndConditions,
                  icon: Icons.description,
                  svgPath: "assets/icons/terms_and_conditions.svg",
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse('https://premiumforcegroup.com/privacy-policy');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Could not launch privacy URL: $e');
                  }
                },
                child: profileTile(
                  loc: loc,
                  isSvg: false,
                  title: loc.privacyPolicy,
                  icon: Icons.privacy_tip_outlined,
                  svgPath: "",
                ),
              ),
              profileTile(
                loc: loc,
                title: loc.language,
                icon: Icons.language,
                trailingOverride: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          MainApp.setLocale(context, const Locale('en'));
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Localizations.localeOf(context).languageCode == 'en'
                                ? Colors.white
                                : Colors.black,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'English',
                            style: TextStyle(
                              color: Localizations.localeOf(context).languageCode == 'en'
                                  ? Colors.black
                                  : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          MainApp.setLocale(context, const Locale('ar'));
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Localizations.localeOf(context).languageCode == 'ar'
                                ? Colors.white
                                : Colors.black,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'العربية',
                            style: TextStyle(
                              color: Localizations.localeOf(context).languageCode == 'ar'
                                  ? Colors.black
                                  : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (context.read<TripsProvider>().hasLiveTrip) {
                    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                    AnimatedSnackBar.show(
                      context,
                      isArabic ? 'لا يمكنك تسجيل الخروج أثناء وجود حجز نشط' : 'Cannot logout while having an active booking',
                      'E',
                    );
                    return;
                  }
                  _showLogoutBottomSheet(context, loc);
                },
                child: profileTile(
                  loc: loc,
                  isLogout: true,
                  title: loc.logout,
                  icon: Icons.logout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget buidAppBar(BuildContext context, AppLocalizations loc) {
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(100), Colors.transparent],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            loc.account,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
        ),
      ),
    );
  }

  Widget profileTile({
    required AppLocalizations loc,
    required String title,
    required IconData icon,
    bool isSvg = false,
    bool isDelete = false,
    bool isLogout = false,
    bool isLast = false,
    String? svgPath,
    Widget? trailingOverride,
  }) {
    return ListTile(
      shape: Border(
        bottom: BorderSide(
          color: isLast
              ? Colors.transparent
              : Colors.grey.shade800.withAlpha(160),
        ),
      ),
      minTileHeight: 80,
      leading: isSvg
          ? SvgPicture.asset(svgPath!, width: 24, height: 24)
          : ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF404040),
                    Color(0xFFC0C0C0),
                    Color(0xFF808080),
                  ],
                ).createShader(bounds);
              },
              child: Icon(icon, color: Colors.white),
            ),
      trailing:
          trailingOverride ??
          (!(isDelete || isLogout)
              ? ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF404040),
                        Color(0xFFC0C0C0),
                        Color(0xFF808080),
                      ],
                    ).createShader(bounds);
                  },
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              : null),
      title: Text(title, style: TextStyle(color: Colors.white)),
    );
  }

  void _showLogoutBottomSheet(BuildContext context, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF303030),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ShaderMask(
              //   shaderCallback: (Rect bounds) {
              //     return const LinearGradient(
              //       begin: Alignment.centerLeft,
              //       end: Alignment.centerRight,
              //       colors: [
              //         Color(0xFF49280B),
              //         Color(0xFFE4A46B),
              //         Color(0xFF60350F),
              //       ],
              //     ).createShader(bounds);
              //   },
              //   child: const Icon(Icons.logout, color: Colors.white, size: 50),
              // ),
              Padding(
                padding: const EdgeInsets.only(
                  top: 24,
                  bottom: 12,
                  left: 24,
                  right: 24,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.logout,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetContext),
                      child: Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white, thickness: 1),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.logoutConfirm,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.loginAgainMessage,
                  textAlign: TextAlign.start,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 80),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(sheetContext),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade600),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            loc.cancel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: PremiumButton(
                        onTap: () async {
                          final authProvider = context.read<AuthProvider>();
                          Navigator.pop(sheetContext); // Close bottom sheet
                          await authProvider.logout();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              SmoothNavigation.route(
                                const PremiumForceLoginPage(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        text: loc.logout,
                        fontsize: 14,
                        showLoader: false,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

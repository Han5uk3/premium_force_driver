import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:premium_force_driver/main.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_driver/authentication/otp.dart';
import 'package:premium_force_driver/common_widgets/button.dart';
import 'package:premium_force_driver/common_widgets/checkbox.dart';
import 'package:premium_force_driver/common_widgets/snackbar.dart';
import 'package:premium_force_driver/common_widgets/textfield.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/providers/auth_provider.dart';
import 'package:premium_force_driver/utils/smooth_navigation.dart';
import 'package:country_picker/country_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class PremiumForceLoginPage extends StatefulWidget {
  const PremiumForceLoginPage({super.key});

  @override
  State<PremiumForceLoginPage> createState() => _PremiumForceLoginPageState();
}

final _formKey = GlobalKey<FormState>();

class _PremiumForceLoginPageState extends State<PremiumForceLoginPage> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isAgreed = false;
  bool _isLoading = false;
  String _selectedCountryCode = '966';

  @override
  void dispose() {
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Show dialog when driver is not registered
  void _showNotRegisteredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            AppLocalizations.of(context)!.driverNotRegistered,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            AppLocalizations.of(context)!.noDriverRegistered,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppLocalizations.of(context)!.ok,
                style: const TextStyle(
                  color: Color(0xFFC0C0C0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Top section with logo
            Expanded(
              flex: 30,
              child: SizedBox(
                child: Image.asset(
                  'assets/applogo/premiumforcelogo.png', // You'll need to add your logo
                  width: 180,
                  height: 100,
                ),
              ),
            ),
            // Bottom section with form
            Expanded(
              flex: 55,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF333333), Color(0xFF111111)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        // Sign In Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.signIn,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF404040),
                                    Color(0xFFC0C0C0),
                                    Color(0xFF808080),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(80),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(1.5),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF1E1E1E),
                                ),
                                padding: const EdgeInsets.all(1.5),
                                child: ClipOval(
                                  child: InkWell(
                                    onTap: () {
                                      bool isCurrentlyEnglish =
                                          Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'en';
                                      MainApp.setLocale(
                                        context,
                                        Locale(
                                          isCurrentlyEnglish ? 'ar' : 'en',
                                        ),
                                      );
                                    },
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: SvgPicture.asset(
                                        Localizations.localeOf(
                                                  context,
                                                ).languageCode ==
                                                'en'
                                            ? 'assets/flags/en.svg'
                                            : 'assets/flags/ar.svg',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        PremiumTextField(
                          title: AppLocalizations.of(context)!.mobileNumber,
                          validator: (value) {
                            if (value!.isEmpty) {
                              return AppLocalizations.of(
                                context,
                              )!.pleaseEnterYourMobileNumber;
                            }
                            if (value.length < 9) {
                              return AppLocalizations.of(
                                context,
                              )!.pleaseEnterValidMobileNumber;
                            }
                            return null;
                          },
                          controller: _mobileController,
                          hintText: AppLocalizations.of(
                            context,
                          )!.enterMobileNumber,
                          fontsize: 14,

                          keyboardType: TextInputType.phone,
                          needTitle: true,
                          obscureText: false,
                          prefixIcon: GestureDetector(
                            onTap: () {
                              showCountryPicker(
                                context: context,
                                showPhoneCode: true,
                                customFlagBuilder: (context) =>
                                    const SizedBox.shrink(),
                                countryListTheme: CountryListThemeData(
                                  backgroundColor: const Color(0xFF111111),
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  searchTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(30),
                                    topRight: Radius.circular(30),
                                  ),
                                  inputDecoration: InputDecoration(
                                    hintText: AppLocalizations.of(
                                      context,
                                    )!.search,
                                    hintStyle: TextStyle(
                                      color: Colors.white.withAlpha(180),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      color: Colors.white,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF1A1A1A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFC0C0C0),
                                      ),
                                    ),
                                  ),
                                  bottomSheetHeight:
                                      MediaQuery.of(context).size.height * 0.75,
                                ),
                                onSelect: (Country country) {
                                  setState(() {
                                    _selectedCountryCode = country.phoneCode;
                                  });
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+$_selectedCountryCode',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white,
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    height: 24,
                                    width: 1,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Continue Button
                        const SizedBox(height: 20),
                        // Terms and Conditions
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PremiumCheckbox(
                              ontap: () {
                                setState(() {
                                  _isAgreed = !_isAgreed;
                                });
                              },
                              isAgreed: _isAgreed,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Color(0xFFB0B0B0),
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: AppLocalizations.of(
                                        context,
                                      )!.byClickingContinue,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          " ${AppLocalizations.of(context)!.termsAndConditions} ",
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () async {
                                          final Uri url = Uri.parse('https://premiumforcegroup.com/terms-and-conditions');
                                          try {
                                            await launchUrl(url, mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            // No handler for the URL — the tap does nothing.
                                          }
                                        },
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    TextSpan(
                                      text: AppLocalizations.of(context)!.and,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          " ${AppLocalizations.of(context)!.privacyPolicy} ",
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () async {
                                          final Uri url = Uri.parse('https://premiumforcegroup.com/privacy-policy');
                                          try {
                                            await launchUrl(url, mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            // No handler for the URL — the tap does nothing.
                                          }
                                        },
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 25),
                        PremiumButton(
                          showLoader: _isLoading,
                          fontsize: 16,
                          text: AppLocalizations.of(context)!.continueText,
                          onTap: () async {
                            if (_formKey.currentState!.validate() &&
                                _isAgreed) {
                              final authProvider = context.read<AuthProvider>();
                              final navigator = Navigator.of(context);

                              setState(() => _isLoading = true);

                              final success = await authProvider.requestOtp(
                                countryCode: '+$_selectedCountryCode',
                                phoneNumber: _mobileController.text.trim(),
                              );

                              if (!mounted) return;
                              setState(() => _isLoading = false);

                              if (success) {
                                navigator.push(
                                  SmoothNavigation.route(
                                    OTPVerificationPage(
                                      countryCode: '+$_selectedCountryCode',
                                      phoneNumber: _mobileController.text
                                          .trim(),
                                    ),
                                  ),
                                );
                              } else {
                                // Check if this is a "not registered" error
                                final errorMsg =
                                    authProvider.errorMessage ?? '';
                                if (errorMsg.contains(
                                  AppLocalizations.of(
                                    context,
                                  )!.noDriverRegisteredError,
                                )) {
                                  _showNotRegisteredDialog();
                                } else {
                                  AnimatedSnackBar.show(context, errorMsg, "E");
                                }
                              }
                            } else if (_isAgreed == false) {
                              AnimatedSnackBar.show(
                                context,
                                AppLocalizations.of(
                                  context,
                                )!.pleaseAgreeToTheTermsAndConditionsAndPrivacyPolicy,
                                "E",
                              );
                            }
                          },
                        ),

                        const SizedBox(height: 24),

                        // ── OR divider ─────────────────────────────────
                        // Row(
                        //   children: [
                        //     Expanded(
                        //       child: Container(
                        //         height: 1,
                        //         decoration: BoxDecoration(
                        //           gradient: LinearGradient(
                        //             colors: [
                        //               Colors.transparent,
                        //               Colors.white.withAlpha(60),
                        //             ],
                        //           ),
                        //         ),
                        //       ),
                        //     ),
                        //     Padding(
                        //       padding: const EdgeInsets.symmetric(
                        //         horizontal: 16,
                        //       ),
                        //       child: Text(
                        //         'OR',
                        //         style: TextStyle(
                        //           color: Colors.white.withAlpha(150),
                        //           fontSize: 12,
                        //           fontWeight: FontWeight.w500,
                        //           letterSpacing: 1.5,
                        //         ),
                        //       ),
                        //     ),
                        //     Expanded(
                        //       child: Container(
                        //         height: 1,
                        //         decoration: BoxDecoration(
                        //           gradient: LinearGradient(
                        //             colors: [
                        //               Colors.white.withAlpha(60),
                        //               Colors.transparent,
                        //             ],
                        //           ),
                        //         ),
                        //     //   ),
                        //     // ),
                        //   ],
                        // ),

                        // const SizedBox(height: 24),
                        // const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

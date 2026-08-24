import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:premium_force_driver/providers/auth_provider.dart';
import 'package:premium_force_driver/common_widgets/button.dart';
import 'package:premium_force_driver/common_widgets/snackbar.dart';
import 'package:premium_force_driver/authentication/signup.dart';
import 'package:premium_force_driver/authentication/blocked_page.dart';
import 'package:premium_force_driver/home/home.dart';
import 'package:premium_force_driver/utils/smooth_navigation.dart';

class OTPVerificationPage extends StatefulWidget {
  final String countryCode;
  final String phoneNumber;
  const OTPVerificationPage({
    super.key,
    required this.countryCode,
    required this.phoneNumber,
  });

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  static const int _otpLength = 6;

  /// Matches an [_otpLength]-digit run that isn't part of a longer number, so a
  /// phone number or an order id in the same message is not mistaken for a code.
  static const String _smsCodeMatcher = '(?<!\\d)\\d{$_otpLength}(?!\\d)';

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  bool _isVerifying = false;

  /// Guards against stacking SMS User Consent listeners across resends.
  bool _isListeningForSms = false;

  @override
  void initState() {
    super.initState();
    _listenForSmsCode();
  }

  @override
  void dispose() {
    if (_isListeningForSms) {
      SmartAuth.instance.removeUserConsentApiListener();
    }
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  /// Android SMS autofill via the SMS User Consent API.
  ///
  /// Registers a one-shot listener; Android shows its own consent dialog when a
  /// matching SMS arrives, and only on approval do we get the message body.
  /// The listener is one-shot by design, so this is called again after a resend.
  ///
  /// iOS needs nothing here: the Pinput field advertises
  /// [AutofillHints.oneTimeCode] inside an [AutofillGroup], which is what drives
  /// the QuickType "From Messages" suggestion above the keyboard.
  Future<void> _listenForSmsCode() async {
    if (!Platform.isAndroid || _isListeningForSms) return;

    _isListeningForSms = true;
    final res = await SmartAuth.instance.getSmsWithUserConsentApi(
      matcher: _smsCodeMatcher,
    );
    _isListeningForSms = false;

    // The page may have been popped while we were waiting on the user, which
    // would leave _otpController disposed.
    if (!mounted) return;

    final code = res.hasData ? res.requireData.code : null;
    if (code == null || code.length != _otpLength) return;

    // Triggers Pinput's onCompleted, which runs the verify action.
    _otpController.setText(code);
  }

  /// Formats seconds as mm:ss (e.g. 01:05).
  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Handle OTP verification and navigate based on result.
  Future<void> _handleVerify() async {
    if (_otpController.text.length != 6) {
      AnimatedSnackBar.show(context, "Please enter a valid OTP", "E");
      return;
    }

    setState(() => _isVerifying = true);

    final authProvider = context.read<AuthProvider>();
    await authProvider.verifyOtp(
      otp: _otpController.text,
      countryCode: widget.countryCode,
      phoneNumber: widget.phoneNumber,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (authProvider.status == AuthStatus.authenticated) {
      if (authProvider.driver?.isActive == false) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const BlockedPage()),
          (route) => false,
        );
      } else {
        // ── Existing user → go straight to Home ──
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => Home()),
          (route) => false,
        );
      }
    } else if (authProvider.status == AuthStatus.otpVerified) {
      // ── New user → go to SignUp ──
      Navigator.of(context).push(
        SmoothNavigation.route(
          SignUpPage(
            countryCode: widget.countryCode,
            phoneNumber: widget.phoneNumber,
          ),
        ),
      );
    } else if (authProvider.status == AuthStatus.failure &&
        authProvider.errorMessage != null) {
      AnimatedSnackBar.show(context, authProvider.errorMessage!, "E");
    }
  }

  @override
  Widget build(BuildContext context) {
    PreferredSizeWidget buidAppBar() {
      return PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withAlpha(150), Colors.transparent],
            ),
          ),
          child: AppBar(
            centerTitle: true,
            title: Text(
              "Enter OTP",
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ),
      );
    }

    final defaultPinTheme = PinTheme(
      width: 55,
      height: 55,
      textStyle: const TextStyle(
        fontSize: 20,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
    );

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
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        appBar: buidAppBar(),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 50),

              // Title
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'OTP has been sent to ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: '${widget.countryCode} ${widget.phoneNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // OTP Input Fields
              Directionality(
                // Digits run left to right whatever the app's language is.
                textDirection: TextDirection.ltr,
                child: AutofillGroup(
                  // Ensures the OS-level "code from Messages" autofill
                  // suggestion reliably appears for this field.
                  child: Pinput(
                    length: _otpLength,
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    defaultPinTheme: defaultPinTheme,
                    obscureText: true,
                    obscuringCharacter: '*',
                    enableInteractiveSelection: true,
                    showCursor: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    // Long-press offers Paste and nothing else — the field is
                    // obscured, so Copy, Cut and Select All have nothing
                    // useful to act on.
                    contextMenuBuilder: (context, editableTextState) {
                      final List<ContextMenuButtonItem> buttonItems = [
                        ContextMenuButtonItem(
                          onPressed: () {
                            editableTextState.pasteText(
                              SelectionChangedCause.toolbar,
                            );
                          },
                          type: ContextMenuButtonType.paste,
                        ),
                      ];

                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: editableTextState.contextMenuAnchors,
                        buttonItems: buttonItems,
                      );
                    },
                    separatorBuilder: (index) => const SizedBox(width: 8),
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        border: Border.all(color: const Color(0xFFD4D4D4)),
                      ),
                    ),
                    onCompleted: (pin) {
                      // All six digits in: run the same action as the Verify
                      // button, however they arrived — typed, pasted, or
                      // filled by the OS.
                      _otpFocusNode.unfocus();
                      _handleVerify();
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Resend OTP row ──────────────────────────────────
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  final canResend = authProvider.resendCountdown == 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(180),
                        ),
                      ),
                      GestureDetector(
                        onTap: canResend
                            ? () {
                                context.read<AuthProvider>().requestOtpResend(
                                  countryCode: widget.countryCode,
                                  phoneNumber: widget.phoneNumber,
                                );
                                // The previous listener was consumed by the
                                // first OTP, so re-arm it for this one.
                                _listenForSmsCode();
                                AnimatedSnackBar.show(
                                  context,
                                  "OTP has been resent to ${widget.countryCode} ${widget.phoneNumber}",
                                  "S",
                                );
                              }
                            : null,
                        child: Text(
                          canResend
                              ? 'Resend OTP'
                              : 'Resend in ${_formatCountdown(authProvider.resendCountdown)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: canResend
                                ? const Color(0xFFD4D4D4)
                                : Colors.white.withAlpha(100),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 56),

              // Verify Button
              PremiumButton(
                showLoader: _isVerifying,
                fontsize: 16,
                text: "Verify",
                onTap: _isVerifying ? () {} : _handleVerify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

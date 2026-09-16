import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_driver/app_update/app_update_prompts.dart';
import 'package:premium_force_driver/authentication/login.dart';
import 'package:premium_force_driver/authentication/blocked_page.dart';
import 'package:premium_force_driver/home/home.dart';
import 'package:premium_force_driver/providers/auth_provider.dart';
import 'package:premium_force_driver/services/app_update_service.dart';
import 'package:premium_force_driver/utils/smooth_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Defer so the widget tree finishes building before AuthProvider
    // calls notifyListeners().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _navigateAfterSplash();
      }
    });
  }

  Future<void> _navigateAfterSplash() async {
    final authProvider = context.read<AuthProvider>();
    // Never throws — a failed check lets the driver in.
    final updateCheck = AppUpdateService.check();

    try {
      // Show splash for at least 3 seconds while checking auth and the minimum
      // supported build in parallel
      await Future.wait([
        authProvider.checkAuth(),
        updateCheck,
        Future.delayed(const Duration(seconds: 3)),
      ]);
    } catch (e) {
      // Auth check failed; the unauthenticated branch below routes to Login.
    }

    // Already settled by the wait above; read before the mounted check so no
    // async gap sits between it and the navigation below.
    final updateStatus = await updateCheck;

    if (!mounted) return;

    switch (updateStatus) {
      case AppUpdateStatus.required:
        // Ahead of the auth routing: an unsupported build must not reach Home
        // or Login, whatever state the account is in.
        Navigator.pushReplacement(
          context,
          SmoothNavigation.route(const UpdateRequiredPage()),
        );
        return;
      case AppUpdateStatus.optional:
        await showUpdateAvailableDialog(context);
        if (!mounted) return;
      case AppUpdateStatus.upToDate:
        break;
    }

    if (authProvider.status == AuthStatus.authenticated &&
        authProvider.driver != null) {
      if (authProvider.driver?.isActive == false) {
        Navigator.pushReplacement(context, SmoothNavigation.route(const BlockedPage()));
      } else {
        Navigator.pushReplacement(context, SmoothNavigation.route(const Home()));
      }
    } else {
      Navigator.pushReplacement(
        context,
        SmoothNavigation.route(const PremiumForceLoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/splashimage.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.3,
                colors: [Colors.transparent, Colors.black.withAlpha(180)],
                stops: const [0.4, 1.0],
                center: Alignment.center,
              ),
            ),
          ),
          Center(
            child: Image.asset(
              'assets/applogo/premiumforcelogo.png',
              width: MediaQuery.of(context).size.width / 1.8,
              height: 300,
            ),
          ),
        ],
      ),
    );
  }
}

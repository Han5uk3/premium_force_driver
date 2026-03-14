import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_driver/authentication/login.dart';
import 'package:premium_force_driver/home/home.dart';
import 'package:premium_force_driver/providers/auth_provider.dart';
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
      _navigateAfterSplash();
    });
  }

  Future<void> _navigateAfterSplash() async {
    final authProvider = context.read<AuthProvider>();

    try {
      // Show splash for at least 3 seconds while checking auth in parallel
      debugPrint('⏱️ Starting splash delay and auth check...');
      await Future.wait([
        authProvider.checkAuth(),
        Future.delayed(const Duration(seconds: 3)),
      ]);
    } catch (e) {
      debugPrint('❌ Splash Screen Auth Check Error: $e');
    }

    if (!mounted) return;

    debugPrint(
      '🚀 Auth status: ${authProvider.status}, Driver: ${authProvider.driver?.fullName}',
    );

    if (authProvider.status == AuthStatus.authenticated &&
        authProvider.driver != null) {
      debugPrint('💾 Session valid — navigating to Home');
      Navigator.pushReplacement(context, SmoothNavigation.route(const Home()));
    } else {
      debugPrint('👋 No active session — navigating to Login');
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

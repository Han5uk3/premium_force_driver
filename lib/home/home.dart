import 'package:flutter/material.dart';
import 'package:premium_force_driver/account/account.dart';
import 'package:premium_force_driver/trips/trips_page.dart';
import 'package:premium_force_driver/common_widgets/bottomnavbar.dart';
import 'package:premium_force_driver/home/dashboard_page.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  int _selectedIndex = 0;

  /// Which trips tab to open — 0 active, 1 completed. Set by the dashboard's
  /// summary cards so tapping a count lands on the matching list.
  int _tripsTabIndex = 0;

  /// The shell currently on screen.
  ///
  /// Held statically so a route pushed *on top* of it can select a tab —
  /// [showTrips]. `findAncestorStateOfType` cannot reach here from a pushed
  /// route: those live under the [Navigator], which is above this widget, not
  /// beneath it. The dashboard can still use the ancestor lookup because it is
  /// genuinely inside this subtree.
  static HomeState? _current;

  @override
  void initState() {
    super.initState();
    _current = this;
  }

  @override
  void dispose() {
    // Guarded, so a Home replaced by a newer one does not clear its successor.
    if (identical(_current, this)) _current = null;
    super.dispose();
  }

  /// Select the trips tab from anywhere, including a pushed route.
  static void showTrips({int tabIndex = 0}) =>
      _current?.navigateToBookings(tabIndex);

  void _onNavBarItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void navigateToBookings(int tabIndex) {
    setState(() {
      _selectedIndex = 1;
      _tripsTabIndex = tabIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyWidget;
    switch (_selectedIndex) {
      case 0:
        bodyWidget = const DashboardPage();
        break;
      case 1:
        bodyWidget = TripsPage(initialIndex: _tripsTabIndex);
        break;
      case 2:
        bodyWidget = const AccountPage();
        break;
      default:
        bodyWidget = const DashboardPage();
    }

    // System back on the trips or account tab returns to the dashboard rather
    // than leaving the app — the dashboard is the shell's home, and the two
    // other tabs are places you go from it. Only on the dashboard itself does
    // back mean back.
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !mounted) return;
        setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        // The nav bar is a floating, translucent pill with a blur behind it,
        // so the body has to run underneath it for there to be anything to
        // blur. Without this the Scaffold reserves the bar's height and the
        // content stops above it, leaving the bar sitting on a flat strip —
        // which is what made this shell look different from the customer app's.
        //
        // Pages that scroll owe the bar bottom clearance of their own, or their
        // last row ends up permanently beneath it.
        extendBody: true,
        body: bodyWidget,
        bottomNavigationBar: BottomNavBar(
          selectedIndex: _selectedIndex,
          onIndexChanged: _onNavBarItemTapped,
        ),
        backgroundColor: const Color(0xFF1F1F1F),
      ),
    );
  }
}

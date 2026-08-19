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

    return Scaffold(
      body: bodyWidget,
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onIndexChanged: _onNavBarItemTapped,
      ),
      backgroundColor: const Color(0xFF1F1F1F),
    );
  }
}

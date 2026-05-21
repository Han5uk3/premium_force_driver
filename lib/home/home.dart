import 'package:flutter/material.dart';
import 'package:premium_force_driver/account/account.dart';
import 'package:premium_force_driver/bookings/bookings_page.dart';
import 'package:premium_force_driver/common_widgets/bottomnavbar.dart';
import 'package:premium_force_driver/home/dashboard_page.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  int _selectedIndex = 0;
  int _bookingsTabIndex = 0;

  void _onNavBarItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void navigateToBookings(int tabIndex) {
    setState(() {
      _selectedIndex = 1;
      _bookingsTabIndex = tabIndex;
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
        bodyWidget = BookingsPage(initialIndex: _bookingsTabIndex);
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

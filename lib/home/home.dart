import 'package:flutter/material.dart';
import 'package:premium_force_driver/account/account.dart';
import 'package:premium_force_driver/bookings/bookings_page.dart';
import 'package:premium_force_driver/common_widgets/bottomnavbar.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [BookingsPage(), AccountPage()];

  void _onNavBarItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onIndexChanged: _onNavBarItemTapped,
      ),
      backgroundColor: const Color(0xFF1F1F1F),
    );
  }
}

import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'customer_home_screen.dart';
import 'gaam_haul_home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  final GlobalKey<NavigatorState> _rideNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _haulNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  Route<dynamic> _buildTabRoute(Widget screen) =>
      MaterialPageRoute<dynamic>(builder: (_) => screen);

  Widget _buildTabNavigator(
    GlobalKey<NavigatorState> key,
    Widget rootScreen,
  ) {
    return Navigator(
      key: key,
      onGenerateRoute: (_) => _buildTabRoute(rootScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildTabNavigator(_rideNavKey, const CustomerHomeScreen()),
          _buildTabNavigator(_haulNavKey, const GaamHaulHomeScreen()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: _currentIndex == 0
              ? AppColors.primary
              : AppColors.haul,
          unselectedItemColor: AppColors.textSecondary,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_bike_outlined),
              activeIcon: Icon(Icons.directions_bike),
              label: 'GaamRide',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_outlined),
              activeIcon: Icon(Icons.local_shipping),
              label: 'GaamHaul',
            ),
          ],
        ),
      ),
    );
  }
}

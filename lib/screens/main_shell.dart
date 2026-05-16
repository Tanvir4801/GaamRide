import 'package:flutter/material.dart';

import 'customer_home_screen.dart';
import 'gaam_haul_home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final GlobalKey<NavigatorState> _gaamRideNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _gaamHaulNavigatorKey = GlobalKey<NavigatorState>();

  Route<dynamic> _buildTabRoute(Widget screen) {
    return MaterialPageRoute<dynamic>(builder: (_) => screen);
  }

  Widget _buildTabNavigator(GlobalKey<NavigatorState> navigatorKey, Widget rootScreen) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => _buildTabRoute(rootScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = _currentIndex == 0
        ? const Color(0xFF2E7D32)
        : const Color(0xFFE65100);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildTabNavigator(_gaamRideNavigatorKey, const CustomerHomeScreen()),
          _buildTabNavigator(_gaamHaulNavigatorKey, const GaamHaulHomeScreen()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: selectedColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bike),
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
    );
  }
}

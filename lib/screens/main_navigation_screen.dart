import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/route_guard.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'announcements_screen.dart';
import 'daily_progress_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final FirestoreService _fs = FirestoreService();
  bool _isIntern = false;
  bool _isLoading = true;

  List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = await LocalStorage.getUser();
      final employee = await _fs.getEmployee(user["uid"]);
      if (mounted) {
        setState(() {
          _isIntern = employee?.isIntern ?? false;
          _buildScreens();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _buildScreens();
        });
      }
    }
  }

  void _buildScreens() {
    if (_isIntern) {
      _screens = [
        const DashboardScreen(),
        const AnnouncementsScreen(),
        const DailyProgressScreen(),
        const ProfileScreen(),
      ];
    } else {
      _screens = [
    const DashboardScreen(),
    const AnnouncementsScreen(),
    const ProfileScreen(),
  ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return RouteGuard(
      requireAdmin: false,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Colors.grey.shade600,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 12,
            ),
            iconSize: 24,
            items: _isIntern
                ? [
                    BottomNavigationBarItem(
                      icon: Icon(
                        _currentIndex == 0
                            ? Icons.dashboard
                            : Icons.dashboard_outlined,
                      ),
                      label: 'Dashboard',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(
                        _currentIndex == 1
                            ? Icons.campaign
                            : Icons.campaign_outlined,
                      ),
                      label: 'Announcements',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(
                        _currentIndex == 2
                            ? Icons.school
                            : Icons.school_outlined,
                      ),
                      label: 'Progress',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(
                        _currentIndex == 3
                            ? Icons.person
                            : Icons.person_outline,
                      ),
                      label: 'Profile',
                    ),
                  ]
                : [
              BottomNavigationBarItem(
                icon: Icon(
                  _currentIndex == 0
                      ? Icons.dashboard
                      : Icons.dashboard_outlined,
                ),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                        _currentIndex == 1
                            ? Icons.campaign
                            : Icons.campaign_outlined,
                ),
                label: 'Announcements',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                        _currentIndex == 2
                            ? Icons.person
                            : Icons.person_outline,
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

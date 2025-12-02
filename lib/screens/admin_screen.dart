import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';
import '../controllers/auth_controller.dart';
import '../models/employee.dart';
import '../utils/app_colors.dart';
import '../utils/announcement_constants.dart';
import '../widgets/route_guard.dart';
import '../services/pdf_service.dart';
import 'create_announcement_dialog.dart';
import 'employee_details_screen.dart';

enum DocumentPreviewType { image, pdf, other }

const Set<String> _imageExtensions = {
  "png",
  "jpg",
  "jpeg",
  "gif",
  "bmp",
  "webp",
};

const Set<String> _documentExtensions = {"pdf"};

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin {
  final fs = FirestoreService();
  final pdfService = PdfService();
  DateTime selectedMonth = DateTime.now();
  String viewMode = "today"; // "today", "month", "all"
  int _currentIndex =
      0; // 0: Dashboard, 1: Announcements, 2: Leave Applications
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  List<Employee> _allEmployees = [];
  Map<String, Employee> _employeeLookup = {};

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeController.forward();
    _slideController.forward();
    _refreshEmployeeCache();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> pickMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      helpText: "Select Month",
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() => selectedMonth = picked);
    }
  }

  /// Get employees list excluding the current admin user
  Future<List<Employee>> _getFilteredEmployees() async {
    try {
      final allEmployees = await fs.getAllEmployees();
      final currentUser = await LocalStorage.getUser();
      final currentUserId = currentUser["uid"] as String?;

      if (currentUserId == null || currentUserId.isEmpty) {
        return allEmployees;
      }

      // Filter out the current admin user
      return allEmployees
          .where((employee) => employee.id != currentUserId)
          .toList();
    } catch (e) {
      // If there's an error, return all employees
      return await fs.getAllEmployees();
    }
  }

  Future<void> _refreshEmployeeCache() async {
    try {
      final employees = await fs.getAllEmployees();
      if (!mounted) return;
      setState(() {
        _allEmployees = employees;
        _employeeLookup = {
          for (var employee in employees) employee.id: employee,
        };
      });
    } catch (e) {
      print('Failed to load employees for announcements: $e');
    }
  }

  Duration _calculateWorkedHours(List<Map<String, dynamic>> records) {
    if (records.isEmpty) return Duration.zero;

    // Sort by timestamp
    records.sort((a, b) {
      final timeA = a["timestamp"]?.toDate() ?? DateTime(1970);
      final timeB = b["timestamp"]?.toDate() ?? DateTime(1970);
      return timeA.compareTo(timeB);
    });

    Duration totalDuration = Duration.zero;
    DateTime? checkInTime;

    for (var record in records) {
      final timestamp = record["timestamp"];
      if (timestamp == null) continue;

      DateTime? time;
      if (timestamp is DateTime) {
        time = timestamp;
      } else {
        time = timestamp.toDate();
      }

      if (time == null) continue;

      final type = record["type"] as String?;
      if (type == null) continue;

      if (type == "check_in") {
        if (checkInTime != null) {
          final duration = time.difference(checkInTime);
          if (!duration.isNegative) {
            totalDuration += duration;
          }
        }
        checkInTime = time;
      } else if (type == "check_out") {
        if (checkInTime != null) {
          final duration = time.difference(checkInTime);
          if (!duration.isNegative) {
            totalDuration += duration;
          }
          checkInTime = null;
        }
      }
    }

    if (checkInTime != null) {
      final now = DateTime.now();
      final duration = now.difference(checkInTime);
      if (!duration.isNegative) {
        totalDuration += duration;
      }
    }

    return totalDuration;
  }

  @override
  Widget build(BuildContext context) {
    return RouteGuard(
      requireAdmin: true,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                if (_currentIndex == 0) _buildModernAppBar(),
                if (_currentIndex == 1) _buildAnnouncementsHeader(),
                if (_currentIndex == 2) _buildLeaveApplicationsHeader(),
                Expanded(child: _buildCurrentView()),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
        floatingActionButton: _currentIndex == 1
            ? FloatingActionButton.extended(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => CreateAnnouncementDialog(
                      onSaved: _refreshEmployeeCache,
                    ),
                  );
                },
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Create Announcement",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return _buildAnnouncementsView();
      case 2:
        return _buildLeaveApplicationsView();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildStatisticsCards(),
            const SizedBox(height: 24),
            _buildViewModeSelector(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.people, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    "Employees",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildEmployeeStatsList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40), // Spacer for centering
          Expanded(
            child: Text(
              "Admin Dashboard",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to logout?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.find<AuthController>().logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.logout, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return FutureBuilder<List<Employee>>(
      future: _getFilteredEmployees(),
      builder: (context, snapshot) {
        final employeeCount = snapshot.hasData ? snapshot.data!.length : 0;

        return SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.people,
                    label: "Total Employees",
                    value: "$employeeCount",
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.access_time,
                    label: "View Mode",
                    value: viewMode == "today" ? "Today" : "Monthly",
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.shade400, color.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildModeButton("Today", "today", Icons.today)),
          const SizedBox(width: 12),
          Expanded(
            child: _buildModeButton("Month", "month", Icons.calendar_month),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildModeButton("All Time", "all", Icons.history)),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, String mode, IconData icon) {
    final isSelected = viewMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => viewMode = mode);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeStatsList() {
    return FutureBuilder<List<Employee>>(
      future: _getFilteredEmployees(),
      builder: (context, employeesSnapshot) {
        if (!employeesSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final employees = employeesSnapshot.data!;

        if (employees.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "No employees found",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: employees.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (index * 100)),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: _buildEmployeeCard(employees[index], index),
            );
          },
        );
      },
    );
  }

  Widget _buildEmployeeCard(Employee employee, int index) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(
        '${employee.id}_${viewMode}_${selectedMonth.millisecondsSinceEpoch}',
      ),
      future: _getEmployeeRecords(employee.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          print(
            'Error loading records for ${employee.name}: ${snapshot.error}',
          );
        }

        Duration totalDuration = Duration.zero;
        if (snapshot.hasData) {
          final records = snapshot.data!;
          if (viewMode == "all") {
            print(
              'All Time: Received ${records.length} records for ${employee.name}',
            );
          }
          totalDuration = _calculateWorkedHours(records);
        }

        final hours = totalDuration.inHours;
        final minutes = totalDuration.inMinutes % 60;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeeDetailsScreen(
                    employee: employee,
                    viewMode: viewMode,
                    selectedMonth: viewMode == "month" ? selectedMonth : null,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child:
                            employee.profileImage != null &&
                                employee.profileImage!.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: employee.profileImage!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppColors.primaryLight,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    employee.email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.backgroundLight,
                          AppColors.backgroundMedium,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_filled,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    viewMode == "today"
                                        ? "Today's Hours"
                                        : viewMode == "month"
                                        ? "This Month"
                                        : "Total Hours",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "$hours",
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      height: 1,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 6,
                                      left: 4,
                                    ),
                                    child: Text(
                                      "h",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "$minutes",
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      height: 1,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 6,
                                      left: 4,
                                    ),
                                    child: Text(
                                      "m",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () async {
                                  try {
                                    final records = await _getEmployeeRecords(employee.id);
                                    await pdfService.generateAttendanceStatement(
                                      employee: employee,
                                      records: records,
                                      viewMode: viewMode,
                                      selectedMonth: viewMode == "month" ? selectedMonth : null,
                                    );
                                  } catch (e) {
                                    Get.snackbar(
                                      "Error",
                                      "Failed to generate PDF: ${e.toString()}",
                                    );
                                  }
                                },
                                icon: Icon(
                                  Icons.download,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                tooltip: "Download Attendance Statement",
                              ),
                            ),
                            if (viewMode == "month") ...[
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: pickMonth,
                                  icon: Icon(
                                    Icons.calendar_today,
                                    color: Colors.orange.shade700,
                                    size: 20,
                                  ),
                                  tooltip: "Select Month",
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getEmployeeRecords(
    String employeeId,
  ) async {
    if (viewMode == "all") {
      print(
        '_getEmployeeRecords: Fetching All Time records for employeeId="$employeeId"',
      );
    }

    if (viewMode == "today") {
      final records = await fs.getTodayEmployeeAttendance();
      return records.where((r) => r["employeeId"] == employeeId).toList();
    } else if (viewMode == "month") {
      return await fs.getEmployeeAttendanceForMonth(employeeId, selectedMonth);
    } else {
      return await fs.getAllEmployeeAttendance(employeeId);
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
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
        selectedFontSize: 12,
        unselectedFontSize: 12,
        iconSize: 24,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign),
            label: "Announcements",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_busy),
            label: "Leave Applications",
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          "Announcements",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveApplicationsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: const Text(
          "Leave Applications",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementsView() {
    return StreamBuilder(
      stream: fs.getAnnouncements(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.orange.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Loading announcements...",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "No announcements yet",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAnnouncementsSummary(docs),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 300 + (index * 100)),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildAnnouncementCard(docs[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementsSummary(List<dynamic> docs) {
    final totalAnnouncements = docs.length;
    final totalEmployees = _allEmployees.length;
    final totalSeenEntries = docs.fold<int>(0, (total, doc) {
      final seen = (doc.data()["seenBy"] as List<dynamic>?) ?? [];
      return total + seen.length;
    });
    final coverage = (totalAnnouncements == 0 || totalEmployees == 0)
        ? 0
        : ((totalSeenEntries / (totalAnnouncements * totalEmployees)) * 100)
              .clamp(0, 100);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundMedium,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(5),
              margin: EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: const Text(
                      textAlign: TextAlign.center,
                      "Total",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      textAlign: TextAlign.center,
                      "Announcements",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      textAlign: TextAlign.center,

                      "$totalAnnouncements",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundMedium,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(5),
              margin: EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: const Text(
                      textAlign: TextAlign.center,
                      "Total",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      textAlign: TextAlign.center,
                      "Employees",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      textAlign: TextAlign.center,
                      "$totalEmployees",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundMedium,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(5),
              margin: EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: const Text(
                      textAlign: TextAlign.center,
                      "Read",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      textAlign: TextAlign.center,
                      "coverage",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      "${coverage.toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    final docId = doc.id;
    final title = data["title"] as String? ?? "Announcement";
    final text = data["text"] as String? ?? "";
    final imageUrl = data["imageUrl"] as String? ?? "";
    final pdfUrl = data["pdfUrl"] as String? ?? "";
    final category = data["category"] as String? ?? "General";
    final targetType = data["targetType"] as String? ?? announcementTargetAll;
    final targetDepartment = data["targetDepartment"] as String? ?? "";
    final targetEmployeeIds =
        (data["targetEmployeeIds"] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final seenBy =
        (data["seenBy"] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [];
    final timestamp = data["createdAt"];

    DateTime? date;
    if (timestamp != null) {
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = timestamp.toDate();
      }
    }

    final targetLabel = announcementTargetLabels[targetType] ?? "All Employees";
    final targetDetail = formatTargetAudience(
      targetType,
      targetType == announcementTargetDepartment
          ? targetDepartment
          : targetType == announcementTargetEmployees
          ? targetEmployeeIds.length.toString()
          : null,
      targetEmployeeIds.length,
    );
    final totalEmployees = _allEmployees.isNotEmpty
        ? _allEmployees.length
        : seenBy.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (date != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 8),
            Text(
              DateFormat('EEEE, MMMM d, y • h:mm a').format(date),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(
                label: Text(category),
                backgroundColor: AppColors.primary.withOpacity(0.12),
                labelStyle: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Chip(
                label: Text(targetLabel),
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            targetDetail,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                height: 190,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade200,
                  height: 190,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 190,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.error_outline),
                ),
              ),
            ),
          ],
          if (pdfUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _launchDocumentUrl(pdfUrl),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Open PDF",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Seen by: ${seenBy.length}/${totalEmployees > 0 ? totalEmployees : seenBy.length}",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _showAnnouncementAnalytics(title, seenBy),
                    child: const Text("View analytics"),
                  ),
                  IconButton(
                    onPressed: () => _openAnnouncementDialog(
                      announcementId: docId,
                      initialData: data,
                    ),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    onPressed: () => _confirmDeleteAnnouncement(docId, title),
                    icon: const Icon(Icons.delete, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openAnnouncementDialog({
    String? announcementId,
    Map<String, dynamic>? initialData,
  }) {
    showDialog(
      context: context,
      builder: (context) => CreateAnnouncementDialog(
        announcementId: announcementId,
        initialData: initialData,
        onSaved: _refreshEmployeeCache,
      ),
    );
  }

  void _showAnnouncementAnalytics(String title, List<String> seenBy) {
    final seenIds = seenBy;
    final unseenIds = _allEmployees
        .where((employee) => !seenBy.contains(employee.id))
        .map((employee) => employee.id)
        .toList();
    final totalEmployees = _allEmployees.length;
    final seenCount = seenIds.length;
    final coverage = totalEmployees == 0 ? 0.0 : seenCount / totalEmployees;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Announcement Analytics",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildAnalyticsStat(
                    "Seen",
                    "$seenCount",
                    AppColors.backgroundLight,
                    Colors.green,
                  ),
                  const SizedBox(width: 10),
                  _buildAnalyticsStat(
                    "Pending",
                    "${totalEmployees - seenCount}",
                    AppColors.backgroundLight,
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: coverage.clamp(0, 1),
                backgroundColor: Colors.grey.shade200,
                color: Colors.green.shade600,
                minHeight: 6,
              ),
              const SizedBox(height: 8),
              Text(
                "${(coverage * 100).clamp(0, 100).toStringAsFixed(0)}% coverage",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 20),
              if (seenIds.isNotEmpty)
                _buildAnalyticsList(
                  "Seen by (${seenIds.length})",
                  seenIds,
                  Colors.green.shade50,
                ),
              if (unseenIds.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAnalyticsList(
                  "Pending (${unseenIds.length})",
                  unseenIds,
                  Colors.orange.shade50,
                ),
              ],
              if (seenIds.isEmpty && unseenIds.isEmpty)
                Center(
                  child: Text(
                    "No employees available for this announcement yet.",
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsStat(
    String label,
    String value,
    Color background,
    Color accent,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsList(
    String label,
    List<String> userIds,
    Color background,
  ) {
    final listHeight = math.min(userIds.length * 48.0, 200.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            height: listHeight,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: userIds.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.grey.shade300, height: 10),
              itemBuilder: (context, index) {
                final id = userIds[index];
                final entry = _employeeLookup[id];
                final name = entry?.name ?? "Employee";
                final initials = name
                    .trim()
                    .split(" ")
                    .where((part) => part.isNotEmpty)
                    .map((part) => part[0])
                    .take(2)
                    .join()
                    .toUpperCase();
                final profileImage = entry?.profileImage;
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      backgroundImage: profileImage?.isNotEmpty == true
                          ? NetworkImage(profileImage!)
                          : null,
                      child: profileImage?.isNotEmpty == true
                          ? null
                          : Text(
                              initials,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteAnnouncement(String id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete announcement"),
        content: Text(
          "Delete \"$title\" permanently?",
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await fs.deleteAnnouncement(id);
                Get.snackbar("Deleted", "Announcement removed");
              } catch (e) {
                Get.snackbar("Error", "Failed to delete announcement");
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveApplicationsView() {
    return StreamBuilder(
      stream: fs.getLeaveApplications(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "No leave applications",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _buildLeaveApplicationCard(docs[index]);
          },
        );
      },
    );
  }

  Widget _buildLeaveApplicationCard(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    final employeeName = data["employeeName"] as String? ?? "Unknown";
    final employeeEmail = data["employeeEmail"] as String? ?? "";
    final reason = data["reason"] as String? ?? "";
    final imageUrl = data["imageUrl"] as String? ?? "";
    final status = data["status"] as String? ?? "pending";
    final startDate = data["startDate"]?.toDate();
    final endDate = data["endDate"]?.toDate();
    final createdAt = data["createdAt"]?.toDate();
    final leaveType = data["leaveType"] as String? ?? "Leave";
    final leaveSubType = data["leaveSubType"] as String? ?? "General";
    final documentUrl = data["documentUrl"] as String?;
    final documentName =
        data["documentName"] as String? ?? "Supporting document";
    final documentUrlValue = documentUrl ?? "";
    final hasDocument = documentUrlValue.isNotEmpty;
    final documentPreviewType = hasDocument
        ? _documentPreviewTypeFromUrl(documentUrlValue)
        : DocumentPreviewType.other;

    final hasImage = imageUrl.isNotEmpty;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case "approved":
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = "Approved";
        break;
      case "rejected":
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = "Rejected";
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = "Pending";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (employeeEmail.isNotEmpty)
                      Text(
                        employeeEmail,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadge(
                leaveType,
                Icons.health_and_safety,
                AppColors.primary,
              ),
              _buildBadge(leaveSubType, Icons.category, Colors.grey.shade600),
            ],
          ),
          const SizedBox(height: 16),

          // Date Range
          if (startDate != null && endDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)}",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Reason
          Text(
            "Reason:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          if (hasDocument) ...[
            const SizedBox(height: 16),
            _buildDocumentPreview(
              documentUrlValue,
              documentName,
              documentPreviewType,
            ),
          ],

          // Image
          if (hasImage) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.orange.shade600,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.error_outline),
                ),
              ),
            ),
          ],

          if (createdAt != null) ...[
            const SizedBox(height: 16),
            Text(
              "Applied on: ${DateFormat('MMM d, y • h:mm a').format(createdAt)}",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],

          // Action Buttons (only for pending)
          if (status == "pending") ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      fs.updateLeaveApplicationStatus(doc.id, "approved");
                      Get.snackbar("Success", "Leave application approved");
                    },
                    icon: const Icon(Icons.check),
                    label: const Text("Approve"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      fs.updateLeaveApplicationStatus(doc.id, "rejected");
                      Get.snackbar("Success", "Leave application rejected");
                    },
                    icon: const Icon(Icons.close),
                    label: const Text("Reject"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview(
    String url,
    String name,
    DocumentPreviewType type,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _launchDocumentUrl(url),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: type == DocumentPreviewType.image
                  ? CachedNetworkImage(
                      imageUrl: url,
                      height: 160,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.error_outline)),
                      ),
                    )
                  : Container(
                      height: 160,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Icon(
                          type == DocumentPreviewType.pdf
                              ? Icons.picture_as_pdf
                              : Icons.insert_drive_file,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.open_in_full, color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DocumentPreviewType _documentPreviewTypeFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return DocumentPreviewType.other;
    final lastSegment = uri.path.split('/').last;
    final dotIndex = lastSegment.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == lastSegment.length - 1) {
      return DocumentPreviewType.other;
    }
    final ext = lastSegment.substring(dotIndex + 1).toLowerCase();
    if (_imageExtensions.contains(ext)) return DocumentPreviewType.image;
    if (_documentExtensions.contains(ext)) return DocumentPreviewType.pdf;
    return DocumentPreviewType.other;
  }

  Future<void> _launchDocumentUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar(
        "Cannot open document",
        "Please check your network or try again later.",
      );
    }
  }
}

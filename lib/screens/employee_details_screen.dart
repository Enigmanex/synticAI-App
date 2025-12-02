import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../utils/app_colors.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final Employee employee;
  final String viewMode; // "today", "month", "all"
  final DateTime? selectedMonth;

  const EmployeeDetailsScreen({
    super.key,
    required this.employee,
    this.viewMode = "today",
    this.selectedMonth,
  });

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen>
    with TickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  final PdfService _pdfService = PdfService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _getEmployeeRecords() async {
    if (widget.viewMode == "today") {
      final records = await _fs.getTodayEmployeeAttendance();
      return records
          .where((r) => r["employeeId"] == widget.employee.id)
          .toList();
    } else if (widget.viewMode == "month" && widget.selectedMonth != null) {
      return await _fs.getEmployeeAttendanceForMonth(
        widget.employee.id,
        widget.selectedMonth!,
      );
    } else {
      return await _fs.getAllEmployeeAttendance(widget.employee.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildEmployeeRecordsList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employee.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  widget.employee.email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              try {
                final records = await _getEmployeeRecords();
                await _pdfService.generateAttendanceStatement(
                  employee: widget.employee,
                  records: records,
                  viewMode: widget.viewMode,
                  selectedMonth: widget.selectedMonth,
                );
              } catch (e) {
                Get.snackbar(
                  "Error",
                  "Failed to generate PDF: ${e.toString()}",
                );
              }
            },
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: "Download Attendance Statement",
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeRecordsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getEmployeeRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  "Error loading records",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final records = snapshot.data ?? [];

        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "No attendance records",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        // Sort records by timestamp
        records.sort((a, b) {
          final timeA = a["timestamp"]?.toDate() ?? DateTime(1970);
          final timeB = b["timestamp"]?.toDate() ?? DateTime(1970);
          return timeB.compareTo(timeA); // Newest first
        });

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: records.length,
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
              child: _buildRecordCard(records[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final timestamp = record["timestamp"];
    final address = record["address"] as String? ?? "";
    final type = record["type"] as String? ?? "";

    DateTime? time;
    if (timestamp is DateTime) {
      time = timestamp;
    } else if (timestamp != null) {
      time = timestamp.toDate();
    }

    if (time == null) {
      return const SizedBox.shrink();
    }

    final isCheckIn = type == "check_in";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCheckIn
              ? AppColors.backgroundLight
              : Colors.black.withOpacity(0.2),
          width: 2,
        ),
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
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: isCheckIn
                      ? AppColors.primaryGradient
                      : LinearGradient(colors: [Colors.black87, Colors.black]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCheckIn ? Icons.login : Icons.logout,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCheckIn ? "Check In" : "Check Out",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, y • h:mm a').format(time),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
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
                  color: isCheckIn
                      ? AppColors.backgroundLight
                      : Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCheckIn ? "IN" : "OUT",
                  style: TextStyle(
                    color: isCheckIn ? AppColors.primary : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

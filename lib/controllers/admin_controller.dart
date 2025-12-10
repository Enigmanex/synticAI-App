import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';
import '../services/pdf_service.dart';
import '../models/employee.dart';

class AdminController extends GetxController {
  final fs = FirestoreService();
  final pdfService = PdfService();

  // State variables
  final selectedMonth = DateTime.now().obs;
  final viewMode = "today".obs; // "today", "month", "all" - for attendance
  final internProgressViewMode =
      "today".obs; // "today", "month", "all" - for intern progress
  final currentIndex = 0
      .obs; // 0: Dashboard, 1: Announcements, 2: Leave Applications, 3: Intern Progress
  final allEmployees = <Employee>[].obs;
  final employeeLookup = <String, Employee>{}.obs;

  @override
  void onInit() {
    super.onInit();
    refreshEmployeeCache();
  }

  Future<void> pickMonth() async {
    final DateTime? picked = await showDatePicker(
      context: Get.context!,
      initialDate: selectedMonth.value,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      helpText: "Select Month",
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      selectedMonth.value = picked;
    }
  }

  Future<List<Employee>> getFilteredEmployees() async {
    try {
      final allEmployees = await fs.getAllEmployees();
      final currentUser = await LocalStorage.getUser();
      final currentUserId = currentUser["uid"] as String?;

      List<Employee> filteredEmployees;
      if (currentUserId == null || currentUserId.isEmpty) {
        filteredEmployees = allEmployees;
      } else {
        filteredEmployees = allEmployees
            .where((employee) => employee.id != currentUserId)
            .toList();
      }

      // Sort employees alphabetically by name (A to Z)
      filteredEmployees.sort((a, b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return filteredEmployees;
    } catch (e) {
      final employees = await fs.getAllEmployees();
      // Sort even in error case
      employees.sort((a, b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return employees;
    }
  }

  Future<void> refreshEmployeeCache() async {
    try {
      final employees = await fs.getAllEmployees();
      allEmployees.value = employees;
      employeeLookup.value = {
        for (var employee in employees) employee.id: employee,
      };
    } catch (e) {
      print('Failed to load employees: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getEmployeeRecords(
    String employeeId,
  ) async {
    if (viewMode.value == "today") {
      final records = await fs.getTodayEmployeeAttendance();
      // Filter by employeeId with proper type handling
      return records.where((r) {
        final recordEmployeeId = r["employeeId"];
        String recordEmployeeIdStr;
        if (recordEmployeeId == null) {
          return false;
        } else if (recordEmployeeId is String) {
          recordEmployeeIdStr = recordEmployeeId.trim();
        } else {
          recordEmployeeIdStr = recordEmployeeId.toString().trim();
        }
        return recordEmployeeIdStr == employeeId.trim();
      }).toList();
    } else if (viewMode.value == "month") {
      return await fs.getEmployeeAttendanceForMonth(
        employeeId,
        selectedMonth.value,
      );
    } else {
      return await fs.getAllEmployeeAttendance(employeeId);
    }
  }

  Duration calculateWorkedHours(List<Map<String, dynamic>> records) {
    if (records.isEmpty) return Duration.zero;

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

  void changeViewMode(String mode) {
    viewMode.value = mode;
  }

  void changeInternProgressViewMode(String mode) {
    internProgressViewMode.value = mode;
  }

  void changeTab(int index) {
    currentIndex.value = index;
  }
}

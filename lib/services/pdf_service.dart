import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import '../models/employee.dart';

class PdfService {
  /// Generate and save/download attendance statement PDF
  Future<void> generateAttendanceStatement({
    required Employee employee,
    required List<Map<String, dynamic>> records,
    required String viewMode,
    DateTime? selectedMonth,
  }) async {
    final pdf = await _createAttendancePdf(
      employee: employee,
      records: records,
      viewMode: viewMode,
      selectedMonth: selectedMonth,
    );

    // Save PDF bytes
    final pdfBytes = await pdf.save();

    // Save to device storage
    try {
      final filePath = await _savePdfToStorage(
        pdfBytes: pdfBytes,
        employee: employee,
        viewMode: viewMode,
        selectedMonth: selectedMonth,
      );

      Get.snackbar(
        "Success",
        "PDF saved to: $filePath",
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        "Warning",
        "PDF generated but could not save to storage: ${e.toString()}",
        duration: const Duration(seconds: 3),
      );
    }

    // Also open preview/share dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  /// Save PDF to device storage
  Future<String> _savePdfToStorage({
    required List<int> pdfBytes,
    required Employee employee,
    required String viewMode,
    DateTime? selectedMonth,
  }) async {
    // Get the appropriate directory
    Directory directory;

    try {
      if (Platform.isAndroid) {
        // For Android, try multiple locations
        // First try Downloads folder (works on most devices)
        final downloadsPath = '/storage/emulated/0/Download';
        final downloadsDir = Directory(downloadsPath);

        if (await downloadsDir.exists()) {
          directory = downloadsDir;
        } else {
          // Try alternative Downloads path
          final altDownloadsPath = '/sdcard/Download';
          final altDownloadsDir = Directory(altDownloadsPath);
          if (await altDownloadsDir.exists()) {
            directory = altDownloadsDir;
          } else {
            // Fallback to app documents directory
            directory = await getApplicationDocumentsDirectory();
          }
        }
      } else if (Platform.isIOS) {
        // For iOS, use app documents directory
        directory = await getApplicationDocumentsDirectory();
      } else {
        // For other platforms, use app documents directory
        directory = await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      // Fallback to app documents directory
      directory = await getApplicationDocumentsDirectory();
    }

    // Generate filename
    String filename;
    if (viewMode == "today") {
      filename =
          'Attendance_${employee.name.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
    } else if (viewMode == "month" && selectedMonth != null) {
      filename =
          'Attendance_${employee.name.replaceAll(' ', '_')}_${DateFormat('yyyy-MM').format(selectedMonth)}.pdf';
    } else {
      filename = 'Attendance_${employee.name.replaceAll(' ', '_')}_AllTime.pdf';
    }

    // Remove special characters from filename
    filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(pdfBytes);

    // Return user-friendly path
    if (Platform.isAndroid && directory.path.contains('Download')) {
      return 'Downloads/$filename';
    } else if (Platform.isIOS) {
      return 'Documents/$filename';
    } else {
      return file.path;
    }
  }

  /// Create the PDF document
  Future<pw.Document> _createAttendancePdf({
    required Employee employee,
    required List<Map<String, dynamic>> records,
    required String viewMode,
    DateTime? selectedMonth,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // Group records by date and calculate daily hours
    final dailyData = _groupRecordsByDate(records);

    // Generate title based on view mode
    String periodTitle;
    if (viewMode == "today") {
      periodTitle = "Today's Attendance Statement";
    } else if (viewMode == "month" && selectedMonth != null) {
      periodTitle =
          "Attendance Statement - ${DateFormat('MMMM yyyy').format(selectedMonth)}";
    } else {
      periodTitle = "Complete Attendance Statement";
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(employee, periodTitle, now),
            pw.SizedBox(height: 20),

            // Summary
            _buildSummary(dailyData),
            pw.SizedBox(height: 20),

            // Daily Records Table
            _buildDailyRecordsTable(dailyData),
          ];
        },
      ),
    );

    return pdf;
  }

  /// Build PDF header
  pw.Widget _buildHeader(
    Employee employee,
    String title,
    DateTime generatedDate,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated on: ${DateFormat('MMMM d, yyyy • h:mm a').format(generatedDate)}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Employee Information',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Name: ${employee.name}'),
              pw.Text('Email: ${employee.email}'),
              if (employee.department != null &&
                  employee.department!.isNotEmpty)
                pw.Text('Department: ${employee.department}'),
            ],
          ),
        ),
      ],
    );
  }

  /// Build summary section
  pw.Widget _buildSummary(Map<String, DailyAttendanceData> dailyData) {
    int totalDays = dailyData.length;
    Duration totalHours = Duration.zero;

    for (var data in dailyData.values) {
      totalHours += data.totalHours;
    }

    final totalHoursInt = totalHours.inHours;
    final totalMinutesInt = totalHours.inMinutes % 60;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text(
                '$totalDays',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(
                'Days',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Container(width: 1, height: 40, color: PdfColors.blue200),
          pw.Column(
            children: [
              pw.Text(
                '$totalHoursInt h $totalMinutesInt m',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(
                'Total Hours',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build daily records table
  pw.Widget _buildDailyRecordsTable(
    Map<String, DailyAttendanceData> dailyData,
  ) {
    final sortedDates = dailyData.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('Date', isHeader: true),
            _buildTableCell('Check In', isHeader: true),
            _buildTableCell('Check Out', isHeader: true),
            _buildTableCell('Hours', isHeader: true),
          ],
        ),
        // Data rows
        ...sortedDates.map((date) {
          final data = dailyData[date]!;
          return pw.TableRow(
            children: [
              _buildTableCell(
                DateFormat('MMM d, yyyy').format(DateTime.parse(date)),
              ),
              _buildTableCell(
                data.checkInTime != null
                    ? DateFormat('h:mm a').format(data.checkInTime!)
                    : '-',
              ),
              _buildTableCell(
                data.checkOutTime != null
                    ? DateFormat('h:mm a').format(data.checkOutTime!)
                    : data.isCurrentlyCheckedIn
                    ? 'In Progress'
                    : '-',
              ),
              _buildTableCell(
                '${data.totalHours.inHours}h ${data.totalHours.inMinutes % 60}m',
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Build table cell
  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Group records by date and calculate daily hours
  Map<String, DailyAttendanceData> _groupRecordsByDate(
    List<Map<String, dynamic>> records,
  ) {
    final Map<String, DailyAttendanceData> dailyData = {};

    // Sort records by timestamp
    final sortedRecords = List<Map<String, dynamic>>.from(records)
      ..sort((a, b) {
        final timeA = _getDateTime(a["timestamp"]);
        final timeB = _getDateTime(b["timestamp"]);
        if (timeA == null || timeB == null) return 0;
        return timeA.compareTo(timeB);
      });

    // Process records day by day
    // Track current check-in per day
    final Map<String, DateTime?> currentCheckInByDay = {};

    for (var record in sortedRecords) {
      final timestamp = _getDateTime(record["timestamp"]);
      if (timestamp == null) continue;

      final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);
      final type = record["type"] as String?;

      if (type == null) continue;

      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = DailyAttendanceData();
      }

      final dayData = dailyData[dateKey]!;
      final currentCheckIn = currentCheckInByDay[dateKey];

      if (type == "check_in") {
        // If there's already a check-in without check-out, calculate hours
        if (currentCheckIn != null) {
          // Calculate hours from previous check-in to this check-in
          final duration = timestamp.difference(currentCheckIn);
          if (!duration.isNegative) {
            dayData.totalHours += duration;
          }
        }
        // Track first check-in of the day
        if (dayData.checkInTime == null) {
          dayData.checkInTime = timestamp;
        }
        currentCheckInByDay[dateKey] = timestamp;
        dayData.isCurrentlyCheckedIn = true;
      } else if (type == "check_out") {
        if (currentCheckIn != null) {
          final duration = timestamp.difference(currentCheckIn);
          if (!duration.isNegative) {
            dayData.totalHours += duration;
          }
        }
        // Track last check-out of the day
        dayData.checkOutTime = timestamp;
        dayData.isCurrentlyCheckedIn = false;
        currentCheckInByDay[dateKey] = null;
      }
    }

    // Handle currently checked-in employees (no check-out yet)
    for (var entry in currentCheckInByDay.entries) {
      final currentCheckIn = entry.value;
      if (currentCheckIn != null) {
        final dateKey = entry.key;
        if (dailyData.containsKey(dateKey)) {
          final dayData = dailyData[dateKey]!;
          final now = DateTime.now();
          final date = DateTime.parse(dateKey);
          // Only add if it's today
          if (date.day == now.day &&
              date.month == now.month &&
              date.year == now.year) {
            final duration = now.difference(currentCheckIn);
            if (!duration.isNegative) {
              dayData.totalHours += duration;
            }
          }
        }
      }
    }

    return dailyData;
  }

  /// Extract DateTime from timestamp (handles both DateTime and Firestore Timestamp)
  DateTime? _getDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is DateTime) return timestamp;
    try {
      return timestamp.toDate();
    } catch (e) {
      return null;
    }
  }
}

/// Data class for daily attendance information
class DailyAttendanceData {
  DateTime? checkInTime;
  DateTime? checkOutTime;
  Duration totalHours = Duration.zero;
  bool isCurrentlyCheckedIn = false;
}

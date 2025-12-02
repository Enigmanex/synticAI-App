import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<Employee?> getEmployee(String uid) async {
    final doc = await _db.collection("employees").doc(uid).get();
    if (!doc.exists) return null;
    return Employee.fromMap(uid, doc.data()!);
  }

  Future<void> createEmployee(String uid, String name, String email) async {
    await _db.collection("employees").doc(uid).set({
      "name": name,
      "email": email,
      "role": "employee",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  /// Ensures admin user exists in Firestore with admin role
  Future<void> ensureAdminUser(String uid, String email) async {
    final docRef = _db.collection("employees").doc(uid);
    final doc = await docRef.get();
    
    if (!doc.exists) {
      // Create admin user if doesn't exist
      await docRef.set({
        "name": "Admin",
        "email": email,
        "role": "admin",
        "createdAt": FieldValue.serverTimestamp(),
      });
    } else {
      // Update existing user to admin if not already
      final data = doc.data()!;
      if (data["role"] != "admin") {
        await docRef.update({
          "role": "admin",
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> recordAttendance(String uid, String type, String? address) async {
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());

    Map<String, dynamic> recordData = {
      "employeeId": uid,
      "type": type,
      "timestamp": FieldValue.serverTimestamp(),
    };

    if (address != null && address.isNotEmpty) {
      recordData["address"] = address;
    }

    await _db.collection("attendance").doc(date).collection("records").add(recordData);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> todayRecords() {
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _db
        .collection("attendance")
        .doc(date)
        .collection("records")
        .orderBy("timestamp")
        .snapshots();
  }

  Future<List<Employee>> getAllEmployees() async {
    final snap = await _db.collection("employees").get();
    return snap.docs.map((d) => Employee.fromMap(d.id, d.data())).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> recordsByDate(DateTime date) {
    String day = DateFormat('yyyy-MM-dd').format(date);
    return _db
        .collection("attendance")
        .doc(day)
        .collection("records")
        .orderBy("timestamp")
        .snapshots();
  }

  Future<void> updateProfile(String uid, String name, String? imageUrl) async {
    Map<String, dynamic> updateData = {
      "name": name,
      "updatedAt": FieldValue.serverTimestamp(),
    };
    
    if (imageUrl != null) {
      updateData["profileImage"] = imageUrl;
    }
    
    await _db.collection("employees").doc(uid).update(updateData);
  }

  // Announcements methods
  Stream<QuerySnapshot<Map<String, dynamic>>> getAnnouncements() {
    return _db
        .collection("announcements")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Future<void> createAnnouncement({
    required String title,
    required String text,
    String? imageUrl,
    String? pdfUrl,
    String? adminId,
    String category = "General",
    String targetType = "all",
    String? targetDepartment,
    List<String>? targetEmployeeIds,
    bool sendPushNotification = false,
  }) async {
    await _db.collection("announcements").add({
      "title": title,
      "text": text,
      "imageUrl": imageUrl ?? "",
      "pdfUrl": pdfUrl ?? "",
      "adminId": adminId ?? "",
      "category": category,
      "targetType": targetType,
      "targetDepartment": targetDepartment ?? "",
      "targetEmployeeIds": targetEmployeeIds ?? [],
      "seenBy": [],
      "sendPushNotification": sendPushNotification,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAnnouncement(
    String announcementId, {
    required String title,
    required String text,
    String? imageUrl,
    String? pdfUrl,
    String? category,
    String? targetType,
    String? targetDepartment,
    List<String>? targetEmployeeIds,
    bool? sendPushNotification,
  }) async {
    final Map<String, dynamic> updateData = {
      "title": title,
      "text": text,
      "imageUrl": imageUrl ?? "",
      "pdfUrl": pdfUrl ?? "",
    };

    if (category != null) updateData["category"] = category;
    if (targetType != null) updateData["targetType"] = targetType;
    if (targetDepartment != null) updateData["targetDepartment"] = targetDepartment;
    if (targetEmployeeIds != null) {
      updateData["targetEmployeeIds"] = targetEmployeeIds;
    }
    if (sendPushNotification != null) {
      updateData["sendPushNotification"] = sendPushNotification;
    }

    await _db.collection("announcements").doc(announcementId).update(updateData);
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await _db.collection("announcements").doc(announcementId).delete();
  }

  Future<void> markAnnouncementAsRead(
      String announcementId, String userId) async {
    await _db.collection("announcements").doc(announcementId).update({
      "seenBy": FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> markAnnouncementAsUnread(
      String announcementId, String userId) async {
    await _db.collection("announcements").doc(announcementId).update({
      "seenBy": FieldValue.arrayRemove([userId]),
    });
  }

  // Leave Applications methods
  Future<void> createLeaveApplication({
    required String employeeId,
    required String employeeName,
    required String employeeEmail,
    required String reason,
    String? imageUrl,
    required DateTime startDate,
    required DateTime endDate,
    String? leaveType,
    String? leaveSubType,
    String? documentUrl,
    String? documentName,
  }) async {
    await _db.collection("leave_applications").add({
      "employeeId": employeeId,
      "employeeName": employeeName,
      "employeeEmail": employeeEmail,
      "reason": reason,
      "imageUrl": imageUrl ?? "",
      "startDate": Timestamp.fromDate(startDate),
      "endDate": Timestamp.fromDate(endDate),
      if (leaveType != null) "leaveType": leaveType,
      if (leaveSubType != null) "leaveSubType": leaveSubType,
      if (documentUrl != null) "documentUrl": documentUrl,
      if (documentName != null) "documentName": documentName,
      "status": "pending", // pending, approved, rejected
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getLeaveApplications() {
    return _db
        .collection("leave_applications")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getEmployeeLeaveApplications(
      String employeeId) {
    // Query without orderBy to avoid composite index requirement
    // Sorting will be done in the UI
    return _db
        .collection("leave_applications")
        .where("employeeId", isEqualTo: employeeId)
        .snapshots();
  }

  Future<void> updateLeaveApplicationStatus(
      String applicationId, String status) async {
    await _db.collection("leave_applications").doc(applicationId).update({
      "status": status,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  // Admin methods for employee attendance
  Future<List<Map<String, dynamic>>> getTodayEmployeeAttendance() async {
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snap = await _db
        .collection("attendance")
        .doc(date)
        .collection("records")
        .orderBy("timestamp")
        .get();

    final records = snap.docs.map((d) => d.data()).toList();
    return records;
  }

  Future<List<Map<String, dynamic>>> getEmployeeAttendanceForMonth(
      String employeeId, DateTime month) async {
    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final allRecords = <Map<String, dynamic>>[];

      for (var date = startDate;
          date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
          date = date.add(const Duration(days: 1))) {
        String dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        try {
          // Fetch all records for the date and filter in memory
          // This avoids composite index requirements
          final snap = await _db
              .collection("attendance")
              .doc(dateStr)
              .collection("records")
              .get();

          for (var doc in snap.docs) {
            final data = doc.data();
            // Filter by employeeId in memory (handle both String and dynamic types)
            final recordEmployeeId = data["employeeId"];
            String recordEmployeeIdStr;
            if (recordEmployeeId == null) {
              recordEmployeeIdStr = "";
            } else if (recordEmployeeId is String) {
              recordEmployeeIdStr = recordEmployeeId;
            } else {
              recordEmployeeIdStr = recordEmployeeId.toString().trim();
            }
            
            if (recordEmployeeIdStr == employeeId.trim()) {
              allRecords.add({
                ...data,
                'date': dateStr,
              });
            }
          }
        } catch (e) {
          // If document doesn't exist, continue to next date
          // This is normal for dates with no attendance records
          continue;
        }
      }

      // Sort by timestamp
      allRecords.sort((a, b) {
        final timeA = a["timestamp"]?.toDate() ?? DateTime(1970);
        final timeB = b["timestamp"]?.toDate() ?? DateTime(1970);
        return timeA.compareTo(timeB);
      });

      print('getEmployeeAttendanceForMonth: Found ${allRecords.length} records for employee $employeeId in month ${month.year}-${month.month}');
      return allRecords;
    } catch (e) {
      print('Error in getEmployeeAttendanceForMonth: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllEmployeeAttendance(
      String employeeId) async {
    try {
      final allRecords = <Map<String, dynamic>>[];
      int totalRecordsChecked = 0;
      int matchingRecords = 0;

      print('getAllEmployeeAttendance: Looking for employeeId="$employeeId" (type: ${employeeId.runtimeType})');

      // Use CollectionGroup to query all "records" subcollections across all attendance documents
      // This is more efficient and works even if we can't list the parent collection
      try {
        final recordsSnapshot = await _db
            .collectionGroup("records")
            .get();

        totalRecordsChecked = recordsSnapshot.docs.length;
        print('getAllEmployeeAttendance: Found $totalRecordsChecked total records across all dates');

        for (var recordDoc in recordsSnapshot.docs) {
          try {
            final data = recordDoc.data();
            
            // Ensure we have the required fields
            if (!data.containsKey("employeeId") || !data.containsKey("timestamp")) {
              continue;
            }
            
            // Filter by employeeId in memory (handle both String and dynamic types)
            final recordEmployeeId = data["employeeId"];
            
            // Handle different types of employeeId - be more flexible
            String recordEmployeeIdStr;
            if (recordEmployeeId == null) {
              continue; // Skip records without employeeId
            } else if (recordEmployeeId is String) {
              recordEmployeeIdStr = recordEmployeeId.trim();
            } else {
              recordEmployeeIdStr = recordEmployeeId.toString().trim();
            }
            
            final employeeIdStr = employeeId.trim();
            
            // Debug: Print first few comparisons to see what's happening
            if (matchingRecords < 3 && totalRecordsChecked <= 10) {
              print('getAllEmployeeAttendance: Comparing recordEmployeeId="$recordEmployeeIdStr" (original type: ${recordEmployeeId.runtimeType}) with employeeId="$employeeIdStr" - Match: ${recordEmployeeIdStr == employeeIdStr}');
            }
            
            // Use both exact match and case-insensitive comparison
            if (recordEmployeeIdStr == employeeIdStr || 
                recordEmployeeIdStr.toLowerCase() == employeeIdStr.toLowerCase()) {
              matchingRecords++;
              
              // Extract date from the document path
              // Path format: attendance/{date}/records/{recordId}
              String? dateStr;
              try {
                final pathParts = recordDoc.reference.path.split('/');
                if (pathParts.length >= 2 && pathParts[0] == 'attendance') {
                  dateStr = pathParts[1];
                }
              } catch (e) {
                // If we can't extract date, try to get it from the data or use a default
                dateStr = data["date"] as String?;
              }
              
              // Ensure timestamp is properly included
              final recordData = {
                ...data,
                if (dateStr != null) 'date': dateStr,
              };
              
              // Verify timestamp exists and is valid
              if (recordData["timestamp"] != null) {
                allRecords.add(recordData);
                if (matchingRecords <= 3) {
                  print('getAllEmployeeAttendance: Added record for employee $employeeId from date ${dateStr ?? "unknown"}');
                }
              } else {
                print('Warning: Record found but timestamp is null for employee $employeeId');
              }
            }
          } catch (e) {
            print('Error processing record: $e');
            continue;
          }
        }
      } catch (e) {
        print('Error using collectionGroup query: $e');
        // Fallback: Try the old method if collectionGroup fails
        print('Falling back to date-based iteration method...');
        
        // Get a wide date range (last 2 years to future 1 year)
        final now = DateTime.now();
        final startDate = DateTime(now.year - 2, 1, 1);
        final endDate = DateTime(now.year + 1, 12, 31);
        
        for (var date = startDate;
            date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
            date = date.add(const Duration(days: 1))) {
          String dateStr = DateFormat('yyyy-MM-dd').format(date);
          
          try {
            final snap = await _db
                .collection("attendance")
                .doc(dateStr)
                .collection("records")
                .get();

            totalRecordsChecked += snap.docs.length;

            for (var doc in snap.docs) {
              final data = doc.data();
              final recordEmployeeId = data["employeeId"];
              
              String recordEmployeeIdStr;
              if (recordEmployeeId == null) {
                continue;
              } else if (recordEmployeeId is String) {
                recordEmployeeIdStr = recordEmployeeId.trim();
              } else {
                recordEmployeeIdStr = recordEmployeeId.toString().trim();
              }
              
              if (recordEmployeeIdStr == employeeId.trim()) {
                matchingRecords++;
                allRecords.add({
                  ...data,
                  'date': dateStr,
                });
              }
            }
          } catch (e) {
            continue;
          }
        }
      }

      // Sort by timestamp
      allRecords.sort((a, b) {
        try {
          final timeA = a["timestamp"]?.toDate() ?? DateTime(1970);
          final timeB = b["timestamp"]?.toDate() ?? DateTime(1970);
          return timeA.compareTo(timeB);
        } catch (e) {
          return 0;
        }
      });

      print('getAllEmployeeAttendance: Checked $totalRecordsChecked total records, found $matchingRecords matching records for employee "$employeeId"');
      print('getAllEmployeeAttendance: Returning ${allRecords.length} records');
      
      if (allRecords.isEmpty && totalRecordsChecked > 0) {
        print('WARNING: getAllEmployeeAttendance found $totalRecordsChecked records but none matched employeeId="$employeeId"');
      }
      
      return allRecords;
    } catch (e, stackTrace) {
      print('Error in getAllEmployeeAttendance: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
}

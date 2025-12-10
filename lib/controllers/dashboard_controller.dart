import 'package:get/get.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';

class DashboardController extends GetxController {
  final fs = FirestoreService();
  
  final userEmail = "".obs;
  final userId = "".obs;
  final profileImageUrl = "".obs;

  @override
  void onInit() {
    super.onInit();
    loadUser();
    loadProfileImage();
  }

  Future<void> loadUser() async {
    final u = await LocalStorage.getUser();
    userEmail.value = u["email"] ?? "";
    userId.value = u["uid"] ?? "";
  }

  Future<void> loadProfileImage() async {
    final u = await LocalStorage.getUser();
    final employee = await fs.getEmployee(u["uid"]);
    profileImageUrl.value = employee?.profileImage ?? "";
  }

  Duration calculateWorkedHours(List records) {
    if (records.isEmpty) return Duration.zero;

    List<Map<String, dynamic>> recordList = [];
    for (var record in records) {
      try {
        final data = record.data() as Map<String, dynamic>;
        final timestamp = data["timestamp"];
        final type = data["type"] as String?;
        if (timestamp == null || type == null) continue;

        DateTime? time;
        if (timestamp is DateTime) {
          time = timestamp;
        } else {
          try {
            time = timestamp.toDate();
          } catch (e) {
            continue;
          }
        }
        if (time == null) continue;
        recordList.add({'type': type, 'timestamp': time});
      } catch (e) {
        continue;
      }
    }

    if (recordList.isEmpty) return Duration.zero;
    recordList.sort((a, b) {
      final timeA = a["timestamp"] as DateTime;
      final timeB = b["timestamp"] as DateTime;
      return timeA.compareTo(timeB);
    });

    Duration totalDuration = Duration.zero;
    DateTime? checkInTime;

    for (var record in recordList) {
      final time = record["timestamp"] as DateTime;
      final type = record["type"] as String;

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
}


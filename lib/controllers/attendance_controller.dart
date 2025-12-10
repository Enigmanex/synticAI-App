import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';

class AttendanceController extends GetxController {
  final FirestoreService _fs = FirestoreService();

  RxBool loading = false.obs; // Keep for backward compatibility
  RxBool checkInLoading = false.obs;
  RxBool checkOutLoading = false.obs;
  RxBool hasLocationAccess = true.obs;
  RxBool isCheckedIn = false.obs; // Track if employee is currently checked in

  Timer? _autoCheckoutTimer;
  StreamSubscription? _recordsSubscription;

  @override
  void onInit() {
    super.onInit();
    _refreshLocationAccessStatus();
    _listenToRecords();
    // Delay status check slightly to ensure user data is loaded
    Future.delayed(const Duration(milliseconds: 300), () {
      _checkCurrentStatus();
    });
    _setupAutoCheckout();
  }

  @override
  void onClose() {
    _autoCheckoutTimer?.cancel();
    _recordsSubscription?.cancel();
    super.onClose();
  }

  /// Listen to today's records to update check-in status reactively
  void _listenToRecords() {
    _recordsSubscription = _fs.todayRecords().listen((snapshot) async {
      try {
        final user = await LocalStorage.getUser();
        final userId = user["uid"];
        if (userId == null || userId.isEmpty) {
          isCheckedIn.value = false;
          return;
        }

        // Filter records for current user
        final userRecords = snapshot.docs.where((doc) {
          try {
            final data = doc.data();
            final empId = data["employeeId"];
            final empIdString = empId is String
                ? empId
                : empId?.toString() ?? "";
            return empIdString == userId;
          } catch (e) {
            return false;
          }
        }).toList();

        if (userRecords.isEmpty) {
          isCheckedIn.value = false;
          print('No records found for user, setting isCheckedIn to false');
          return;
        }

        // Get all records and sort by timestamp
        final records = <Map<String, dynamic>>[];
        for (var doc in userRecords) {
          try {
            final data = doc.data();
            final type = data["type"] as String?;
            if (type == null) continue;

            DateTime? timestamp;
            final ts = data["timestamp"];
            if (ts != null) {
              if (ts is DateTime) {
                timestamp = ts;
              } else {
                try {
                  timestamp = ts.toDate();
                } catch (e) {
                  print('Error converting timestamp: $e');
                  continue;
                }
              }
            }

            if (timestamp != null) {
              records.add({'type': type, 'timestamp': timestamp});
            }
          } catch (e) {
            print('Error processing record: $e');
            continue;
          }
        }

        if (records.isEmpty) {
          isCheckedIn.value = false;
          print('No valid records found, setting isCheckedIn to false');
          return;
        }

        // Sort by timestamp
        records.sort((a, b) {
          final timeA = a["timestamp"] as DateTime? ?? DateTime(1970);
          final timeB = b["timestamp"] as DateTime? ?? DateTime(1970);
          return timeA.compareTo(timeB);
        });

        // Check if last record is check_in
        final lastRecord = records.last;
        final lastType = lastRecord["type"] as String?;
        final isCheckedInStatus = lastType == "check_in";
        isCheckedIn.value = isCheckedInStatus;
        print(
          'Status updated: isCheckedIn = $isCheckedInStatus (last record type: $lastType)',
        );
      } catch (e) {
        print('Error listening to records: $e');
        print('Stack trace: ${StackTrace.current}');
      }
    });
  }

  /// Check current check-in status
  Future<void> _checkCurrentStatus() async {
    try {
      final user = await LocalStorage.getUser();
      final userId = user["uid"];
      if (userId == null || userId.isEmpty) {
        isCheckedIn.value = false;
        return;
      }

      // Check for auto-checkout first
      await _fs.autoCheckoutAtEndOfDay(userId);

      // Then check current status
      final hasOpen = await _fs.hasOpenCheckIn(userId);
      isCheckedIn.value = hasOpen;
      print(
        '_checkCurrentStatus: hasOpen = $hasOpen, isCheckedIn.value = ${isCheckedIn.value}',
      );
    } catch (e) {
      print('Error checking current status: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Setup periodic check for auto-checkout (every 5 minutes)
  void _setupAutoCheckout() {
    // Check immediately
    _checkAutoCheckout();

    // Then check every 5 minutes
    _autoCheckoutTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkAutoCheckout();
    });
  }

  /// Check and perform auto-checkout if needed
  Future<void> _checkAutoCheckout() async {
    try {
      final user = await LocalStorage.getUser();
      final userId = user["uid"];
      if (userId == null || userId.isEmpty) return;

      await _fs.autoCheckoutAtEndOfDay(userId);
      await _checkCurrentStatus(); // Refresh status after auto-checkout
    } catch (e) {
      print('Error in auto-checkout check: $e');
    }
  }

  Future<void> _refreshLocationAccessStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      hasLocationAccess.value =
          serviceEnabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse);
    } catch (_) {
      hasLocationAccess.value = false;
    }
  }

  Future<bool> _ensureLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      hasLocationAccess.value = false;
      Get.snackbar(
        "Location",
        "Location services are disabled. Please enable them in settings.",
        mainButton: TextButton(
          onPressed: () => Geolocator.openLocationSettings(),
          child: const Text("Open Settings"),
        ),
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      hasLocationAccess.value = false;
      Get.snackbar(
        "Location",
        "Location permissions are denied. Grant permission to proceed.",
        mainButton: TextButton(
          onPressed: () => Geolocator.openAppSettings(),
          child: const Text("Grant Permission"),
        ),
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      hasLocationAccess.value = false;
      Get.snackbar(
        "Location",
        "Location permissions are blocked. Enable them in the app settings.",
        mainButton: TextButton(
          onPressed: () => Geolocator.openAppSettings(),
          child: const Text("Open Settings"),
        ),
      );
      return false;
    }

    hasLocationAccess.value = true;
    return true;
  }

  Future<String?> _getCurrentAddress() async {
    try {
      if (!await _ensureLocationAccess()) {
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Convert coordinates to address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = _formatAddress(place);
        return address;
      }

      return null;
    } catch (e) {
      Get.snackbar("Location Error", "Failed to get location: ${e.toString()}");
      return null;
    }
  }

  String _formatAddress(Placemark place) {
    List<String> addressParts = [];

    if (place.street != null && place.street!.isNotEmpty) {
      addressParts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      addressParts.add(place.country!);
    }

    return addressParts.isNotEmpty
        ? addressParts.join(", ")
        : "Location unavailable";
  }

  Future<void> checkIn() async {
    checkInLoading.value = true;
    loading.value = true; // Keep for backward compatibility
    try {
      // Check if already checked in
      final user = await LocalStorage.getUser();
      final userId = user["uid"];

      if (userId == null || userId.isEmpty) {
        Get.snackbar("Error", "User not found");
        return;
      }

      // Check for auto-checkout first
      await _fs.autoCheckoutAtEndOfDay(userId);

      // Check if already checked in - use reactive value first, then verify with database
      if (isCheckedIn.value) {
        // Double-check with database to be sure
        final hasOpen = await _fs.hasOpenCheckIn(userId);
        if (hasOpen) {
          Get.snackbar(
            "Already Checked In",
            "You need to check out first before checking in again.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return;
        }
        // If database says not checked in, update reactive value
        isCheckedIn.value = false;
      } else {
        // Verify with database in case reactive value is stale
        final hasOpen = await _fs.hasOpenCheckIn(userId);
        if (hasOpen) {
          isCheckedIn.value = true;
          Get.snackbar(
            "Already Checked In",
            "You need to check out first before checking in again.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return;
        }
      }

      String? address = await _getCurrentAddress();
      if (address == null) {
        return;
      }

      await _fs.recordAttendance(userId, "check_in", address);
      // Update reactive value immediately
      isCheckedIn.value = true;
      print('Check-in completed, isCheckedIn set to true');
      // Also refresh from database after a short delay to ensure sync
      Future.delayed(const Duration(milliseconds: 1000), () {
        _checkCurrentStatus();
      });
      Get.snackbar("Success", "Checked in successfully");
    } catch (e) {
      Get.snackbar("Error", "Failed to check in: ${e.toString()}");
    } finally {
      checkInLoading.value = false;
      loading.value = false; // Keep for backward compatibility
    }
  }

  Future<void> checkOut() async {
    checkOutLoading.value = true;
    loading.value = true; // Keep for backward compatibility
    try {
      final user = await LocalStorage.getUser();
      final userId = user["uid"];

      if (userId == null || userId.isEmpty) {
        Get.snackbar("Error", "User not found");
        return;
      }

      // Check current status - use reactive value as primary, verify with database
      bool canCheckOut = isCheckedIn.value;

      // If reactive value says not checked in, verify with database
      if (!canCheckOut) {
        // Refresh status from database
        await _checkCurrentStatus();
        canCheckOut = isCheckedIn.value;
      }

      if (!canCheckOut) {
        Get.snackbar(
          "Not Checked In",
          "You need to check in first before checking out.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      String? address = await _getCurrentAddress();
      if (address == null) {
        return;
      }

      await _fs.recordAttendance(userId, "check_out", address);
      // Update reactive value immediately
      isCheckedIn.value = false;
      print('Check-out completed, isCheckedIn set to false');
      // Also refresh from database after a short delay to ensure sync
      Future.delayed(const Duration(milliseconds: 1000), () {
        _checkCurrentStatus();
      });
      Get.snackbar("Success", "Checked out successfully");
    } catch (e) {
      Get.snackbar("Error", "Failed to check out: ${e.toString()}");
    } finally {
      checkOutLoading.value = false;
      loading.value = false; // Keep for backward compatibility
    }
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/attendance_controller.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';
import '../utils/app_colors.dart';
import 'leave_application_flow_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final attendance = Get.put(AttendanceController());
  final fs = FirestoreService();

  String userEmail = "";
  String userId = "";
  String profileImageUrl = "";
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    loadUser();
    _loadProfileImage();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  loadUser() async {
    final u = await LocalStorage.getUser();
    setState(() {
      userEmail = u["email"];
      userId = u["uid"];
    });
  }

  Future<void> _loadProfileImage() async {
    final u = await LocalStorage.getUser();
    final employee = await fs.getEmployee(u["uid"]);
    if (mounted) {
      setState(() {
        profileImageUrl = employee?.profileImage ?? "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        height: size.height,
        width: size.width,
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Modern App Bar
              _buildModernAppBar(theme),
              SizedBox(height: 20),
              // User Info Card with Animation
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildUserInfoCard(size, theme),
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons with Animation
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildActionButtons(theme),
                ),
              ),

              const SizedBox(height: 20),

              // Apply for Leave Button
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildLeaveApplicationButton(),
              ),

              const SizedBox(height: 20),

              // Worked Hours Card
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildWorkedHoursCard(),
              ),

              const SizedBox(height: 24),

              // Records Section Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.history, color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      "Today's Records",
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

              // Records List with Animation
              Expanded(child: _buildRecordsList(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(ThemeData theme) {
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(Size size, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
      child: Row(
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
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: profileImageUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: profileImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.primaryLight,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  )
                : const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userEmail.isEmpty ? "Loading..." : userEmail,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
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
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Obx(() {
      final hasLocationAccess = attendance.hasLocationAccess.value;
      final isLoading =
          attendance.checkInLoading.value || attendance.checkOutLoading.value;
      final disableActions = isLoading;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildAnimatedButton(
                    onPressed: disableActions
                        ? null
                        : () {
                            _scaleController.reset();
                            _scaleController.forward();
                            attendance.checkIn();
                          },
                    label: "Check In",
                    icon: Icons.login,
                    color: AppColors.primary,
                    isLoading: attendance.checkInLoading.value,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAnimatedButton(
                    onPressed: disableActions
                        ? null
                        : () {
                            _scaleController.reset();
                            _scaleController.forward();
                            attendance.checkOut();
                          },
                    label: "Check Out",
                    icon: Icons.logout,
                    color: Colors.black87,
                    isLoading: attendance.checkOutLoading.value,
                  ),
                ),
              ],
            ),
            if (!hasLocationAccess)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Enable location access to check in or out.",
                  style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildLeaveApplicationButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Get.to(() => const LeaveApplicationFlowScreen()),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_busy, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "Apply for Leave",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: onPressed == null
                    ? [Colors.grey.shade300, Colors.grey.shade400]
                    : [color.withOpacity(0.8), color],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: onPressed == null
                  ? []
                  : [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkedHoursCard() {
    return FutureBuilder<String>(
      future: userId.isEmpty
          ? LocalStorage.getUser().then((u) => u["uid"] ?? "")
          : Future.value(userId),
      builder: (context, userIdSnapshot) {
        return StreamBuilder(
          stream: fs.todayRecords(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !userIdSnapshot.hasData) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
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
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            final currentUserId = userIdSnapshot.data ?? userId;
            if (currentUserId.isEmpty) {
              return const SizedBox.shrink();
            }

            final docs = snapshot.data!.docs;
            final userRecords = docs.where((doc) {
              try {
                final data = doc.data();
                final empId = data["employeeId"];
                // Handle both String and dynamic types
                final empIdString = empId is String
                    ? empId
                    : empId?.toString() ?? "";
                return empIdString == currentUserId;
              } catch (e) {
                return false;
              }
            }).toList();

            // Calculate total worked hours
            Duration totalDuration = _calculateWorkedHours(userRecords);

            final hours = totalDuration.inHours;
            final minutes = totalDuration.inMinutes % 60;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.access_time_filled,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Worked Today",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "$hours",
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1,
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
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$minutes",
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1,
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
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Duration _calculateWorkedHours(List records) {
    if (records.isEmpty) return Duration.zero;

    // Convert records to a list with proper data access and DateTime conversion
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
          // It's a Firestore Timestamp
          try {
            time = timestamp.toDate();
          } catch (e) {
            // print("Error converting timestamp: $e");
            continue; // Skip invalid timestamps
          }
        }

        if (time == null) continue;

        recordList.add({'type': type, 'timestamp': time});
      } catch (e) {
        // print("Error processing record: $e");
        continue;
      }
    }

    if (recordList.isEmpty) return Duration.zero;

    // Sort records by timestamp
    recordList.sort((a, b) {
      final timeA = a["timestamp"] as DateTime;
      final timeB = b["timestamp"] as DateTime;
      return timeA.compareTo(timeB);
    });

    // Debug: Print sorted records
    // print("Processing ${recordList.length} records:");
    // for (var r in recordList) {
    //   print("  ${r['type']} at ${r['timestamp']}");
    // }

    Duration totalDuration = Duration.zero;
    DateTime? checkInTime;

    for (var record in recordList) {
      final time = record["timestamp"] as DateTime;
      final type = record["type"] as String;

      if (type == "check_in") {
        // If there's already a check-in without check-out,
        // calculate time from previous check-in to this check-in (treat as check-out)
        if (checkInTime != null) {
          final duration = time.difference(checkInTime);
          if (!duration.isNegative) {
            totalDuration += duration;
          }
        }
        // Set new check-in time
        checkInTime = time;
      } else if (type == "check_out") {
        if (checkInTime != null) {
          final duration = time.difference(checkInTime);
          if (duration.isNegative) {
            // Invalid pair (check-out before check-in), skip
            // print("Warning: Check-out before check-in at $time");
            checkInTime = null;
            continue;
          }
          totalDuration += duration;
          checkInTime = null; // Reset for next pair
        }
        // If check-out without check-in, ignore it (orphaned check-out)
      }
    }

    // If user is still checked in (has check-in but no check-out)
    if (checkInTime != null) {
      final now = DateTime.now();
      final duration = now.difference(checkInTime);
      if (!duration.isNegative) {
        totalDuration += duration;
      }
    }

    // Debug: Print result
    // print("Total duration: ${totalDuration.inHours}h ${totalDuration.inMinutes % 60}m");

    return totalDuration;
  }

  Widget _buildRecordsList(ThemeData theme) {
    return FutureBuilder<String>(
      future: userId.isEmpty
          ? LocalStorage.getUser().then((u) => u["uid"] ?? "")
          : Future.value(userId),
      builder: (context, userIdSnapshot) {
        return StreamBuilder(
          stream: fs.todayRecords(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !userIdSnapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Loading records...",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            final currentUserId = userIdSnapshot.data ?? userId;
            if (currentUserId.isEmpty) {
              return const SizedBox.shrink();
            }

            final docs = snapshot.data!.docs;

            // Filter records to show only current user's records
            final userRecords = docs.where((doc) {
              try {
                final data = doc.data();
                final empId = data["employeeId"];
                // Handle both String and dynamic types
                final empIdString = empId is String
                    ? empId
                    : empId?.toString() ?? "";
                return empIdString == currentUserId;
              } catch (e) {
                return false;
              }
            }).toList();

            if (userRecords.isEmpty) {
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
                      "No records for today",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: userRecords.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                  child: _buildRecordCard(userRecords[index], theme),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRecordCard(dynamic doc, ThemeData theme) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data["timestamp"];
    final address = data["address"] as String? ?? "";
    DateTime? time;
    if (timestamp is DateTime) {
      time = timestamp;
    } else if (timestamp != null) {
      time = timestamp.toDate();
    }
    final isCheckIn = data["type"] == "check_in";

    if (time == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCheckIn
              ? AppColors.backgroundLight
              : Colors.black.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                        fontSize: 16,
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
                          DateFormat('h:mm a').format(time),
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
            const SizedBox(height: 12),
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
                  Icon(Icons.location_on, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

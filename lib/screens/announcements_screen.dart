import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';
import '../utils/app_colors.dart';
import '../utils/announcement_constants.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen>
    with TickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _userId = "";
  String _userDepartment = "";
  bool _isLoadingUser = true;
  String _selectedCategory = _categoryAll;
  final Set<String> _processingAnnouncements = {};
  static const String _categoryAll = "All";

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
    _loadUserContext();
  }

  Future<void> _loadUserContext() async {
    final user = await LocalStorage.getUser();
    final uid = user["uid"] as String? ?? "";
    String department = "";
    if (uid.isNotEmpty) {
      final employee = await _fs.getEmployee(uid);
      department = employee?.department ?? "";
    }
    if (!mounted) return;
    setState(() {
      _userId = uid;
      _userDepartment = department;
      _isLoadingUser = false;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar("Error", "Could not open PDF");
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
              // Header
              _buildHeader(),

              // Announcements List
              Expanded(
                child: _isLoadingUser
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      )
                    : _buildAnnouncementsList(),
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

  Widget _buildAnnouncementsList() {
    return StreamBuilder(
      stream: _fs.getAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Failed to load announcements",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
        final targetedDocs = docs
            .where((doc) => _isTargetedAnnouncement(doc.data()))
            .toList();
        final displayDocs = _selectedCategory == _categoryAll
            ? targetedDocs
            : targetedDocs.where((doc) {
                final category =
                    (doc.data()["category"] as String?) ??
                    announcementCategories.first;
                return category == _selectedCategory;
              }).toList();

        String message;
        if (docs.isEmpty) {
          message = "No announcements yet";
        } else if (targetedDocs.isEmpty) {
          message = "No announcements available for you yet";
        } else {
          message = "No announcements match this category";
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildCategoryFilter(),
            ),
            Expanded(
              child: displayDocs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            size: 70,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            message,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: displayDocs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(
                              milliseconds: 300 + (index * 100),
                            ),
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
                            child: _buildAnnouncementCard(displayDocs[index]),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    final filters = [_categoryAll, ...announcementCategories];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: filters.map((category) {
        final isSelected = _selectedCategory == category;
        return ChoiceChip(
          checkmarkColor: Colors.white,
          label: Text(category),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedCategory = category),
          selectedColor: AppColors.primary,
          backgroundColor: Colors.grey.shade100,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }

  bool _isTargetedAnnouncement(Map<String, dynamic> data) {
    final targetType = data["targetType"] as String? ?? announcementTargetAll;
    if (targetType == announcementTargetAll) return true;
    if (_userId.isEmpty) return false;
    if (targetType == announcementTargetDepartment) {
      final targetDept = (data["targetDepartment"] as String?) ?? "";
      return targetDept.isNotEmpty &&
          targetDept.toLowerCase() == _userDepartment.toLowerCase();
    }
    if (targetType == announcementTargetEmployees) {
      final ids = (data["targetEmployeeIds"] as List<dynamic>?) ?? [];
      return ids.map((e) => e.toString()).contains(_userId);
    }
    return true;
  }

  Future<void> _toggleAnnouncementRead(String docId, bool markRead) async {
    if (_userId.isEmpty) return;
    setState(() => _processingAnnouncements.add(docId));
    try {
      if (markRead) {
        await _fs.markAnnouncementAsRead(docId, _userId);
      } else {
        await _fs.markAnnouncementAsUnread(docId, _userId);
      }
    } finally {
      if (mounted) {
        setState(() => _processingAnnouncements.remove(docId));
      }
    }
  }

  Widget _buildAnnouncementCard(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
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
    final targetDetail = formatTargetAudience(
      targetType,
      targetType == announcementTargetDepartment
          ? targetDepartment
          : targetType == announcementTargetEmployees
          ? targetEmployeeIds.length.toString()
          : null,
      targetEmployeeIds.length,
    );
    final isRead = seenBy.contains(_userId);
    final processing = _processingAnnouncements.contains(doc.id);
    final timestamp = data["createdAt"];

    DateTime? date;
    if (timestamp != null) {
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = timestamp.toDate();
      }
    }

    final hasImage = imageUrl.isNotEmpty;
    final hasPdf = pdfUrl.isNotEmpty;
    final hasText = text.isNotEmpty;

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
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                      label: Text(isRead ? "Marked as read" : "Unread"),
                      backgroundColor: isRead
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isRead
                            ? Colors.green.shade800
                            : Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Seen by ${seenBy.length} people",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.topRight,

                  child: GestureDetector(
                    onTap: () => _toggleAnnouncementRead(doc.id, !isRead),
                    child: Icon(
                      !isRead ? Icons.email_outlined : Icons.email,
                      color: isRead ? AppColors.primaryLight : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Title and Date
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
                label: Text(announcementTargetLabels[targetType] ?? "Targeted"),
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
          const SizedBox(height: 12),

          // Text Content
          if (hasText)
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),

          // Image
          if (hasImage) ...[
            if (hasText) const SizedBox(height: 16),
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
                        AppColors.primary,
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

          // PDF Button
          if (hasPdf) ...[
            if (hasText || hasImage) const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openPdf(pdfUrl),
                  borderRadius: BorderRadius.circular(12),
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
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

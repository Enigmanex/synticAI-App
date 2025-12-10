const List<String> announcementCategories = [
  "General",
  "HR Update",
  "Holiday",
  "Policy Update",
  "Emergency",
];

const String announcementTargetAll = "all";
const String announcementTargetEmployees = "employees";

const List<String> announcementTargetOptions = [
  announcementTargetAll,
  announcementTargetEmployees,
];

const Map<String, String> announcementTargetLabels = {
  announcementTargetAll: "All Employees",
  announcementTargetEmployees: "Specific Employee(s)",
};

String formatTargetAudience(
  String targetType,
  String? detail,
  int employeeCount,
) {
  switch (targetType) {
    case announcementTargetEmployees:
      if (employeeCount > 0) {
        return "Employees: $employeeCount selected";
      }
      return detail?.isEmpty == false
          ? "Employees: $detail"
          : "Specific employees";
    default:
      return "All Employees";
  }
}

const List<String> announcementCategories = [
  "General",
  "HR Update",
  "Holiday",
  "Policy Update",
  "Emergency",
];

const String announcementTargetAll = "all";
const String announcementTargetDepartment = "department";
const String announcementTargetEmployees = "employees";

const List<String> announcementTargetOptions = [
  announcementTargetAll,
  announcementTargetDepartment,
  announcementTargetEmployees,
];

const Map<String, String> announcementTargetLabels = {
  announcementTargetAll: "All Employees",
  announcementTargetDepartment: "Specific Department",
  announcementTargetEmployees: "Specific Employee(s)",
};

String formatTargetAudience(String targetType, String? detail, int employeeCount) {
  switch (targetType) {
    case announcementTargetDepartment:
      return detail?.isEmpty == false
          ? "Department: $detail"
          : "Department selected";
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


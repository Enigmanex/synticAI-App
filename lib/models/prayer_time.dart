class PrayerTime {
  final String name;
  final String time; // Format: "HH:mm" (24-hour format)
  final String message;

  const PrayerTime({
    required this.name,
    required this.time,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'time': time, 'message': message};
  }

  factory PrayerTime.fromMap(Map<String, dynamic> map) {
    return PrayerTime(
      name: map['name'] ?? '',
      time: map['time'] ?? '',
      message: map['message'] ?? '',
    );
  }

  // Get hour and minute from time string
  int get hour {
    final parts = time.split(':');
    if (parts.length == 2) {
      return int.tryParse(parts[0]) ?? 0;
    }
    return 0;
  }

  int get minute {
    final parts = time.split(':');
    if (parts.length == 2) {
      return int.tryParse(parts[1]) ?? 0;
    }
    return 0;
  }
}

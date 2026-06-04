import 'package:hive/hive.dart';

part 'attendance_model.g.dart';

@HiveType(typeId: 1)
class Attendance {
  @HiveField(0)
  final int? id;
  @HiveField(1)
  final String rfid;
  @HiveField(2)
  final String date;
  @HiveField(3)
  final String status;
  @HiveField(4)
  final String? time; // e.g. "14:35"

  Attendance({
    this.id,
    required this.rfid,
    required this.date,
    required this.status,
    this.time,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rfid': rfid,
      'date': date,
      'status': status,
      'time': time,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'],
      rfid: map['rfid'],
      date: map['date'],
      status: map['status'],
      time: map['time'],
    );
  }
}

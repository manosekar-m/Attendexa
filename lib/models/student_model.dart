import 'package:hive/hive.dart';

part 'student_model.g.dart';

@HiveType(typeId: 0)
class Student {
  @HiveField(0)
  final String rfid;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String stdSec;

  Student({required this.rfid, required this.name, required this.stdSec});

  Map<String, dynamic> toMap() {
    return {
      'rfid': rfid,
      'name': name,
      'stdSec': stdSec,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      rfid: map['rfid'],
      name: map['name'],
      stdSec: map['stdSec'],
    );
  }
}

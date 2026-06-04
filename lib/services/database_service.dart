import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  // Box Names
  static const String studentsBoxName = 'students_box';
  static const String attendanceBoxName = 'attendance_box';
  static const String deletedStudentsBoxName = 'deleted_students_box';

  // Lazy box access or persistent box? Since it's a small app, we can just keep them open.
  Future<Box<Student>> get studentsBox async => await Hive.openBox<Student>(studentsBoxName);
  Future<Box<Attendance>> get attendanceBox async => await Hive.openBox<Attendance>(attendanceBoxName);
  Future<Box<String>> get deletedBox async => await Hive.openBox<String>(deletedStudentsBoxName);

  // Student Operations
  Future<void> insertStudent(Student student) async {
    final sBox = await studentsBox;
    final dBox = await deletedBox;
    
    // When inserting (manual or undo), remove from exclusion list
    if (dBox.containsKey(student.rfid)) {
      await dBox.delete(student.rfid);
    }
    
    await sBox.put(student.rfid, student);
  }

  Future<void> updateStudent(String oldRfid, Student newStudent) async {
    final sBox = await studentsBox;
    final dBox = await deletedBox;
    
    // If the RFID changed, delete the old record
    if (oldRfid != newStudent.rfid) {
      await sBox.delete(oldRfid);
    }
    
    if (dBox.containsKey(newStudent.rfid)) {
      await dBox.delete(newStudent.rfid);
    }
    
    await sBox.put(newStudent.rfid, newStudent);
  }

  Future<bool> isStudentDeletedManually(String rfid) async {
    final dBox = await deletedBox;
    return dBox.containsKey(rfid);
  }

  Future<List<Student>> getAllStudents() async {
    final sBox = await studentsBox;
    return sBox.values.toList();
  }

  Future<Student?> getStudentByRfid(String rfid) async {
    final sBox = await studentsBox;
    return sBox.get(rfid);
  }

  Future<Student?> getStudentByStdSec(String stdSec) async {
    final sBox = await studentsBox;
    try {
      return sBox.values.firstWhere((s) => s.stdSec == stdSec);
    } catch (_) {
      return null;
    }
  }

  // Attendance Operations
  Future<int> markAttendance(String rfid, String date) async {
    final aBox = await attendanceBox;
    
    // Check if already marked (composite key check)
    final existing = aBox.values.where((a) => a.rfid == rfid && a.date == date);
    
    if (existing.isNotEmpty) {
      return -1; // Already marked
    }

    final time = DateFormat('HH:mm').format(DateTime.now());

    final attendance = Attendance(
      rfid: rfid,
      date: date,
      status: 'Present',
      time: time,
    );
    
    await aBox.add(attendance);
    return 1;
  }

  Future<List<Map<String, dynamic>>> getTodayAttendanceList(String date) async {
    final aBox = await attendanceBox;
    final sBox = await studentsBox;
    
    final dailyAttendance = aBox.values.where((a) => a.date == date).toList();
    
    List<Map<String, dynamic>> result = [];
    
    for (var student in sBox.values) {
      final att = dailyAttendance.where((a) => a.rfid == student.rfid).firstOrNull;
      
      if (att != null) {
        result.add({
          'rfid': student.rfid,
          'name': student.name,
          'stdSec': student.stdSec,
          'date': att.date,
          'status': att.status,
          'time': att.time ?? '',
        });
      } else {
        result.add({
          'rfid': student.rfid,
          'name': student.name,
          'stdSec': student.stdSec,
          'date': date,
          'status': 'Absent',
          'time': '',
        });
      }
    }
    
    return result;
  }

  Future<void> toggleAttendance(String rfid, String date, String currentStatus) async {
    final aBox = await attendanceBox;
    
    if (currentStatus == 'Present') {
      // Change to Absent -> Delete the record
      final keysToDelete = aBox.keys.where((k) {
        final att = aBox.get(k);
        return att != null && att.rfid == rfid && att.date == date;
      }).toList();
      
      for (var k in keysToDelete) {
        await aBox.delete(k);
      }
    } else {
      // Change to Present -> Add the record
      final time = DateFormat('HH:mm').format(DateTime.now());
      final attendance = Attendance(
        rfid: rfid,
        date: date,
        status: 'Present',
        time: time,
      );
      await aBox.add(attendance);
    }
  }

  Future<int> getPresentCountToday(String date) async {
    final aBox = await attendanceBox;
    return aBox.values.where((a) => a.date == date).length;
  }

  Future<void> deleteStudent(String rfid) async {
    final sBox = await studentsBox;
    final aBox = await attendanceBox;
    final dBox = await deletedBox;
    
    // Record in exclusion list so it doesn't reappear on re-import
    await dBox.put(rfid, rfid);

    // Delete attendance records for this student
    final keysToDelete = aBox.keys.where((k) {
      final att = aBox.get(k);
      return att != null && att.rfid == rfid;
    }).toList();
    
    await aBox.deleteAll(keysToDelete);
    await sBox.delete(rfid);
  }

  Future<void> eraseAllData() async {
    final sBox = await studentsBox;
    final aBox = await attendanceBox;
    final dBox = await deletedBox;
    
    await sBox.clear();
    await aBox.clear();
    await dBox.clear();
  }
}

import 'dart:io';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';
import '../models/student_model.dart';

class ExcelService {
  final DatabaseService _dbService = DatabaseService();

  Future<String?> importStudents(String filePath) async {
    try {
      var file = File(filePath);
      if (!file.existsSync()) return "File does not exist";
      var bytes = file.readAsBytesSync();
      
      // Use SpreadsheetDecoder for more robust reading
      var decoder = SpreadsheetDecoder.decodeBytes(bytes);

      for (var table in decoder.tables.keys) {
        var sheet = decoder.tables[table];
        if (sheet == null) continue;
        
        final allRows = sheet.rows;
        if (allRows.isEmpty) continue;
        
        var firstRow = allRows[0];
        if (firstRow.length < 3) continue; // Skip sheets that don't have enough columns

        String h0 = _getCellValue(firstRow[0]).trim().toLowerCase();
        String h1 = _getCellValue(firstRow[1]).trim().toLowerCase();
        String h2 = _getCellValue(firstRow[2]).trim().toLowerCase();
        
        // Only process sheets that match our header format (rfid/nfc tag id, name, std-sec/roll)
        bool hasNfc = h0.contains("nfc") || h0.contains("rfid") || h0.contains("tag");
        bool hasName = h1.contains("name");
        bool hasStdSec = h2.contains("std") || h2.contains("sec") || h2.contains("roll");

        if (!hasNfc || !hasName || !hasStdSec) {
          continue; 
        }

        for (int i = 1; i < allRows.length; i++) {
          var row = allRows[i];
          if (row.isEmpty) continue;

          String rfid = _getCellValue(row.isNotEmpty ? row[0] : null).trim();
          String name = _getCellValue(row.length > 1 ? row[1] : null).trim();
          String roll = _getCellValue(row.length > 2 ? row[2] : null).trim();

          if (rfid.isEmpty || rfid.toLowerCase() == "rfid" || rfid == "null") continue;

          bool isDeleted = await _dbService.isStudentDeletedManually(rfid);
          if (!isDeleted) {
            await _dbService.insertStudent(Student(
              rfid: rfid,
              name: name,
              stdSec: roll,
            ));
          }
        }
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print("Excel Import Error: $e");
      return "Import Error: $e";
    }
  }

  String _getCellValue(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  Future<String?> exportAttendance(String date, List<Map<String, dynamic>> records) async {
    try {
      List<List<dynamic>> rows = [];
      rows.add(["Name", "Std-Sec", "Date", "Time", "Status"]);

      for (var record in records) {
        rows.add([
          record['name'],
          record['stdSec'],
          record['date'],
          record['time'] ?? '',
          record['status'],
        ]);
      }

      String csvData = Csv().encode(rows);
      
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) return null;

      String fileName = "Attendance_$date.csv";
      File file = File("${downloadsDir.path}/$fileName");
      await file.writeAsString(csvData);
      
      return file.path;
    } catch (e) {
      // csv export error handled silently
      return null;
    }
  }
}

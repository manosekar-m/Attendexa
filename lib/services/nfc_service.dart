import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'database_service.dart';
import 'package:intl/intl.dart';

class NfcService {
  final DatabaseService _dbService = DatabaseService();

  Future<void> startNfcSession({
    required Function(String status, bool isError) onResult,
  }) async {
    // Check availability
    NfcAvailability availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      onResult("NFC not available on this device", true);
      return;
    }

    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        try {
          // Read the text stored on the NFC card
          String? tagText = _readNdefText(tag);

          if (tagText == null || tagText.isEmpty) {
            onResult("No text found on NFC card", true);
            return;
          }

          String nfcTagId = tagText.trim().toUpperCase();
          String date = DateFormat('yyyy-MM-dd').format(DateTime.now());

          // Match against student NFC Tag ID
          var student = await _dbService.getStudentByRfid(nfcTagId);
          if (student == null) {
            onResult("Unknown NFC ID: $nfcTagId", true);
          } else {
            int result = await _dbService.markAttendance(nfcTagId, date);
            if (result == -1) {
              onResult("${student.name} already marked today", false);
            } else {
              onResult("Marked Present: ${student.name}", false);
            }
          }
        } catch (e) {
          onResult("Error: $e", true);
        }
      },
    );
  }

  /// Listens for a single tag and returns the text stored on it
  Future<void> listenForTagID({
    required Function(String rfid) onRead,
    required Function(String error) onError,
  }) async {
    NfcAvailability availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      onError("NFC not available");
      return;
    }

    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        try {
          String? tagText = _readNdefText(tag);
          if (tagText != null && tagText.isNotEmpty) {
            await NfcManager.instance.stopSession();
            onRead(tagText.trim().toUpperCase());
          } else {
            onError("No text found on NFC card");
          }
        } catch (e) {
          onError("Scanning error: $e");
        }
      },
    );
  }

  /// Reads the NDEF text record from the NFC tag
  String? _readNdefText(NfcTag tag) {
    try {
      Ndef? ndef = Ndef.from(tag);
      if (ndef == null) return null;

      NdefMessage? cachedMessage = ndef.cachedMessage;
      if (cachedMessage == null) return null;

      for (NdefRecord record in cachedMessage.records) {
        // Check for Text Record (TNF=1 is nfcWellknown, type "T" is [0x54])
        if (record.typeNameFormat == TypeNameFormat.wellKnown) {
          if (record.type.isNotEmpty && record.type[0] == 0x54) {
            final payload = record.payload;
            if (payload.isNotEmpty) {
              // First byte: status byte (bit 7 = encoding, bits 5-0 = lang code length)
              final langCodeLength = payload[0] & 0x3F;
              if (payload.length > 1 + langCodeLength) {
                return utf8.decode(payload.sublist(1 + langCodeLength));
              }
            }
          }
        } 
        // Also check for media records (TNF=2, text/plain)
        else if (record.typeNameFormat == TypeNameFormat.media) {
          final typeString = String.fromCharCodes(record.type).toLowerCase();
          if (typeString == 'text/plain') {
            return utf8.decode(record.payload);
          }
        }
      }
    } catch (_) {
      // In case of any unexpected structure
    }
    return null;
  }

  Future<void> stopNfcSession() async {
    await NfcManager.instance.stopSession();
  }
}

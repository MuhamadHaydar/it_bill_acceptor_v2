import 'dart:typed_data';

import '../models/ssp_command.dart';
import '../utils/commands.dart';
import 'encyption_service.dart';
import 'serial_service.dart';

class ESSPProtocol {
  final SerialService _serialService;
  SSPKeys? _keys;
  bool _encryptionEnabled = false;

  ESSPProtocol(this._serialService);

  bool sendCommand(SSPCommand command, SSPCommandInfo info) {
    try {
      _addLog(
        '📤 Sending command: ${command.commandData[0].toRadixString(16).padLeft(2, '0')}',
      );

      // Build packet
      final packet = _buildPacket(command);
      _addLog(
        '📦 Built packet (${packet.length} bytes): ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );

      // Log transmitted data
      info.transmittedData.setRange(0, packet.length, packet);
      info.transmittedLength = packet.length;
      info.timestamp = DateTime.now();

      // Send packet
      if (!_serialService.writeData(packet)) {
        _addLog('❌ Failed to write packet to serial port');
        return false;
      }
      _addLog('✅ Packet sent successfully');

      // Read response with timeout
      _addLog('📥 Waiting for response...');
      final response = _readResponse();
      if (response == null) {
        _addLog('❌ No response received from device');
        return false;
      }

      _addLog(
        '📥 Received response (${response.length} bytes): ${response.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );

      // Log received data
      info.receivedData.setRange(0, response.length, response);
      info.receivedLength = response.length;

      // Parse response
      final parseResult = _parseResponse(response, command);
      if (parseResult) {
        _addLog('✅ Response parsed successfully');
        if (command.responseDataLength > 0) {
          _addLog(
            '📋 Response data: ${command.responseData.take(command.responseDataLength).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
          );
        }
      } else {
        _addLog('❌ Failed to parse response');
      }

      return parseResult;
    } catch (e) {
      _addLog('💥 sendCommand exception: $e');
      return false;
    }
  }

  // Add a method to add logs from protocol (you'll need to pass the validator service reference)
  void _addLog(String message) {
    print('ESSP: $message'); // Console output
    // If you have access to ValidatorService, also call its _addLog method
  }

  Uint8List _buildPacket(SSPCommand command) {
    final packet = Uint8List(command.commandDataLength + 5);
    int index = 0;

    // STX
    packet[index++] = 0x7F;

    // Sequence/sync bit (simplified)
    packet[index++] = 0x80;

    // Length
    packet[index++] = command.commandDataLength;

    // Data
    for (int i = 0; i < command.commandDataLength; i++) {
      packet[index++] = command.commandData[i];
    }

    // Encrypt data if encryption is enabled
    if (_encryptionEnabled && _keys != null && command.commandDataLength > 0) {
      final dataToEncrypt = Uint8List.sublistView(
        command.commandData,
        0,
        command.commandDataLength,
      );
      final encryptedData = EncryptionService.encryptData(
        dataToEncrypt,
        _keys!,
      );

      for (int i = 0; i < encryptedData.length; i++) {
        packet[3 + i] = encryptedData[i];
      }
    }

    // CRC (simplified - use proper CRC16 in production)
    final crc = _calculateCRC(packet, packet.length - 2);
    packet[index++] = crc & 0xFF;
    packet[index] = (crc >> 8) & 0xFF;

    return packet;
  }

  Uint8List? _readResponse() {
    // Read with timeout
    for (int attempt = 0; attempt < 10; attempt++) {
      final data = _serialService.readData(255);
      if (data != null && data.isNotEmpty) {
        return data;
      }
      // Small delay before retry
      Future.delayed(const Duration(milliseconds: 10));
    }
    return null;
  }

  bool _parseResponse(Uint8List response, SSPCommand command) {
    if (response.length < 5) return false;

    // Extract length
    final length = response[2];
    if (response.length < length + 5) return false;

    // Extract data
    command.responseDataLength = length;
    for (int i = 0; i < length; i++) {
      command.responseData[i] = response[3 + i];
    }

    // Decrypt if needed
    if (_encryptionEnabled && _keys != null && length > 0) {
      final encryptedData = Uint8List.sublistView(
        command.responseData,
        0,
        length,
      );
      final decryptedData = EncryptionService.decryptData(
        encryptedData,
        _keys!,
      );

      for (int i = 0; i < decryptedData.length; i++) {
        command.responseData[i] = decryptedData[i];
      }
    }

    return true;
  }

  int _calculateCRC(Uint8List data, int length) {
    int crc = 0xFFFF;
    for (int i = 0; i < length; i++) {
      crc ^= data[i];
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0x8408;
        } else {
          crc >>= 1;
        }
      }
    }
    return (~crc) & 0xFFFF;
  }

  bool negotiateKeys(SSPCommand command) {
    _keys = SSPKeys();

    // Step 1: Send SYNC
    command.reset();
    command.commandData[0] = Commands.SSP_CMD_SYNC;
    command.commandDataLength = 1;

    final info = SSPCommandInfo();
    if (!sendCommand(command, info)) return false;

    // Step 2: Initialize keys
    EncryptionService.initiateSSPHostKeys(_keys!, command);

    // Step 3: Send generator
    command.reset();
    command.commandData[0] = Commands.SSP_CMD_SET_GENERATOR;
    command.commandDataLength = 9;
    _setIntToCommand(command.commandData, 1, _keys!.generator);

    if (!sendCommand(command, info)) return false;

    // Step 4: Send modulus
    command.reset();
    command.commandData[0] = Commands.SSP_CMD_SET_MODULUS;
    command.commandDataLength = 9;
    _setIntToCommand(command.commandData, 1, _keys!.modulus);

    if (!sendCommand(command, info)) return false;

    // Step 5: Key exchange
    command.reset();
    command.commandData[0] = Commands.SSP_CMD_REQUEST_KEY_EXCHANGE;
    command.commandDataLength = 9;
    _setIntToCommand(command.commandData, 1, _keys!.hostInter);

    if (!sendCommand(command, info)) return false;

    // Step 6: Extract slave key and create final key
    _keys!.slaveInterKey = _getIntFromCommand(command.responseData, 1);
    EncryptionService.createSSPHostEncryptionKey(_keys!);

    _encryptionEnabled = true;
    return true;
  }

  void _setIntToCommand(Uint8List data, int offset, int value) {
    for (int i = 0; i < 8; i++) {
      data[offset + i] = (value >> (i * 8)) & 0xFF;
    }
  }

  int _getIntFromCommand(Uint8List data, int offset) {
    int value = 0;
    for (int i = 0; i < 8; i++) {
      value |= (data[offset + i] << (i * 8));
    }
    return value;
  }

  void enableEncryption() {
    _encryptionEnabled = true;
  }

  void disableEncryption() {
    _encryptionEnabled = false;
  }
}

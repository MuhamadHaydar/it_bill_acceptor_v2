import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:typed_data';
import '../models/ssp_command.dart';
import '../models/channel_data.dart';
import '../utils/commands.dart';
import '../utils/helpers.dart';
import 'serial_service.dart';
import 'essp_protocol.dart';

class ValidatorService extends ChangeNotifier {
  final SerialService _serialService = SerialService();
  late ESSPProtocol _protocol;
  Timer? _pollTimer;

  // State variables
  bool _isConnected = false;
  bool _isPolling = false;
  String _currentPort = '';
  int _sspAddress = 0;
  int _notesAccepted = 0;
  bool _holdInEscrow = false;
  int _holdCount = 0;
  int _holdNumber = 10;
  bool _noteHeld = false;

  // Device info
  String _unitType = '';
  String _firmwareVersion = '';
  String _serialNumber = '';
  int _protocolVersion = 0;
  int _numberOfChannels = 0;
  int _valueMultiplier = 1;
  List<ChannelData> _channels = [];

  // Logging
  final List<String> _logMessages = [];
  final List<SSPCommandInfo> _commandHistory = [];

  // Getters
  bool get isConnected => _isConnected;
  bool get isPolling => _isPolling;
  String get currentPort => _currentPort;
  int get notesAccepted => _notesAccepted;
  bool get holdInEscrow => _holdInEscrow;
  bool get noteHeld => _noteHeld;
  String get unitType => _unitType;
  String get firmwareVersion => _firmwareVersion;
  String get serialNumber => _serialNumber;
  int get protocolVersion => _protocolVersion;
  List<ChannelData> get channels => List.unmodifiable(_channels);
  List<String> get logMessages => List.unmodifiable(_logMessages);
  List<SSPCommandInfo> get commandHistory => List.unmodifiable(_commandHistory);

  ValidatorService() {
    _protocol = ESSPProtocol(_serialService);
  }

  void _addLog(String message) {
    _logMessages.add('${DateTime.now().toLocal()}: $message');
    if (_logMessages.length > 1000) {
      _logMessages.removeAt(0);
    }
    notifyListeners();
  }

  Future<bool> connect(String portName, int sspAddress) async {
    try {
      _addLog('Attempting to connect to $portName...');

      if (!_serialService.openPort(portName)) {
        _addLog('Failed to open COM port $portName');
        return false;
      }

      _currentPort = portName;
      _sspAddress = sspAddress;

      // Negotiate encryption keys
      final command = SSPCommand();
      command.comPort = portName;
      command.sspAddress = sspAddress;
      command.timeout = 3000;

      _protocol.disableEncryption();

      if (!_protocol.negotiateKeys(command)) {
        _addLog('Failed to negotiate encryption keys');
        disconnect();
        return false;
      }

      _protocol.enableEncryption();
      command.encryptionStatus = true;

      // Get device information
      if (!await _setupDevice(command)) {
        _addLog('Failed to setup device');
        disconnect();
        return false;
      }

      _isConnected = true;
      _addLog('Successfully connected to validator');
      notifyListeners();
      return true;
    } catch (e) {
      _addLog('Connection error: $e');
      disconnect();
      return false;
    }
  }

  Future<bool> _setupDevice(SSPCommand command) async {
    try {
      // Find maximum protocol version
      int maxVersion = await _findMaxProtocolVersion(command);
      if (maxVersion < 6) {
        _addLog('Protocol version $maxVersion not supported (minimum 6)');
        return false;
      }

      // Set protocol version
      if (!await _setProtocolVersion(command, maxVersion)) {
        return false;
      }

      // Get device setup information
      if (!await _getSetupRequest(command)) {
        return false;
      }

      // Get serial number
      if (!await _getSerialNumber(command)) {
        return false;
      }

      // Set inhibits (enable all channels)
      if (!await _setInhibits(command)) {
        return false;
      }

      // Enable validator
      if (!await _enableValidator(command)) {
        return false;
      }

      return true;
    } catch (e) {
      _addLog('Setup error: $e');
      return false;
    }
  }

  Future<int> _findMaxProtocolVersion(SSPCommand command) async {
    for (int version = 6; version <= 20; version++) {
      command.reset();
      command.commandData[0] = Commands.SSP_CMD_HOST_PROTOCOL_VERSION;
      command.commandData[1] = version;
      command.commandDataLength = 2;

      final info = SSPCommandInfo();
      if (_protocol.sendCommand(command, info)) {
        if (command.responseData[0] == Commands.SSP_RESPONSE_FAIL) {
          return version - 1;
        }
      }
    }
    return 6; // Default fallback
  }

  Future<bool> _setProtocolVersion(SSPCommand command, int version) async {
    command.reset();
    command.commandData[0] = Commands.SSP_CMD_HOST_PROTOCOL_VERSION;
    command.commandData[1] = version;
    command.commandDataLength = 2;

    final info = SSPCommandInfo();
    if (_protocol.sendCommand(command, info)) {
      _commandHistory.add(info);
      if (command.responseData[0] == Commands.SSP_RESPONSE_OK) {
        _protocolVersion = version;
        _addLog('Protocol version set to $version');
        return true;
      }
    }
    return false;
  }

  Future<bool> _getSetupRequest(SSPCommand command) async {
    command.reset();
    command.commandData[0] = Commands.SSP_CMD_SETUP_REQUEST;
    command.commandDataLength = 1;

    final info = SSPCommandInfo();
    if (_protocol.sendCommand(command, info)) {
      _commandHistory.add(info);
      if (command.responseData[0] == Commands.SSP_RESPONSE_OK) {
        _parseSetupResponse(command.responseData);
        return true;
      }
    }
    return false;
  }

  void _parseSetupResponse(Uint8List data) {
    int index = 1;

    // Unit type
    final unitTypeCode = data[index++];
    _unitType = _getUnitTypeName(unitTypeCode);

    // Firmware version
    _firmwareVersion = String.fromCharCode(data[index++]) +
        String.fromCharCode(data[index++]) + '.' +
        String.fromCharCode(data[index++]) +
        String.fromCharCode(data[index++]);

    // Skip legacy data
    index += 6; // country code + value multiplier

    // Number of channels
    _numberOfChannels = data[index++];

    // Skip channel values and security
    index += _numberOfChannels * 2;

    // Real value multiplier (big endian)
    _valueMultiplier = data[index + 2] + (data[index + 1] << 8) + (data[index] << 16);
    index += 3;

    // Protocol version
    _protocolVersion = data[index++];

    // Parse channel data
    _channels.clear();
    for (int i = 0; i < _numberOfChannels; i++) {
      final channel = i + 1;

      // Channel value (4 bytes, little endian)
      final valueOffset = index + (_numberOfChannels * 3) + (i * 4);
      final value = Helpers.bytesToInt32(data, valueOffset) * _valueMultiplier;

      // Channel currency (3 chars)
      final currencyOffset = index + (i * 3);
      final currency = String.fromCharCode(data[currencyOffset]) +
          String.fromCharCode(data[currencyOffset + 1]) +
          String.fromCharCode(data[currencyOffset + 2]);

      _channels.add(ChannelData(
        channel: channel,
        value: value,
        currency: currency,
      ));
    }

    // Sort channels by value
    _channels.sort((a, b) => a.value.compareTo(b.value));

    _addLog('Device setup: $_unitType, FW: $_firmwareVersion, Channels: $_numberOfChannels');
    for (final channel in _channels) {
      _addLog(channel.toString());
    }
  }

  String _getUnitTypeName(int typeCode) {
    switch (typeCode) {
      case 0x00: return 'Validator';
      case 0x03: return 'SMART Hopper';
      case 0x06: return 'SMART Payout';
      case 0x07: return 'NV11';
      case 0x0D: return 'TEBS';
      default: return 'Unknown Type ($typeCode)';
    }
  }

  Future<bool> _getSerialNumber(SSPCommand command) async {
    command.reset();
    command.commandData[0] = Commands.SSP_CMD_GET_SERIAL_NUMBER;
    command.commandDataLength = 1;

    final info = SSPCommandInfo();
    if (_protocol.sendCommand(command, info)) {
      _commandHistory.add(info);
      if (command.responseData[0] == Commands.SSP_RESPONSE_OK) {
        // Response data is big endian, so reverse bytes 1 to 4
        final serialBytes = Uint8List.sublistView(command.responseData, 1, 5);
        final reversedBytes = Uint8List.fromList(serialBytes.reversed.toList());
        _serialNumber = Helpers.bytesToInt32(reversedBytes, 0).toString();
        _addLog('Serial Number: $_serialNumber');
        return true;
      }
    }
    return false;
  }

  Future<bool> _setInhibits(SSPCommand command) async {
    command.reset();
    command.commandData[0] = Commands.SSP_CMD_SET_CHANNEL_INHIBITS;
    command.commandData[1] = 0xFF; // Enable all channels
    command.commandData[2] = 0xFF;
    command.commandDataLength = 3;

    final info = SSPCommandInfo();
    if (_protocol.sendCommand(command, info)) {
      _commandHistory.add(info);
      if (command.responseData[0] == Commands.SSP_RESPONSE_OK) {
        _addLog('Channel inhibits set');
        return true;
      }
    }
    return false;
  }

  Future<bool> _enableValidator(SSPCommand command) async {
    command.reset();
    command.commandData[0] = Commands.SSP_CMD_ENABLE;
    command.commandDataLength = 1;

    final info = SSPCommandInfo();
    if (_protocol.sendCommand(command, info)) {
      _commandHistory.add(info);
      if (command.responseData[0] == Commands.SSP_RESPONSE_OK) {
        _addLog('Validator enabled');
        return true;
      }
    }
    return false;
  }

  void startPolling() {
    if (!_isConnected || _isPolling) return;

    _isPolling = true;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      _doPoll();
    });

    _addLog('Started polling loop');
    notifyListeners();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
    _addLog('Stopped polling loop');
    notifyListeners();
  }

  Future<void> _doPoll() async {
    if (!_isConnected) return;

    try {
      final command = SSPCommand();
      command.comPort = _currentPort;
      command.sspAddress = _sspAddress;
      command.timeout = 3000;
      command.encryptionStatus = true;

      // Handle escrow holding
      if (_holdCount > 0) {
        _noteHeld = true;
        _holdCount--;
        command.reset();
        command.commandData[0] = Commands.SSP_CMD_HOLD;
        command.commandDataLength = 1;

        final info = SSPCommandInfo();
        if (_protocol.sendCommand(command, info)) {
          _commandHistory.add(info);
          _addLog('Note held in escrow: $_holdCount polls remaining');
        }
        notifyListeners();
        return;
      }

      // Send poll command
      command.reset();
      command.commandData[0] = Commands.SSP_CMD_POLL;
      command.commandDataLength = 1;
      _noteHeld = false;

      final info = SSPCommandInfo();
      if (!_protocol.sendCommand(command, info)) {
        _addLog('Poll command failed - attempting reconnection');
        await _handleConnectionFailure();
        return;
      }

      _commandHistory.add(info);

      // Process poll response
      await _processPollResponse(command.responseData, command.responseDataLength);

    } catch (e) {
      _addLog('Poll error: $e');
      await _handleConnectionFailure();
    }
  }

  Future<void> _processPollResponse(Uint8List data, int length) async {
    for (int i = 1; i < length; i++) {
      switch (data[i]) {
        case Commands.SSP_POLL_SLAVE_RESET:
          _addLog('Unit reset');
          break;

        case Commands.SSP_POLL_READ_NOTE:
          if (i + 1 < length && data[i + 1] > 0) {
            final channelData = _getChannelData(data[i + 1]);
            if (channelData != null) {
              _addLog('Note in escrow: ${Helpers.formatToCurrency(channelData.value)} ${channelData.currency}');
              if (_holdInEscrow) {
                _holdCount = _holdNumber;
              }
            }
          } else {
            _addLog('Reading note...');
          }
          i++; // Skip channel byte
          break;

        case Commands.SSP_POLL_CREDIT_NOTE:
          if (i + 1 < length) {
            final channelData = _getChannelData(data[i + 1]);
            if (channelData != null) {
              _addLog('Credit: ${Helpers.formatToCurrency(channelData.value)} ${channelData.currency}');
              _notesAccepted++;
              notifyListeners();
            }
          }
          i++; // Skip channel byte
          break;

        case Commands.SSP_POLL_NOTE_REJECTING:
          _addLog('Rejecting note...');
          break;

        case Commands.SSP_POLL_NOTE_REJECTED:
          _addLog('Note rejected');
          await _queryRejection();
          break;

        case Commands.SSP_POLL_NOTE_STACKING:
          _addLog('Stacking note...');
          break;

        case Commands.SSP_POLL_NOTE_STACKED:
          _addLog('Note stacked');
          break;

        case Commands.SSP_POLL_SAFE_NOTE_JAM:
          _addLog('Safe jam detected');
          break;

        case Commands.SSP_POLL_UNSAFE_NOTE_JAM:
          _addLog('Unsafe jam detected');
          break;

        case Commands.SSP_POLL_DISABLED:
        // Validator is disabled - don't log this as it's normal
          break;

        case Commands.SSP_POLL_FRAUD_ATTEMPT:
          if (i + 1 < length) {
            final channelData = _getChannelData(data[i + 1]);
            final value = channelData?.value ?? 0;
            _addLog('Fraud attempt detected on note value: ${Helpers.formatToCurrency(value)}');
          }
          i++; // Skip channel byte
          break;

        case Commands.SSP_POLL_STACKER_FULL:
          _addLog('Stacker full');
          break;

        case Commands.SSP_POLL_NOTE_CLEARED_FROM_FRONT:
          if (i + 1 < length) {
            final channelData = _getChannelData(data[i + 1]);
            if (channelData != null) {
              _addLog('${Helpers.formatToCurrency(channelData.value)} note cleared from front at reset');
            }
          }
          i++; // Skip channel byte
          break;

        case Commands.SSP_POLL_NOTE_CLEARED_TO_CASHBOX:
          if (i + 1 < length) {
            final channelData = _getChannelData(data[i + 1]);
            if (channelData != null) {
              _addLog('${Helpers.formatToCurrency(channelData.value)} note cleared to stacker at reset');
            }
          }
          i++; // Skip channel byte
          break;

        case Commands.SSP_POLL_CASHBOX_REMOVED:
          _addLog('Cashbox removed...');
          break;

        case Commands.SSP_POLL_CASHBOX_REPLACED:
          _addLog('Cashbox replaced');
          break;

        case Commands.SSP_POLL_NOTE_PATH_OPEN:
          _addLog('Note path open');
          break;

        case Commands.SSP_POLL_CHANNEL_DISABLE:
          _addLog('All channels inhibited, unit disabled');
          break;

        default:
          _addLog('Unrecognized poll response: ${data[i]}');
          break;
      }
    }
  }

  ChannelData? _getChannelData(int channelNumber) {
    try {
      return _channels.firstWhere((channel) => channel.channel == channelNumber);
    } catch (e) {
      return null;
    }
  }

  Future<void> _queryRejection() async {
    try {
      final command = SSPCommand();
      command.comPort = _currentPort;
      command.sspAddress = _sspAddress;
      command.timeout = 3000;
      command.encryptionStatus = true;

      command.reset();
      command.commandData[0] = Commands.SSP_CMD_LAST_REJECT_CODE;
      command.commandDataLength = 1;

      final info = SSPCommandInfo();
      if (_protocol.sendCommand(command, info)) {
        _commandHistory.add(info);
        if (command.responseData[0] == Commands.SSP_RESPONSE_OK &&
            command.responseDataLength > 1) {
          final rejectionReason = _getRejectionReason(command.responseData[1]);
          _addLog('Rejection reason: $rejectionReason');
        }
      }
    } catch (e) {
      _addLog('Failed to query rejection reason: $e');
    }
  }

  String _getRejectionReason(int code) {
    switch (code) {
      case 0x00: return 'Note accepted';
      case 0x01: return 'Note length incorrect';
      case 0x02: return 'Invalid note';
      case 0x03: return 'Invalid note';
      case 0x04: return 'Invalid note';
      case 0x05: return 'Invalid note';
      case 0x06: return 'Channel inhibited';
      case 0x07: return 'Second note inserted during read';
      case 0x08: return 'Host rejected note';
      case 0x09: return 'Invalid note';
      case 0x0A: return 'Invalid note read';
      case 0x0B: return 'Note too long';
      case 0x0C: return 'Validator disabled';
      case 0x0D: return 'Mechanism slow/stalled';
      case 0x0E: return 'Strim attempt';
      case 0x0F: return 'Fraud channel reject';
      case 0x10: return 'No notes inserted';
      case 0x11: return 'Invalid note read';
      case 0x12: return 'Twisted note detected';
      case 0x13: return 'Escrow time-out';
      case 0x14: return 'Bar code scan fail';
      case 0x15: return 'Invalid note read';
      case 0x16: return 'Invalid note read';
      case 0x17: return 'Invalid note read';
      case 0x18: return 'Invalid note read';
      case 0x19: return 'Incorrect note width';
      case 0x1A: return 'Note too short';
      default: return 'Unknown rejection code: $code';
    }
  }

  Future<void> _handleConnectionFailure() async {
    _addLog('Connection lost - attempting to reconnect...');
    stopPolling();

    // Try to reconnect
    final reconnected = await connect(_currentPort, _sspAddress);
    if (reconnected) {
      _addLog('Reconnected successfully');
      startPolling();
    } else {
      _addLog('Failed to reconnect');
      disconnect();
    }
  }

  Future<void> resetValidator() async {
    if (!_isConnected) return;

    try {
      final command = SSPCommand();
      command.comPort = _currentPort;
      command.sspAddress = _sspAddress;
      command.timeout = 3000;
      command.encryptionStatus = true;

      command.reset();
      command.commandData[0] = Commands.SSP_CMD_RESET;
      command.commandDataLength = 1;

      final info = SSPCommandInfo();
      if (_protocol.sendCommand(command, info)) {
        _commandHistory.add(info);
        _addLog('Validator reset command sent');
      }
    } catch (e) {
      _addLog('Reset failed: $e');
    }
  }

  Future<void> returnNote() async {
    if (!_isConnected || !_noteHeld) return;

    try {
      final command = SSPCommand();
      command.comPort = _currentPort;
      command.sspAddress = _sspAddress;
      command.timeout = 3000;
      command.encryptionStatus = true;

      command.reset();
      command.commandData[0] = Commands.SSP_CMD_REJECT_BANKNOTE;
      command.commandDataLength = 1;

      final info = SSPCommandInfo();
      if (_protocol.sendCommand(command, info)) {
        _commandHistory.add(info);
        if (command.responseData[0] == Commands.SSP_RESPONSE_OK) {
          _addLog('Returning note');
          _holdCount = 0;
          _noteHeld = false;
          notifyListeners();
        }
      }
    } catch (e) {
      _addLog('Return note failed: $e');
    }
  }

  void setHoldInEscrow(bool hold) {
    _holdInEscrow = hold;
    _holdNumber = hold ? 10 : 0;
    _addLog(hold ? 'Hold in escrow enabled' : 'Hold in escrow disabled');
    notifyListeners();
  }

  void clearNoteCount() {
    _notesAccepted = 0;
    _addLog('Note count cleared');
    notifyListeners();
  }

  void clearLog() {
    _logMessages.clear();
    _addLog('Log cleared');
    notifyListeners();
  }

  void disconnect() {
    stopPolling();
    _serialService.closePort();
    _isConnected = false;
    _currentPort = '';
    _sspAddress = 0;
    _unitType = '';
    _firmwareVersion = '';
    _serialNumber = '';
    _protocolVersion = 0;
    _numberOfChannels = 0;
    _valueMultiplier = 1;
    _channels.clear();
    _noteHeld = false;
    _holdCount = 0;

    _addLog('Disconnected from validator');
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class PortInfo {
  final String name;
  final String description;
  final bool isAvailable;
  final String? friendlyName;

  PortInfo({
    required this.name,
    this.description = '',
    this.isAvailable = false,
    this.friendlyName,
  });

  @override
  String toString() {
    if (friendlyName != null && friendlyName!.isNotEmpty) {
      return '$name ($friendlyName)';
    }
    return description.isNotEmpty ? '$name - $description' : name;
  }
}

class SerialService {
  int? _handle;
  String? _portName;
  bool _isOpen = false;

  /// Get all available COM ports with detailed information
  static List<PortInfo> getAvailablePortsWithInfo() {
    List<PortInfo> ports = [];

    // Scan COM1 to COM256 for available ports
    for (int i = 1; i <= 256; i++) {
      final portName = 'COM$i';
      final isAvailable = _testPortAvailability(portName);

      if (isAvailable) {
        ports.add(PortInfo(
          name: portName,
          description: 'Serial Port',
          isAvailable: true,
        ));
      } else {
        // Also add unavailable ports so user can see them
        ports.add(PortInfo(
          name: portName,
          description: 'Serial Port (Not Available)',
          isAvailable: false,
        ));
      }
    }

    return ports;
  }

  /// Simple method that returns just available port names
  static List<String> getAvailablePorts() {
    return getAvailablePortsWithInfo()
        .where((port) => port.isAvailable)
        .map((port) => port.name)
        .toList();
  }

  /// Test if a COM port is available by trying to open it
  static bool _testPortAvailability(String portName) {
    // For COM ports 10 and above, use the \\.\\ prefix
    final devicePath = int.parse(portName.replaceAll('COM', '')) >= 10
        ? '\\\\.\\$portName'
        : portName;

    final pcCommPort = devicePath.toNativeUtf16();

    try {
      final handle = CreateFile(
        pcCommPort,
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        NULL,
      );

      if (handle != INVALID_HANDLE_VALUE) {
        // Test if we can get comm state (validates it's a real serial port)
        final dcb = calloc<DCB>();
        dcb.ref.DCBlength = sizeOf<DCB>();

        final success = GetCommState(handle, dcb);

        free(dcb);
        CloseHandle(handle);
        free(pcCommPort);

        return success != 0;
      }
    } catch (e) {
      print('Error testing port $portName: $e');
    }

    free(pcCommPort);
    return false;
  }

  /// Open a COM port with specified settings
  bool openPort(String portName, {
    int baudRate = 9600,
    int dataBits = 8,
    int stopBits = ONESTOPBIT,
    int parity = NOPARITY,
  }) {
    if (_isOpen) closePort();

    // For COM ports 10 and above, use the \\.\\ prefix
    final devicePath = int.parse(portName.replaceAll('COM', '')) >= 10
        ? '\\\\.\\$portName'
        : portName;

    final pcCommPort = devicePath.toNativeUtf16();
    final dcb = calloc<DCB>();

    try {
      print('Attempting to open $portName (using path: $devicePath)...');

      _handle = CreateFile(
        pcCommPort,
        GENERIC_READ | GENERIC_WRITE,
        0,
        // No sharing
        nullptr,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        NULL,
      );

      if (_handle == INVALID_HANDLE_VALUE) {
        final errorCode = GetLastError();
        print('Failed to open $portName - Error Code: $errorCode');
        print('Error Description: ${_getErrorMessage(errorCode)}');
        return false;
      }

      // Get current DCB settings
      dcb.ref.DCBlength = sizeOf<DCB>();

      if (GetCommState(_handle!, dcb) == 0) {
        final errorCode = GetLastError();
        print('GetCommState failed for $portName - Error: $errorCode');
        closePort();
        return false;
      }

      // Configure only the available DCB settings
      dcb.ref.BaudRate = baudRate;
      dcb.ref.ByteSize = dataBits;
      dcb.ref.StopBits = stopBits;
      dcb.ref.Parity = parity;

      if (SetCommState(_handle!, dcb) == 0) {
        final errorCode = GetLastError();
        print('SetCommState failed for $portName - Error: $errorCode');
        closePort();
        return false;
      }

      // Set timeouts
      final timeouts = calloc<COMMTIMEOUTS>();
      timeouts.ref.ReadIntervalTimeout = 50;
      timeouts.ref.ReadTotalTimeoutConstant = 1000;
      timeouts.ref.ReadTotalTimeoutMultiplier = 10;
      timeouts.ref.WriteTotalTimeoutConstant = 1000;
      timeouts.ref.WriteTotalTimeoutMultiplier = 10;

      if (SetCommTimeouts(_handle!, timeouts) == 0) {
        final errorCode = GetLastError();
        print('SetCommTimeouts failed for $portName - Error: $errorCode');
        free(timeouts);
        closePort();
        return false;
      }

      free(timeouts);

      _portName = portName;
      _isOpen = true;

      print('Successfully opened $portName');
      print('Settings: $baudRate baud, $dataBits data bits, '
          '${parity == NOPARITY ? "No" : "Even/Odd"} parity, '
          '${stopBits == ONESTOPBIT ? "1" : "2"} stop bits');

      return true;
    } catch (e) {
      print('Exception opening port $portName: $e');
      closePort();
      return false;
    } finally {
      free(pcCommPort);
      free(dcb);
    }
  }

  String _getErrorMessage(int errorCode) {
    switch (errorCode) {
      case ERROR_FILE_NOT_FOUND:
        return 'The system cannot find the file specified. (Port may not exist)';
      case ERROR_ACCESS_DENIED:
        return 'Access is denied. (Port may be in use by another application or requires admin rights)';
      case ERROR_SHARING_VIOLATION:
        return 'The process cannot access the file because it is being used by another process.';
      case ERROR_INVALID_HANDLE:
        return 'The handle is invalid.';
      case ERROR_INVALID_PARAMETER:
        return 'The parameter is incorrect.';
      case ERROR_NOT_READY:
        return 'The device is not ready.';
      case ERROR_DEV_NOT_EXIST:
        return 'The specified device does not exist.';
      case ERROR_BAD_COMMAND:
        return 'The device does not recognize the command.';
      default:
        return 'Unknown error code: $errorCode';
    }
  }

  /// Write data to the serial port
  bool writeData(Uint8List data) {
    if (!_isOpen || _handle == null) {
      print('Port not open for writing');
      return false;
    }

    final dataPtr = calloc<Uint8>(data.length);
    final bytesWritten = calloc<Uint32>();

    try {
      // Copy data to native memory
      for (int i = 0; i < data.length; i++) {
        dataPtr[i] = data[i];
      }

      final result = WriteFile(
        _handle!,
        dataPtr,
        data.length,
        bytesWritten,
        nullptr,
      );

      final success = result != 0 && bytesWritten.value == data.length;

      if (!success) {
        final error = GetLastError();
        print('WriteFile failed. Error code: $error, '
            'Bytes written: ${bytesWritten.value}/${data.length}');
      }

      return success;
    } catch (e) {
      print('Exception writing data: $e');
      return false;
    } finally {
      free(dataPtr);
      free(bytesWritten);
    }
  }

  /// Read data from the serial port
  Uint8List? readData(int maxLength, {int timeoutMs = 1000}) {
    if (!_isOpen || _handle == null) {
      print('Port not open for reading');
      return null;
    }

    final buffer = calloc<Uint8>(maxLength);
    final bytesRead = calloc<Uint32>();

    try {
      final result = ReadFile(
        _handle!,
        buffer,
        maxLength,
        bytesRead,
        nullptr,
      );

      if (result == 0) {
        final error = GetLastError();
        if (error != ERROR_TIMEOUT && error != ERROR_IO_PENDING) {
          print('ReadFile failed. Error code: $error');
        }
        return null;
      }

      if (bytesRead.value == 0) {
        return null;
      }

      final data = Uint8List(bytesRead.value);
      for (int i = 0; i < bytesRead.value; i++) {
        data[i] = buffer[i];
      }

      return data;
    } catch (e) {
      print('Exception reading data: $e');
      return null;
    } finally {
      free(buffer);
      free(bytesRead);
    }
  }

  /// Close the serial port
  void closePort() {
    if (_handle != null && _handle != INVALID_HANDLE_VALUE) {
      CloseHandle(_handle!);
    }
    _handle = null;
    _portName = null;
    _isOpen = false;
  }

  /// Purge the serial port buffers
  bool purgePort() {
    if (!_isOpen || _handle == null) return false;

    return PurgeComm(_handle!,
        PURGE_TXABORT | PURGE_RXABORT | PURGE_TXCLEAR | PURGE_RXCLEAR) != 0;
  }

  /// Check if port is open
  bool get isOpen => _isOpen;

  /// Get current port name
  String? get portName => _portName;
}
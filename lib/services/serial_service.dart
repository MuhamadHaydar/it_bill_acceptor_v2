import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class SerialService {
  int? _handle;
  String? _portName;
  bool _isOpen = false;

  static List<String> getAvailablePorts() {
    List<String> ports = [];

    // Check COM1 to COM256
    for (int i = 1; i <= 256; i++) {
      String portName = 'COM$i';
      final portNamePtr = portName.toNativeUtf16();

      final handle = CreateFile(
        portNamePtr,
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        0,
      );

      if (handle != INVALID_HANDLE_VALUE) {
        ports.add(portName);
        CloseHandle(handle);
      }

      free(portNamePtr);
    }

    return ports;
  }

  bool openPort(String portName, {
    int baudRate = 9600,
    int dataBits = 8,
    int stopBits = ONESTOPBIT,
    int parity = NOPARITY,
  }) {
    if (_isOpen) closePort();

    final portNamePtr = portName.toNativeUtf16();

    _handle = CreateFile(
      portNamePtr,
      GENERIC_READ | GENERIC_WRITE,
      0,
      nullptr,
      OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL,
      0,
    );

    free(portNamePtr);

    if (_handle == INVALID_HANDLE_VALUE) {
      return false;
    }

    // Configure port settings
    final dcb = calloc<DCB>();
    dcb.ref.DCBlength = sizeOf<DCB>();

    if (GetCommState(_handle!, dcb) == 0) {
      free(dcb);
      closePort();
      return false;
    }

    dcb.ref.BaudRate = baudRate;
    dcb.ref.ByteSize = dataBits;
    dcb.ref.StopBits = stopBits;
    dcb.ref.Parity = parity;
    // Todo: The following flags can be set as needed
    // dcb.ref.fBinary = 1;
    // dcb.ref.fParity = 1;

    if (SetCommState(_handle!, dcb) == 0) {
      free(dcb);
      closePort();
      return false;
    }

    free(dcb);

    // Set timeouts
    final timeouts = calloc<COMMTIMEOUTS>();
    timeouts.ref.ReadIntervalTimeout = 50;
    timeouts.ref.ReadTotalTimeoutConstant = 1000;
    timeouts.ref.ReadTotalTimeoutMultiplier = 10;
    timeouts.ref.WriteTotalTimeoutConstant = 1000;
    timeouts.ref.WriteTotalTimeoutMultiplier = 10;

    if (SetCommTimeouts(_handle!, timeouts) == 0) {
      free(timeouts);
      closePort();
      return false;
    }

    free(timeouts);

    _portName = portName;
    _isOpen = true;
    return true;
  }

  bool writeData(Uint8List data) {
    if (!_isOpen || _handle == null) return false;

    final dataPtr = calloc<Uint8>(data.length);
    for (int i = 0; i < data.length; i++) {
      dataPtr[i] = data[i];
    }

    final bytesWritten = calloc<Uint32>();
    final result = WriteFile(
      _handle!,
      dataPtr,
      data.length,
      bytesWritten,
      nullptr,
    );

    final success = result != 0 && bytesWritten.value == data.length;

    free(dataPtr);
    free(bytesWritten);

    return success;
  }

  Uint8List? readData(int maxLength, {int timeoutMs = 1000}) {
    if (!_isOpen || _handle == null) return null;

    final buffer = calloc<Uint8>(maxLength);
    final bytesRead = calloc<Uint32>();

    final result = ReadFile(
      _handle!,
      buffer,
      maxLength,
      bytesRead,
      nullptr,
    );

    if (result == 0 || bytesRead.value == 0) {
      free(buffer);
      free(bytesRead);
      return null;
    }

    final data = Uint8List(bytesRead.value);
    for (int i = 0; i < bytesRead.value; i++) {
      data[i] = buffer[i];
    }

    free(buffer);
    free(bytesRead);

    return data;
  }

  void closePort() {
    if (_handle != null && _handle != INVALID_HANDLE_VALUE) {
      CloseHandle(_handle!);
    }
    _handle = null;
    _portName = null;
    _isOpen = false;
  }

  bool get isOpen => _isOpen;
  String? get portName => _portName;
}
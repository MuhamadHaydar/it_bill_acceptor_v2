import 'dart:typed_data';

class SSPCommand {
  Uint8List commandData = Uint8List(255);
  int commandDataLength = 0;
  Uint8List responseData = Uint8List(255);
  int responseDataLength = 0;
  String comPort = '';
  int sspAddress = 0;
  int timeout = 3000;
  bool encryptionStatus = false;
  SSPKeys? key;

  void reset() {
    commandDataLength = 0;
    responseDataLength = 0;
    commandData.fillRange(0, commandData.length, 0);
    responseData.fillRange(0, responseData.length, 0);
  }
}

class SSPKeys {
  int fixedKey = 0x0123456701234567;
  int variableKey = 0;
  int generator = 0;
  int modulus = 0;
  int hostInter = 0;
  int slaveInterKey = 0;
  int keyHost = 0;
}

class SSPCommandInfo {
  Uint8List transmittedData = Uint8List(255);
  Uint8List receivedData = Uint8List(255);
  int transmittedLength = 0;
  int receivedLength = 0;
  DateTime timestamp = DateTime.now();
}
class Commands {
  // Basic Commands
  static const int SSP_CMD_RESET = 0x01;
  static const int SSP_CMD_SET_CHANNEL_INHIBITS = 0x02;
  static const int SSP_CMD_DISPLAY_ON = 0x03;
  static const int SSP_CMD_DISPLAY_OFF = 0x04;
  static const int SSP_CMD_SETUP_REQUEST = 0x05;
  static const int SSP_CMD_HOST_PROTOCOL_VERSION = 0x06;
  static const int SSP_CMD_POLL = 0x07;
  static const int SSP_CMD_REJECT_BANKNOTE = 0x08;
  static const int SSP_CMD_DISABLE = 0x09;
  static const int SSP_CMD_ENABLE = 0x0A;
  static const int SSP_CMD_GET_SERIAL_NUMBER = 0x0C;
  static const int SSP_CMD_SYNC = 0x11;
  static const int SSP_CMD_LAST_REJECT_CODE = 0x17;
  static const int SSP_CMD_HOLD = 0x18;

  // Encryption Commands
  static const int SSP_CMD_SET_GENERATOR = 0x4A;
  static const int SSP_CMD_SET_MODULUS = 0x4B;
  static const int SSP_CMD_REQUEST_KEY_EXCHANGE = 0x4C;

  // Poll Responses
  static const int SSP_POLL_SLAVE_RESET = 0xF1;
  static const int SSP_POLL_READ_NOTE = 0xEF;
  static const int SSP_POLL_CREDIT_NOTE = 0xEE;
  static const int SSP_POLL_NOTE_REJECTING = 0xED;
  static const int SSP_POLL_NOTE_REJECTED = 0xEC;
  static const int SSP_POLL_NOTE_STACKING = 0xCC;
  static const int SSP_POLL_NOTE_STACKED = 0xEB;
  static const int SSP_POLL_SAFE_NOTE_JAM = 0xEA;
  static const int SSP_POLL_UNSAFE_NOTE_JAM = 0xE9;
  static const int SSP_POLL_DISABLED = 0xE8;
  static const int SSP_POLL_FRAUD_ATTEMPT = 0xE6;
  static const int SSP_POLL_STACKER_FULL = 0xE7;
  static const int SSP_POLL_NOTE_CLEARED_FROM_FRONT = 0xE1;
  static const int SSP_POLL_NOTE_CLEARED_TO_CASHBOX = 0xE2;
  static const int SSP_POLL_CASHBOX_REMOVED = 0xE3;
  static const int SSP_POLL_CASHBOX_REPLACED = 0xE4;
  static const int SSP_POLL_NOTE_PATH_OPEN = 0xE0;
  static const int SSP_POLL_CHANNEL_DISABLE = 0xB5;

  // Generic Responses
  static const int SSP_RESPONSE_OK = 0xF0;
  static const int SSP_RESPONSE_COMMAND_NOT_KNOWN = 0xF2;
  static const int SSP_RESPONSE_WRONG_NO_PARAMETERS = 0xF3;
  static const int SSP_RESPONSE_PARAMETER_OUT_OF_RANGE = 0xF4;
  static const int SSP_RESPONSE_COMMAND_CANNOT_BE_PROCESSED = 0xF5;
  static const int SSP_RESPONSE_SOFTWARE_ERROR = 0xF6;
  static const int SSP_RESPONSE_FAIL = 0xF8;
  static const int SSP_RESPONSE_KEY_NOT_SET = 0xFA;
}
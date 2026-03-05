enum PCCommandType {
  lock,
  restart,
  shutdown,
  message,
}

PCCommandType? commandFromString(String? value) {
  if (value == null) return null;

  switch (value.toLowerCase()) {
    case 'lock':
      return PCCommandType.lock;
    case 'restart':
      return PCCommandType.restart;
    case 'shutdown':
      return PCCommandType.shutdown;
    case 'message':
      return PCCommandType.message;
    default:
      return null;
  }
}

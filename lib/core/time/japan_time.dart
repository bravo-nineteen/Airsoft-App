class JapanTime {
  static const Duration _jstOffset = Duration(hours: 9);

  static DateTime now() {
    return DateTime.now().toUtc().add(_jstOffset);
  }

  static DateTime? parseServerTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    final String raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return null;
    }
    return parsed.toUtc().add(_jstOffset);
  }
}

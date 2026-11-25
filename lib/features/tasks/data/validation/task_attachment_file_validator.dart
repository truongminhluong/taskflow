final class TaskAttachmentValidationException implements Exception {
  const TaskAttachmentValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class TaskAttachmentFileValidator {
  static const maxSizeBytes = 5 * 1024 * 1024;

  static String validate({
    required int sizeBytes,
    required List<int> header,
  }) {
    if (sizeBytes <= 0) {
      throw const TaskAttachmentValidationException('Ảnh không có dữ liệu.');
    }
    if (sizeBytes > maxSizeBytes) {
      throw const TaskAttachmentValidationException(
        'Mỗi ảnh chỉ được tối đa 5 MB.',
      );
    }

    if (_startsWith(header, const [0xff, 0xd8, 0xff])) return 'image/jpeg';
    if (_startsWith(
      header,
      const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
    )) {
      return 'image/png';
    }
    if (_isWebp(header)) return 'image/webp';
    if (_isHeic(header)) {
      throw const TaskAttachmentValidationException(
        'Ảnh HEIC chưa được hỗ trợ. Hãy chọn ảnh JPEG, PNG hoặc WebP.',
      );
    }

    throw const TaskAttachmentValidationException(
      'Chỉ hỗ trợ ảnh JPEG, PNG hoặc WebP.',
    );
  }

  static bool _startsWith(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  static bool _isWebp(List<int> bytes) =>
      bytes.length >= 12 &&
      _matchesAscii(bytes, 0, 'RIFF') &&
      _matchesAscii(bytes, 8, 'WEBP');

  static bool _isHeic(List<int> bytes) {
    if (bytes.length < 12 ||
        !_matchesAscii(bytes, 4, 'ftyp')) {
      return false;
    }

    return const {'heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1'}.contains(
      String.fromCharCodes(bytes.sublist(8, 12)),
    );
  }

  static bool _matchesAscii(List<int> bytes, int offset, String value) =>
      bytes.length >= offset + value.length &&
      String.fromCharCodes(bytes.sublist(offset, offset + value.length)) ==
          value;
}

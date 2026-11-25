import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/data/validation/task_attachment_file_validator.dart';

void main() {
  test('accepts JPEG, PNG, and WebP signatures', () {
    expect(
      TaskAttachmentFileValidator.validate(
        sizeBytes: 3,
        header: Uint8List.fromList([0xff, 0xd8, 0xff]),
      ),
      'image/jpeg',
    );
    expect(
      TaskAttachmentFileValidator.validate(
        sizeBytes: 8,
        header: Uint8List.fromList([
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
        ]),
      ),
      'image/png',
    );
    expect(
      TaskAttachmentFileValidator.validate(
        sizeBytes: 12,
        header: Uint8List.fromList([
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x45,
          0x42,
          0x50,
        ]),
      ),
      'image/webp',
    );
  });

  test('rejects HEIC, unsupported content, empty files, and files over 5 MB', () {
    expect(
      () => TaskAttachmentFileValidator.validate(
        sizeBytes: 12,
        header: Uint8List.fromList([
          0,
          0,
          0,
          0,
          0x66,
          0x74,
          0x79,
          0x70,
          0x68,
          0x65,
          0x69,
          0x63,
        ]),
      ),
      throwsA(
        isA<TaskAttachmentValidationException>().having(
          (error) => error.message,
          'message',
          contains('HEIC'),
        ),
      ),
    );
    expect(
      () => TaskAttachmentFileValidator.validate(
        sizeBytes: 3,
        header: Uint8List.fromList([1, 2, 3]),
      ),
      throwsA(isA<TaskAttachmentValidationException>()),
    );
    expect(
      () => TaskAttachmentFileValidator.validate(
        sizeBytes: 0,
        header: Uint8List(0),
      ),
      throwsA(isA<TaskAttachmentValidationException>()),
    );
    expect(
      () => TaskAttachmentFileValidator.validate(
        sizeBytes: 5 * 1024 * 1024 + 1,
        header: Uint8List.fromList([0xff, 0xd8, 0xff]),
      ),
      throwsA(isA<TaskAttachmentValidationException>()),
    );
  });
}

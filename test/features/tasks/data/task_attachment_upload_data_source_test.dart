import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/network/api_client.dart';
import 'package:task_flow_v2/features/tasks/data/datasources/task_remote_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uploads a validated image as authenticated multipart data', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
    final directory = await Directory.systemTemp.createTemp('task-upload-');
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}/photo.png');
    await image.writeAsBytes(_pngSignature);
    final adapter = _UploadAdapter(
      responseData: {
        'name': 'photo.png',
        'url': 'https://cdn.example.test/photo.png',
        'publicId': 'taskflow/users/user/photo',
        'mimeType': 'image/png',
        'sizeBytes': _pngSignature.length,
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://taskflow.test/api'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);

    final attachment = await TaskRemoteDataSource(
      apiClient: ApiClient(
        dio: dio,
        storage: const FlutterSecureStorage(),
      ),
    ).uploadTaskAttachment(path: image.path, name: 'photo.png');

    expect(attachment.publicId, 'taskflow/users/user/photo');
    expect(attachment.mimeType, 'image/png');
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/uploads/task-attachments');
    expect(request.headers['Authorization'], startsWith('Bearer '));
    expect(request.contentType, startsWith('multipart/form-data'));
    final form = request.data as FormData;
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'photo.png');
    expect(form.files.single.value.contentType.toString(), 'image/png');
  });

  test('rejects unsupported image bytes before sending a request', () async {
    final directory = await Directory.systemTemp.createTemp('task-upload-');
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}/photo.png');
    await image.writeAsBytes([1, 2, 3, 4]);
    final adapter = _UploadAdapter(responseData: const {});
    final dio = Dio(BaseOptions(baseUrl: 'https://taskflow.test/api'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);

    await expectLater(
      TaskRemoteDataSource(
        apiClient: ApiClient(dio: dio),
      ).uploadTaskAttachment(path: image.path, name: 'photo.png'),
      throwsA(isA<Exception>()),
    );

    expect(adapter.requests, isEmpty);
  });
}

const _pngSignature = [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
];

final class _UploadAdapter implements HttpClientAdapter {
  _UploadAdapter({required this.responseData});

  final Map<String, Object?> responseData;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'data': responseData}),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:alcove/features/backup/tus_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A fake tus server keeping one upload in memory.
class FakeTus {
  final received = BytesBuilder();
  int length = 0;
  Map<String, String> metadata = {};
  int creations = 0;
  bool refuse = false;

  Future<http.Response> handle(http.Request req) async {
    expect(req.headers['Tus-Resumable'], '1.0.0');
    expect(req.headers['Authorization'], 'tok');
    switch (req.method) {
      case 'POST':
        if (refuse) return http.Response('{"message":"Not enough space."}', 413);
        creations++;
        length = int.parse(req.headers['Upload-Length']!);
        metadata = {
          for (final pair in req.headers['Upload-Metadata']!.split(','))
            pair.split(' ')[0]: utf8.decode(base64.decode(pair.split(' ')[1])),
        };
        return http.Response('', 201, headers: {'location': '/api/v1/uploads/abc'});
      case 'HEAD':
        return http.Response('', 200, headers: {'upload-offset': '${received.length}'});
      case 'PATCH':
        expect(int.parse(req.headers['Upload-Offset']!), received.length);
        received.add(req.bodyBytes);
        final done = received.length >= length;
        return http.Response(
          '',
          204,
          headers: {
            'upload-offset': '${received.length}',
            if (done) 'alcove-node-id': 'node42',
          },
        );
    }
    return http.Response('', 405);
  }
}

void main() {
  late Directory dir;
  late File file;
  final content = List<int>.generate(25000, (i) => i % 251);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tus');
    file = File('${dir.path}/IMG_0001.HEIC')..writeAsBytesSync(content);
  });
  tearDown(() => dir.delete(recursive: true));

  test('uploads in chunks and returns the node id', () async {
    final server = FakeTus();
    final progress = <int>[];
    String? created;
    final node = await TusUploader(client: MockClient(server.handle), chunkSize: 10000).upload(
      endpoint: Uri.parse('https://cloud.example.com/api/v1/uploads/'),
      token: 'tok',
      file: file,
      metadata: {'filename': 'IMG_0001.HEIC', 'parent': 'folder1'},
      onCreated: (url) => created = url,
      onProgress: (sent, _) => progress.add(sent),
    );
    expect(node, 'node42');
    expect(server.received.toBytes(), content);
    expect(server.metadata, {'filename': 'IMG_0001.HEIC', 'parent': 'folder1'});
    expect(created, 'https://cloud.example.com/api/v1/uploads/abc');
    expect(progress, [10000, 20000, 25000]);
  });

  test('resumes an interrupted upload where the server stopped', () async {
    final server = FakeTus()..length = content.length;
    server.received.add(content.sublist(0, 12000)); // what arrived before the interruption
    final node = await TusUploader(client: MockClient(server.handle), chunkSize: 10000).upload(
      endpoint: Uri.parse('https://cloud.example.com/api/v1/uploads/'),
      token: 'tok',
      file: file,
      metadata: {'filename': 'IMG_0001.HEIC'},
      resumeUrl: 'https://cloud.example.com/api/v1/uploads/abc',
    );
    expect(node, 'node42');
    expect(server.creations, 0);
    expect(server.received.toBytes(), content);
  });

  test('a refused upload is a permanent error', () async {
    final server = FakeTus()..refuse = true;
    expect(
      () => TusUploader(client: MockClient(server.handle)).upload(
        endpoint: Uri.parse('https://cloud.example.com/api/v1/uploads/'),
        token: 'tok',
        file: file,
        metadata: {'filename': 'x'},
      ),
      throwsA(
        isA<UploadException>()
            .having((e) => e.permanent, 'permanent', isTrue)
            .having((e) => e.message, 'message', 'Not enough space.'),
      ),
    );
  });
}

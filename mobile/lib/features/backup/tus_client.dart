import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

class UploadException implements Exception {
  UploadException(this.message, {this.status = 0});
  final String message;
  final int status;

  /// The server refused for good (quota, invalid folder…): retrying will not help.
  bool get permanent => status == 400 || status == 403 || status == 413;

  @override
  String toString() => 'UploadException($status): $message';
}

/// A minimal tus 1.0 client (creation, resumable PATCH), matching the server's /api/v1/uploads/
/// (ADR 0011). Returns the id of the drive node created by the server.
class TusUploader {
  TusUploader({required this.client, this.chunkSize = 8 * 1024 * 1024});

  final http.Client client;
  final int chunkSize;

  static const _version = {'Tus-Resumable': '1.0.0'};

  Future<String> upload({
    required Uri endpoint,
    required String token,
    required File file,
    required Map<String, String> metadata,
    String? resumeUrl,
    void Function(String uploadUrl)? onCreated,
    void Function(int sent, int total)? onProgress,
  }) async {
    final total = await file.length();
    final auth = {..._version, 'Authorization': token};

    Uri? url = resumeUrl == null ? null : Uri.parse(resumeUrl);
    var offset = 0;
    if (url != null) {
      final head = await client.head(url, headers: auth);
      final o = int.tryParse(head.headers['upload-offset'] ?? '');
      if (head.statusCode == 200 && o != null) {
        offset = o;
      } else {
        url = null; // expired or unknown: start over
      }
    }
    if (url == null) {
      final meta = metadata.entries.map((e) => '${e.key} ${base64.encode(utf8.encode(e.value))}');
      final res = await client.post(
        endpoint,
        headers: {...auth, 'Upload-Length': '$total', 'Upload-Metadata': meta.join(',')},
      );
      final location = res.headers['location'];
      if (res.statusCode != 201 || location == null) throw _error(res);
      url = endpoint.resolve(location);
      onCreated?.call(url.toString());
    }

    final raf = await file.open();
    try {
      while (true) {
        if (offset >= total) {
          // Zero-length files, or an upload finished before an interruption.
          final head = await client.head(url, headers: auth);
          final node = head.headers['alcove-node-id'];
          if (node != null) return node;
        }
        await raf.setPosition(offset);
        final chunk = await raf.read(min(chunkSize, total - offset));
        final res = await client.patch(
          url,
          headers: {
            ...auth,
            'Content-Type': 'application/offset+octet-stream',
            'Upload-Offset': '$offset',
          },
          body: chunk,
        );
        if (res.statusCode != 204) throw _error(res);
        offset = int.tryParse(res.headers['upload-offset'] ?? '') ?? offset + chunk.length;
        onProgress?.call(offset, total);
        if (offset >= total) {
          final node = res.headers['alcove-node-id'];
          if (node == null) throw UploadException('no node id in the final response');
          return node;
        }
      }
    } finally {
      await raf.close();
    }
  }

  static UploadException _error(http.Response res) {
    var message = res.reasonPhrase ?? 'upload failed';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] is String) message = body['message'] as String;
    } catch (_) {}
    return UploadException(message, status: res.statusCode);
  }
}

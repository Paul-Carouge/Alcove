import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An open PDF on the native side: its id and the size of each page (PDF points).
typedef PdfInfo = ({int id, List<Size> pages});

/// The Android side of the file viewers (channel "alcove/files", FilesChannel.kt): PDF pages
/// rendered by the system's PdfRenderer, the "Open with…" and "Share" choosers, and saving to
/// Downloads. Tests replace [instance].
class NativeFiles {
  NativeFiles([MethodChannel? channel]) : _channel = channel ?? const MethodChannel('alcove/files');

  static NativeFiles instance = NativeFiles();

  final MethodChannel _channel;

  /// Whether this platform renders PDFs in the app (Android only for now).
  bool get rendersPdf => !kIsWeb && Platform.isAndroid;

  /// Whether "Open with", "Share" and "Download" go through this channel.
  bool get available => !kIsWeb && Platform.isAndroid;

  Future<PdfInfo> pdfOpen(String path) async {
    final res = (await _channel.invokeMapMethod<String, dynamic>('pdfOpen', {'path': path}))!;
    return (
      id: res['id'] as int,
      pages: [
        for (final p in (res['pages'] as List).cast<List<dynamic>>())
          Size((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
    );
  }

  /// One page as a PNG, [width] pixels wide.
  Future<Uint8List> pdfRender(int id, int page, int width) async =>
      (await _channel.invokeMethod<Uint8List>('pdfRender', {
        'id': id,
        'page': page,
        'width': width,
      }))!;

  Future<void> pdfClose(int id) => _channel.invokeMethod<void>('pdfClose', {'id': id});

  /// The system "Open with…" chooser; false when no app can open the file.
  Future<bool> openWith(String path, String mime, String title) async =>
      await _channel.invokeMethod<bool>('openWith', {
        'path': path,
        'mime': mime,
        'title': title,
      }) ??
      false;

  Future<bool> share(List<String> paths, String mime, String title) async =>
      await _channel.invokeMethod<bool>('share', {
        'paths': paths,
        'mime': mime,
        'title': title,
      }) ??
      false;

  /// Copies the file into Downloads/Alcove; false where unsupported (Android 9 and older).
  Future<bool> saveToDownloads(String path, String name, String mime) async =>
      await _channel.invokeMethod<bool>('saveToDownloads', {
        'path': path,
        'name': name,
        'mime': mime,
      }) ??
      false;
}

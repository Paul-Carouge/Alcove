import 'dart:convert';

/// Bidirectional and zero-width controls (U+200B–U+200F, U+202A–U+202E, U+2066–U+2069, BOM):
/// they can make "invoice\u202Efdp.exe" look like "invoiceexe.pdf". Never kept in a name.
final _invisible = RegExp('[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');
final _unsafe = RegExp(r'[/\\\x00-\x1f\x7f]');

/// A file name safe to show and to write: no path separators, control, bidi or zero-width
/// characters, no leading dots, at most [maxBytes] UTF-8 bytes (the extension is kept when it
/// is short). ShareChannel.kt applies the same rules on the Android side.
String safeFileName(String name, {int maxBytes = 200}) {
  var n = name.replaceAll(_invisible, '').replaceAll(_unsafe, '_').trim();
  n = n.replaceFirst(RegExp(r'^\.+'), '_');
  if (n.isEmpty || n == '_') return 'file';
  if (utf8.encode(n).length <= maxBytes) return n;
  final dot = n.lastIndexOf('.');
  final ext = dot > 0 && n.length - dot <= 16 ? n.substring(dot) : '';
  final base = ext.isEmpty ? n : n.substring(0, dot);
  final budget = maxBytes - utf8.encode(ext).length;
  final out = StringBuffer();
  var used = 0;
  for (final r in base.runes) {
    final ch = String.fromCharCode(r);
    final size = utf8.encode(ch).length;
    if (used + size > budget) break;
    out.write(ch);
    used += size;
  }
  return '${out.toString().trimRight()}$ext';
}

const _byExtension = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'heic': 'image/heic',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'csv': 'text/csv',
  'json': 'application/json',
  'html': 'text/html',
  'zip': 'application/zip',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'odt': 'application/vnd.oasis.opendocument.text',
  'ods': 'application/vnd.oasis.opendocument.spreadsheet',
};

/// The MIME type to hand a file to other apps with (Open with, Share, Download). The extension
/// wins over the server's type when they disagree (that is what the receiving app will see), and
/// installable packages are never announced as such: a shared APK must not open the installer.
String handOutMime(String name, String mime) {
  final lower = name.toLowerCase();
  final m = mime.split(';').first.trim().toLowerCase();
  const generic = 'application/octet-stream';
  if (lower.endsWith('.apk') || lower.endsWith('.apks') || lower.endsWith('.xapk')) return generic;
  final dot = lower.lastIndexOf('.');
  final fromExt = dot < 0 ? null : _byExtension[lower.substring(dot + 1)];
  if (fromExt != null) return fromExt;
  if (m.isEmpty || m.contains('*') || m.contains('android.package-archive')) return generic;
  return m;
}

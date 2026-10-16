import 'dart:convert';
import 'dart:typed_data';

/// How a file is shown in the app.
enum PreviewKind {
  image,
  video,
  pdf,

  /// Prose: plain text, Markdown, logs. Shown in the text face.
  text,

  /// Code and data (JSON, CSV, YAML, source files). Shown in monospace.
  code,

  /// No in-app preview: Open with, Share, Download.
  none,
}

const _textExt = {'txt', 'text', 'md', 'markdown', 'log', 'rst', 'org', 'nfo'};
const _codeExt = {
  'json',
  'jsonl',
  'geojson',
  'csv',
  'tsv',
  'xml',
  'yaml',
  'yml',
  'toml',
  'ini',
  'cfg',
  'conf',
  'env',
  'properties',
  'sql',
  'graphql',
  'gql',
  'dart',
  'js',
  'mjs',
  'cjs',
  'ts',
  'tsx',
  'jsx',
  'svelte',
  'vue',
  'py',
  'rb',
  'go',
  'rs',
  'kt',
  'kts',
  'java',
  'swift',
  'c',
  'h',
  'cc',
  'cpp',
  'hpp',
  'cs',
  'php',
  'pl',
  'lua',
  'r',
  'sh',
  'bash',
  'zsh',
  'fish',
  'ps1',
  'bat',
  'html',
  'htm',
  'css',
  'scss',
  'less',
  'gradle',
  'cmake',
  'makefile',
  'dockerfile',
  'srt',
  'vtt',
  'ics',
  'vcf',
  'diff',
  'patch',
  'tex',
  'bib',
};
const _imageMimes = {'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/bmp'};

String _ext(String name) {
  final n = name.toLowerCase();
  final dot = n.lastIndexOf('.');
  if (dot < 0) return n; // Makefile, Dockerfile
  return n.substring(dot + 1);
}

/// What kind of preview a file gets, from its MIME type first and its name second.
PreviewKind previewKind(String mime, String name) {
  final m = mime.split(';').first.trim().toLowerCase();
  final ext = _ext(name);
  if (_imageMimes.contains(m) ||
      ((m.isEmpty || m == 'application/octet-stream') &&
          {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(ext))) {
    return PreviewKind.image;
  }
  if (m.startsWith('video/')) return PreviewKind.video;
  if (m == 'application/pdf' || ext == 'pdf') return PreviewKind.pdf;
  if (_codeExt.contains(ext)) return PreviewKind.code;
  if (_textExt.contains(ext)) return PreviewKind.text;
  if (m == 'application/json' ||
      m == 'text/csv' ||
      m.endsWith('+json') ||
      m.endsWith('/xml') ||
      m.endsWith('+xml') ||
      m.startsWith('text/x-') ||
      m == 'application/javascript' ||
      m == 'application/x-sh' ||
      m == 'application/yaml' ||
      m == 'text/html' ||
      m == 'text/css') {
    return PreviewKind.code;
  }
  if (m.startsWith('text/')) return PreviewKind.text;
  return PreviewKind.none;
}

/// Text files above this size are not previewed (Open with handles them).
const maxTextPreviewBytes = 1024 * 1024;

/// The text to show for a file's bytes, or null when it does not look like text (a NUL byte in
/// the first KB). JSON is indented when it parses; Windows line endings become plain ones.
String? previewText(Uint8List bytes, PreviewKind kind, {String name = ''}) {
  final head = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
  if (head.contains(0)) return null;
  var start = 0;
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) start = 3;
  var text = utf8.decode(bytes.sublist(start), allowMalformed: true).replaceAll('\r\n', '\n');
  final ext = _ext(name);
  if (kind == PreviewKind.code && (ext == 'json' || ext == 'geojson') && text.length < 256000) {
    try {
      text = const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    } catch (_) {
      // Not valid JSON: shown as it is.
    }
  }
  return text;
}

/// Splits text into chunks of whole lines for a lazy list (one widget per chunk, not per file).
List<String> textChunks(String text, {int lines = 80}) {
  final all = text.split('\n');
  return [
    for (var i = 0; i < all.length; i += lines)
      all.sublist(i, i + lines > all.length ? all.length : i + lines).join('\n'),
  ];
}

/// Page index (0-based) shown at scroll [offset], given each page's top and the viewport height:
/// the last page whose top is above the middle of the screen.
int pageAt(List<double> tops, double offset, double viewport) {
  if (tops.isEmpty) return 0;
  final probe = offset + viewport / 3;
  var lo = 0;
  var hi = tops.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    if (tops[mid] <= probe) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}

/// The bitmap width to ask for a page shown [logicalWidth] wide: rounded up to a step so that a
/// small zoom change reuses the cached bitmap, and capped.
int renderWidth(double logicalWidth, double pixelRatio, {int step = 256, int max = 4096}) {
  final px = (logicalWidth * pixelRatio).ceil();
  final stepped = ((px + step - 1) ~/ step) * step;
  return stepped.clamp(step, max);
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../theme/theme.dart';

/// How remote images are loaded; screenshot tests swap it for local pictures.
ImageProvider Function(Uri url) alcoveImageProvider = FreshTokenImage.new;

/// A valid file token at load time; set by the app from its session.
Future<String> Function()? remoteImageToken;

/// [url] with a fresh file token (unchanged when it has none or the app set no token source).
Future<Uri> withFreshToken(Uri url) async {
  final token = remoteImageToken;
  if (token == null || !url.queryParameters.containsKey('token')) return url;
  return url.replace(queryParameters: {...url.queryParameters, 'token': await token()});
}

/// A server image whose `token` query parameter is renewed when the bytes are fetched.
///
/// File tokens expire after a few minutes, but screens keep the URLs they built: once the big
/// viewer previews evicted the grid's thumbnails from the image cache, reloading them with the old
/// token failed and the timeline stayed blank. The cache key ignores the token, so a renewed one
/// does not download (and make the server read from disk) images already in memory either.
@immutable
class FreshTokenImage extends ImageProvider<FreshTokenImage> {
  FreshTokenImage(this.url) : _key = _withoutToken(url);

  final Uri url;
  final String _key;

  static final http.Client _client = IOClient(
    HttpClient()..connectionTimeout = const Duration(seconds: 15),
  );

  static String _withoutToken(Uri u) =>
      u.replace(queryParameters: Map.of(u.queryParameters)..remove('token')).toString();

  Future<Uri> freshUrl() => withFreshToken(url);

  @override
  Future<FreshTokenImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(FreshTokenImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1, debugLabel: _key);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    try {
      final u = await freshUrl();
      // A server that accepts the connection but never answers would leave a spinner forever.
      final res = await _client.get(u).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw NetworkImageLoadException(statusCode: res.statusCode, uri: u);
      }
      return decode(await ui.ImmutableBuffer.fromUint8List(res.bodyBytes));
    } catch (_) {
      // The cache keeps failures: without this, the image stays broken even once back online.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(this));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) => other is FreshTokenImage && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

/// A server image that fades in over a soft placeholder.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.semanticLabel,
    this.placeholder,
  });

  final Uri url;
  final BoxFit fit;
  final int? cacheWidth;
  final String? semanticLabel;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    ImageProvider provider = alcoveImageProvider(url);
    if (cacheWidth != null) {
      provider = ResizeImage(provider, width: cacheWidth, policy: ResizeImagePolicy.fit);
    }
    return Image(
      image: provider,
      fit: fit,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) => sync
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: child,
            ),
      errorBuilder: (_, _, _) =>
          placeholder ??
          Center(child: Icon(Icons.image_not_supported_outlined, color: colors.textMuted)),
    );
  }
}

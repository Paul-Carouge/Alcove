import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// How remote images are loaded; screenshot tests swap it for local pictures.
ImageProvider Function(Uri url) alcoveImageProvider = (url) => NetworkImage(url.toString());

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

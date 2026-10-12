import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

/// A photo or video of the phone's library.
abstract class LibraryAsset {
  String get id;
  bool get isVideo;
  DateTime get created;

  /// The original file (HEIC/RAW/video as taken, with its location metadata when allowed).
  Future<File?> original();

  /// The original file name (IMG_1234.HEIC).
  Future<String> name();
}

/// The phone's photo library.
abstract class PhotoLibrary {
  /// Asks for access (and, on Android, for photo locations). Returns whether reading is allowed.
  Future<bool> requestAccess();

  /// Every photo (and video when asked), newest first.
  Future<List<LibraryAsset>> assets({required bool videos});
}

class DevicePhotoLibrary implements PhotoLibrary {
  @override
  Future<bool> requestAccess() async {
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(type: RequestType.common, mediaLocation: true),
      ),
    );
    return state.hasAccess;
  }

  @override
  Future<List<LibraryAsset>> assets({required bool videos}) async {
    final paths = await PhotoManager.getAssetPathList(
      type: videos ? RequestType.common : RequestType.image,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (paths.isEmpty) return [];
    final all = paths.first;
    final count = await all.assetCountAsync;
    final out = <LibraryAsset>[];
    for (var page = 0; page * 500 < count; page++) {
      final list = await all.getAssetListPaged(page: page, size: 500);
      out.addAll(list.map(_DeviceAsset.new));
    }
    return out;
  }
}

class _DeviceAsset implements LibraryAsset {
  _DeviceAsset(this.entity);

  final AssetEntity entity;

  @override
  String get id => entity.id;

  @override
  bool get isVideo => entity.type == AssetType.video;

  @override
  DateTime get created => entity.createDateTime;

  @override
  Future<File?> original() => entity.originFile;

  @override
  Future<String> name() async => await entity.titleAsync;
}

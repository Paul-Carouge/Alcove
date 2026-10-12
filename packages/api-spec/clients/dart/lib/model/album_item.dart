//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class AlbumItem {
  /// Returns a new [AlbumItem] instance.
  AlbumItem({
    required this.id,
    required this.collectionId,
    required this.thumb,
    required this.preview,
    required this.itemId,
    required this.addedBy,
    required this.kind,
    required this.status,
    required this.takenAt,
    required this.width,
    required this.height,
    required this.duration,
    required this.favorite,
    this.cameraMake,
    this.cameraModel,
    this.lens,
    this.exposure,
    this.hasLocation,
    this.lat,
    this.lon,
    required this.name,
    required this.size,
    required this.mime,
  });

  String id;

  String collectionId;

  String thumb;

  String preview;

  /// The album_items record (to remove it).
  String itemId;

  /// User id.
  String addedBy;

  AlbumItemKindEnum kind;

  AlbumItemStatusEnum status;

  String takenAt;

  int width;

  int height;

  num duration;

  /// The owner's favorite flag (false for others' photos).
  bool favorite;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? cameraMake;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? cameraModel;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? lens;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? exposure;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? hasLocation;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? lat;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? lon;

  /// File name.
  String name;

  int size;

  String mime;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AlbumItem &&
    other.id == id &&
    other.collectionId == collectionId &&
    other.thumb == thumb &&
    other.preview == preview &&
    other.itemId == itemId &&
    other.addedBy == addedBy &&
    other.kind == kind &&
    other.status == status &&
    other.takenAt == takenAt &&
    other.width == width &&
    other.height == height &&
    other.duration == duration &&
    other.favorite == favorite &&
    other.cameraMake == cameraMake &&
    other.cameraModel == cameraModel &&
    other.lens == lens &&
    other.exposure == exposure &&
    other.hasLocation == hasLocation &&
    other.lat == lat &&
    other.lon == lon &&
    other.name == name &&
    other.size == size &&
    other.mime == mime;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (collectionId.hashCode) +
    (thumb.hashCode) +
    (preview.hashCode) +
    (itemId.hashCode) +
    (addedBy.hashCode) +
    (kind.hashCode) +
    (status.hashCode) +
    (takenAt.hashCode) +
    (width.hashCode) +
    (height.hashCode) +
    (duration.hashCode) +
    (favorite.hashCode) +
    (cameraMake == null ? 0 : cameraMake!.hashCode) +
    (cameraModel == null ? 0 : cameraModel!.hashCode) +
    (lens == null ? 0 : lens!.hashCode) +
    (exposure == null ? 0 : exposure!.hashCode) +
    (hasLocation == null ? 0 : hasLocation!.hashCode) +
    (lat == null ? 0 : lat!.hashCode) +
    (lon == null ? 0 : lon!.hashCode) +
    (name.hashCode) +
    (size.hashCode) +
    (mime.hashCode);

  @override
  String toString() => 'AlbumItem[id=$id, collectionId=$collectionId, thumb=$thumb, preview=$preview, itemId=$itemId, addedBy=$addedBy, kind=$kind, status=$status, takenAt=$takenAt, width=$width, height=$height, duration=$duration, favorite=$favorite, cameraMake=$cameraMake, cameraModel=$cameraModel, lens=$lens, exposure=$exposure, hasLocation=$hasLocation, lat=$lat, lon=$lon, name=$name, size=$size, mime=$mime]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'collectionId'] = this.collectionId;
      json[r'thumb'] = this.thumb;
      json[r'preview'] = this.preview;
      json[r'itemId'] = this.itemId;
      json[r'addedBy'] = this.addedBy;
      json[r'kind'] = this.kind;
      json[r'status'] = this.status;
      json[r'taken_at'] = this.takenAt;
      json[r'width'] = this.width;
      json[r'height'] = this.height;
      json[r'duration'] = this.duration;
      json[r'favorite'] = this.favorite;
    if (this.cameraMake != null) {
      json[r'camera_make'] = this.cameraMake;
    } else {
      json[r'camera_make'] = null;
    }
    if (this.cameraModel != null) {
      json[r'camera_model'] = this.cameraModel;
    } else {
      json[r'camera_model'] = null;
    }
    if (this.lens != null) {
      json[r'lens'] = this.lens;
    } else {
      json[r'lens'] = null;
    }
    if (this.exposure != null) {
      json[r'exposure'] = this.exposure;
    } else {
      json[r'exposure'] = null;
    }
    if (this.hasLocation != null) {
      json[r'has_location'] = this.hasLocation;
    } else {
      json[r'has_location'] = null;
    }
    if (this.lat != null) {
      json[r'lat'] = this.lat;
    } else {
      json[r'lat'] = null;
    }
    if (this.lon != null) {
      json[r'lon'] = this.lon;
    } else {
      json[r'lon'] = null;
    }
      json[r'name'] = this.name;
      json[r'size'] = this.size;
      json[r'mime'] = this.mime;
    return json;
  }

  /// Returns a new [AlbumItem] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AlbumItem? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AlbumItem[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AlbumItem[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AlbumItem(
        id: mapValueOfType<String>(json, r'id')!,
        collectionId: mapValueOfType<String>(json, r'collectionId')!,
        thumb: mapValueOfType<String>(json, r'thumb')!,
        preview: mapValueOfType<String>(json, r'preview')!,
        itemId: mapValueOfType<String>(json, r'itemId')!,
        addedBy: mapValueOfType<String>(json, r'addedBy')!,
        kind: AlbumItemKindEnum.fromJson(json[r'kind'])!,
        status: AlbumItemStatusEnum.fromJson(json[r'status'])!,
        takenAt: mapValueOfType<String>(json, r'taken_at')!,
        width: mapValueOfType<int>(json, r'width')!,
        height: mapValueOfType<int>(json, r'height')!,
        duration: num.parse('${json[r'duration']}'),
        favorite: mapValueOfType<bool>(json, r'favorite')!,
        cameraMake: mapValueOfType<String>(json, r'camera_make'),
        cameraModel: mapValueOfType<String>(json, r'camera_model'),
        lens: mapValueOfType<String>(json, r'lens'),
        exposure: mapValueOfType<String>(json, r'exposure'),
        hasLocation: mapValueOfType<bool>(json, r'has_location'),
        lat: num.parse('${json[r'lat']}'),
        lon: num.parse('${json[r'lon']}'),
        name: mapValueOfType<String>(json, r'name')!,
        size: mapValueOfType<int>(json, r'size')!,
        mime: mapValueOfType<String>(json, r'mime')!,
      );
    }
    return null;
  }

  static List<AlbumItem> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AlbumItem>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AlbumItem.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AlbumItem> mapFromJson(dynamic json) {
    final map = <String, AlbumItem>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AlbumItem.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AlbumItem-objects as value to a dart map
  static Map<String, List<AlbumItem>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AlbumItem>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AlbumItem.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'collectionId',
    'thumb',
    'preview',
    'itemId',
    'addedBy',
    'kind',
    'status',
    'taken_at',
    'width',
    'height',
    'duration',
    'favorite',
    'name',
    'size',
    'mime',
  };
}


class AlbumItemKindEnum {
  /// Instantiate a new enum with the provided [value].
  const AlbumItemKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const image = AlbumItemKindEnum._(r'image');
  static const video = AlbumItemKindEnum._(r'video');

  /// List of all possible values in this [enum][AlbumItemKindEnum].
  static const values = <AlbumItemKindEnum>[
    image,
    video,
  ];

  static AlbumItemKindEnum? fromJson(dynamic value) => AlbumItemKindEnumTypeTransformer().decode(value);

  static List<AlbumItemKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AlbumItemKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AlbumItemKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AlbumItemKindEnum] to String,
/// and [decode] dynamic data back to [AlbumItemKindEnum].
class AlbumItemKindEnumTypeTransformer {
  factory AlbumItemKindEnumTypeTransformer() => _instance ??= const AlbumItemKindEnumTypeTransformer._();

  const AlbumItemKindEnumTypeTransformer._();

  String encode(AlbumItemKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AlbumItemKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AlbumItemKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'image': return AlbumItemKindEnum.image;
        case r'video': return AlbumItemKindEnum.video;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AlbumItemKindEnumTypeTransformer] instance.
  static AlbumItemKindEnumTypeTransformer? _instance;
}



class AlbumItemStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const AlbumItemStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const pending = AlbumItemStatusEnum._(r'pending');
  static const ready = AlbumItemStatusEnum._(r'ready');
  static const failed = AlbumItemStatusEnum._(r'failed');

  /// List of all possible values in this [enum][AlbumItemStatusEnum].
  static const values = <AlbumItemStatusEnum>[
    pending,
    ready,
    failed,
  ];

  static AlbumItemStatusEnum? fromJson(dynamic value) => AlbumItemStatusEnumTypeTransformer().decode(value);

  static List<AlbumItemStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AlbumItemStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AlbumItemStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AlbumItemStatusEnum] to String,
/// and [decode] dynamic data back to [AlbumItemStatusEnum].
class AlbumItemStatusEnumTypeTransformer {
  factory AlbumItemStatusEnumTypeTransformer() => _instance ??= const AlbumItemStatusEnumTypeTransformer._();

  const AlbumItemStatusEnumTypeTransformer._();

  String encode(AlbumItemStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AlbumItemStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AlbumItemStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'pending': return AlbumItemStatusEnum.pending;
        case r'ready': return AlbumItemStatusEnum.ready;
        case r'failed': return AlbumItemStatusEnum.failed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AlbumItemStatusEnumTypeTransformer] instance.
  static AlbumItemStatusEnumTypeTransformer? _instance;
}



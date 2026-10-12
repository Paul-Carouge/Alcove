//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class DuplicateItem {
  /// Returns a new [DuplicateItem] instance.
  DuplicateItem({
    required this.id,
    required this.collectionId,
    required this.thumb,
    required this.preview,
    required this.node,
    required this.kind,
    required this.status,
    required this.takenAt,
    required this.width,
    required this.height,
    required this.duration,
    required this.name,
    required this.size,
    required this.mime,
    required this.created,
  });

  String id;

  String collectionId;

  String thumb;

  String preview;

  /// Drive node id (to move it to the trash).
  String node;

  DuplicateItemKindEnum kind;

  DuplicateItemStatusEnum status;

  String takenAt;

  int width;

  int height;

  num duration;

  String name;

  int size;

  String mime;

  /// Upload date.
  String created;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DuplicateItem &&
    other.id == id &&
    other.collectionId == collectionId &&
    other.thumb == thumb &&
    other.preview == preview &&
    other.node == node &&
    other.kind == kind &&
    other.status == status &&
    other.takenAt == takenAt &&
    other.width == width &&
    other.height == height &&
    other.duration == duration &&
    other.name == name &&
    other.size == size &&
    other.mime == mime &&
    other.created == created;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (collectionId.hashCode) +
    (thumb.hashCode) +
    (preview.hashCode) +
    (node.hashCode) +
    (kind.hashCode) +
    (status.hashCode) +
    (takenAt.hashCode) +
    (width.hashCode) +
    (height.hashCode) +
    (duration.hashCode) +
    (name.hashCode) +
    (size.hashCode) +
    (mime.hashCode) +
    (created.hashCode);

  @override
  String toString() => 'DuplicateItem[id=$id, collectionId=$collectionId, thumb=$thumb, preview=$preview, node=$node, kind=$kind, status=$status, takenAt=$takenAt, width=$width, height=$height, duration=$duration, name=$name, size=$size, mime=$mime, created=$created]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'collectionId'] = this.collectionId;
      json[r'thumb'] = this.thumb;
      json[r'preview'] = this.preview;
      json[r'node'] = this.node;
      json[r'kind'] = this.kind;
      json[r'status'] = this.status;
      json[r'taken_at'] = this.takenAt;
      json[r'width'] = this.width;
      json[r'height'] = this.height;
      json[r'duration'] = this.duration;
      json[r'name'] = this.name;
      json[r'size'] = this.size;
      json[r'mime'] = this.mime;
      json[r'created'] = this.created;
    return json;
  }

  /// Returns a new [DuplicateItem] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DuplicateItem? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "DuplicateItem[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "DuplicateItem[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return DuplicateItem(
        id: mapValueOfType<String>(json, r'id')!,
        collectionId: mapValueOfType<String>(json, r'collectionId')!,
        thumb: mapValueOfType<String>(json, r'thumb')!,
        preview: mapValueOfType<String>(json, r'preview')!,
        node: mapValueOfType<String>(json, r'node')!,
        kind: DuplicateItemKindEnum.fromJson(json[r'kind'])!,
        status: DuplicateItemStatusEnum.fromJson(json[r'status'])!,
        takenAt: mapValueOfType<String>(json, r'taken_at')!,
        width: mapValueOfType<int>(json, r'width')!,
        height: mapValueOfType<int>(json, r'height')!,
        duration: num.parse('${json[r'duration']}'),
        name: mapValueOfType<String>(json, r'name')!,
        size: mapValueOfType<int>(json, r'size')!,
        mime: mapValueOfType<String>(json, r'mime')!,
        created: mapValueOfType<String>(json, r'created')!,
      );
    }
    return null;
  }

  static List<DuplicateItem> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DuplicateItem>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DuplicateItem.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DuplicateItem> mapFromJson(dynamic json) {
    final map = <String, DuplicateItem>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DuplicateItem.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DuplicateItem-objects as value to a dart map
  static Map<String, List<DuplicateItem>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DuplicateItem>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DuplicateItem.listFromJson(entry.value, growable: growable,);
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
    'node',
    'kind',
    'status',
    'taken_at',
    'width',
    'height',
    'duration',
    'name',
    'size',
    'mime',
    'created',
  };
}


class DuplicateItemKindEnum {
  /// Instantiate a new enum with the provided [value].
  const DuplicateItemKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const image = DuplicateItemKindEnum._(r'image');
  static const video = DuplicateItemKindEnum._(r'video');

  /// List of all possible values in this [enum][DuplicateItemKindEnum].
  static const values = <DuplicateItemKindEnum>[
    image,
    video,
  ];

  static DuplicateItemKindEnum? fromJson(dynamic value) => DuplicateItemKindEnumTypeTransformer().decode(value);

  static List<DuplicateItemKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DuplicateItemKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DuplicateItemKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DuplicateItemKindEnum] to String,
/// and [decode] dynamic data back to [DuplicateItemKindEnum].
class DuplicateItemKindEnumTypeTransformer {
  factory DuplicateItemKindEnumTypeTransformer() => _instance ??= const DuplicateItemKindEnumTypeTransformer._();

  const DuplicateItemKindEnumTypeTransformer._();

  String encode(DuplicateItemKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a DuplicateItemKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DuplicateItemKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'image': return DuplicateItemKindEnum.image;
        case r'video': return DuplicateItemKindEnum.video;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [DuplicateItemKindEnumTypeTransformer] instance.
  static DuplicateItemKindEnumTypeTransformer? _instance;
}



class DuplicateItemStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const DuplicateItemStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const pending = DuplicateItemStatusEnum._(r'pending');
  static const ready = DuplicateItemStatusEnum._(r'ready');
  static const failed = DuplicateItemStatusEnum._(r'failed');

  /// List of all possible values in this [enum][DuplicateItemStatusEnum].
  static const values = <DuplicateItemStatusEnum>[
    pending,
    ready,
    failed,
  ];

  static DuplicateItemStatusEnum? fromJson(dynamic value) => DuplicateItemStatusEnumTypeTransformer().decode(value);

  static List<DuplicateItemStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DuplicateItemStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DuplicateItemStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DuplicateItemStatusEnum] to String,
/// and [decode] dynamic data back to [DuplicateItemStatusEnum].
class DuplicateItemStatusEnumTypeTransformer {
  factory DuplicateItemStatusEnumTypeTransformer() => _instance ??= const DuplicateItemStatusEnumTypeTransformer._();

  const DuplicateItemStatusEnumTypeTransformer._();

  String encode(DuplicateItemStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a DuplicateItemStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DuplicateItemStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'pending': return DuplicateItemStatusEnum.pending;
        case r'ready': return DuplicateItemStatusEnum.ready;
        case r'failed': return DuplicateItemStatusEnum.failed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [DuplicateItemStatusEnumTypeTransformer] instance.
  static DuplicateItemStatusEnumTypeTransformer? _instance;
}



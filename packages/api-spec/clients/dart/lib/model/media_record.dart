//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class MediaRecord {
  /// Returns a new [MediaRecord] instance.
  MediaRecord({
    required this.id,
    required this.node,
    this.kind,
    this.takenAt,
  });

  String id;

  String node;

  MediaRecordKindEnum? kind;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? takenAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is MediaRecord &&
    other.id == id &&
    other.node == node &&
    other.kind == kind &&
    other.takenAt == takenAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (node.hashCode) +
    (kind == null ? 0 : kind!.hashCode) +
    (takenAt == null ? 0 : takenAt!.hashCode);

  @override
  String toString() => 'MediaRecord[id=$id, node=$node, kind=$kind, takenAt=$takenAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'node'] = this.node;
    if (this.kind != null) {
      json[r'kind'] = this.kind;
    } else {
      json[r'kind'] = null;
    }
    if (this.takenAt != null) {
      json[r'taken_at'] = this.takenAt;
    } else {
      json[r'taken_at'] = null;
    }
    return json;
  }

  /// Returns a new [MediaRecord] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MediaRecord? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "MediaRecord[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "MediaRecord[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return MediaRecord(
        id: mapValueOfType<String>(json, r'id')!,
        node: mapValueOfType<String>(json, r'node')!,
        kind: MediaRecordKindEnum.fromJson(json[r'kind']),
        takenAt: mapValueOfType<String>(json, r'taken_at'),
      );
    }
    return null;
  }

  static List<MediaRecord> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MediaRecord>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MediaRecord.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MediaRecord> mapFromJson(dynamic json) {
    final map = <String, MediaRecord>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MediaRecord.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MediaRecord-objects as value to a dart map
  static Map<String, List<MediaRecord>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<MediaRecord>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MediaRecord.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'node',
  };
}


class MediaRecordKindEnum {
  /// Instantiate a new enum with the provided [value].
  const MediaRecordKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const image = MediaRecordKindEnum._(r'image');
  static const video = MediaRecordKindEnum._(r'video');

  /// List of all possible values in this [enum][MediaRecordKindEnum].
  static const values = <MediaRecordKindEnum>[
    image,
    video,
  ];

  static MediaRecordKindEnum? fromJson(dynamic value) => MediaRecordKindEnumTypeTransformer().decode(value);

  static List<MediaRecordKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MediaRecordKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MediaRecordKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [MediaRecordKindEnum] to String,
/// and [decode] dynamic data back to [MediaRecordKindEnum].
class MediaRecordKindEnumTypeTransformer {
  factory MediaRecordKindEnumTypeTransformer() => _instance ??= const MediaRecordKindEnumTypeTransformer._();

  const MediaRecordKindEnumTypeTransformer._();

  String encode(MediaRecordKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a MediaRecordKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  MediaRecordKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'image': return MediaRecordKindEnum.image;
        case r'video': return MediaRecordKindEnum.video;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [MediaRecordKindEnumTypeTransformer] instance.
  static MediaRecordKindEnumTypeTransformer? _instance;
}



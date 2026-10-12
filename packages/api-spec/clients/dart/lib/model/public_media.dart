//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class PublicMedia {
  /// Returns a new [PublicMedia] instance.
  PublicMedia({
    required this.id,
    required this.kind,
    required this.ready,
    required this.width,
    required this.height,
    required this.duration,
    required this.takenAt,
    required this.name,
  });

  String id;

  PublicMediaKindEnum kind;

  /// Thumbnail and preview are available.
  bool ready;

  int width;

  int height;

  num duration;

  String takenAt;

  String name;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PublicMedia &&
    other.id == id &&
    other.kind == kind &&
    other.ready == ready &&
    other.width == width &&
    other.height == height &&
    other.duration == duration &&
    other.takenAt == takenAt &&
    other.name == name;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (kind.hashCode) +
    (ready.hashCode) +
    (width.hashCode) +
    (height.hashCode) +
    (duration.hashCode) +
    (takenAt.hashCode) +
    (name.hashCode);

  @override
  String toString() => 'PublicMedia[id=$id, kind=$kind, ready=$ready, width=$width, height=$height, duration=$duration, takenAt=$takenAt, name=$name]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'kind'] = this.kind;
      json[r'ready'] = this.ready;
      json[r'width'] = this.width;
      json[r'height'] = this.height;
      json[r'duration'] = this.duration;
      json[r'taken_at'] = this.takenAt;
      json[r'name'] = this.name;
    return json;
  }

  /// Returns a new [PublicMedia] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PublicMedia? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PublicMedia[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PublicMedia[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PublicMedia(
        id: mapValueOfType<String>(json, r'id')!,
        kind: PublicMediaKindEnum.fromJson(json[r'kind'])!,
        ready: mapValueOfType<bool>(json, r'ready')!,
        width: mapValueOfType<int>(json, r'width')!,
        height: mapValueOfType<int>(json, r'height')!,
        duration: num.parse('${json[r'duration']}'),
        takenAt: mapValueOfType<String>(json, r'taken_at')!,
        name: mapValueOfType<String>(json, r'name')!,
      );
    }
    return null;
  }

  static List<PublicMedia> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PublicMedia>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PublicMedia.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PublicMedia> mapFromJson(dynamic json) {
    final map = <String, PublicMedia>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PublicMedia.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PublicMedia-objects as value to a dart map
  static Map<String, List<PublicMedia>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PublicMedia>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PublicMedia.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'kind',
    'ready',
    'width',
    'height',
    'duration',
    'taken_at',
    'name',
  };
}


class PublicMediaKindEnum {
  /// Instantiate a new enum with the provided [value].
  const PublicMediaKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const image = PublicMediaKindEnum._(r'image');
  static const video = PublicMediaKindEnum._(r'video');

  /// List of all possible values in this [enum][PublicMediaKindEnum].
  static const values = <PublicMediaKindEnum>[
    image,
    video,
  ];

  static PublicMediaKindEnum? fromJson(dynamic value) => PublicMediaKindEnumTypeTransformer().decode(value);

  static List<PublicMediaKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PublicMediaKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PublicMediaKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PublicMediaKindEnum] to String,
/// and [decode] dynamic data back to [PublicMediaKindEnum].
class PublicMediaKindEnumTypeTransformer {
  factory PublicMediaKindEnumTypeTransformer() => _instance ??= const PublicMediaKindEnumTypeTransformer._();

  const PublicMediaKindEnumTypeTransformer._();

  String encode(PublicMediaKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PublicMediaKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PublicMediaKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'image': return PublicMediaKindEnum.image;
        case r'video': return PublicMediaKindEnum.video;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PublicMediaKindEnumTypeTransformer] instance.
  static PublicMediaKindEnumTypeTransformer? _instance;
}



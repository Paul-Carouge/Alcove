//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class SetupStatusStorage {
  /// Returns a new [SetupStatusStorage] instance.
  SetupStatusStorage({
    required this.type,
    required this.writable,
    this.error,
  });

  SetupStatusStorageTypeEnum type;

  /// A test file could be written, read and deleted.
  bool writable;

  /// Why the write test failed.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? error;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SetupStatusStorage &&
    other.type == type &&
    other.writable == writable &&
    other.error == error;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (type.hashCode) +
    (writable.hashCode) +
    (error == null ? 0 : error!.hashCode);

  @override
  String toString() => 'SetupStatusStorage[type=$type, writable=$writable, error=$error]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'type'] = this.type;
      json[r'writable'] = this.writable;
    if (this.error != null) {
      json[r'error'] = this.error;
    } else {
      json[r'error'] = null;
    }
    return json;
  }

  /// Returns a new [SetupStatusStorage] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SetupStatusStorage? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SetupStatusStorage[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SetupStatusStorage[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SetupStatusStorage(
        type: SetupStatusStorageTypeEnum.fromJson(json[r'type'])!,
        writable: mapValueOfType<bool>(json, r'writable')!,
        error: mapValueOfType<String>(json, r'error'),
      );
    }
    return null;
  }

  static List<SetupStatusStorage> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SetupStatusStorage>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SetupStatusStorage.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SetupStatusStorage> mapFromJson(dynamic json) {
    final map = <String, SetupStatusStorage>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SetupStatusStorage.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SetupStatusStorage-objects as value to a dart map
  static Map<String, List<SetupStatusStorage>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SetupStatusStorage>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SetupStatusStorage.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'type',
    'writable',
  };
}


class SetupStatusStorageTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const SetupStatusStorageTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const local = SetupStatusStorageTypeEnum._(r'local');
  static const s3 = SetupStatusStorageTypeEnum._(r's3');

  /// List of all possible values in this [enum][SetupStatusStorageTypeEnum].
  static const values = <SetupStatusStorageTypeEnum>[
    local,
    s3,
  ];

  static SetupStatusStorageTypeEnum? fromJson(dynamic value) => SetupStatusStorageTypeEnumTypeTransformer().decode(value);

  static List<SetupStatusStorageTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SetupStatusStorageTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SetupStatusStorageTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SetupStatusStorageTypeEnum] to String,
/// and [decode] dynamic data back to [SetupStatusStorageTypeEnum].
class SetupStatusStorageTypeEnumTypeTransformer {
  factory SetupStatusStorageTypeEnumTypeTransformer() => _instance ??= const SetupStatusStorageTypeEnumTypeTransformer._();

  const SetupStatusStorageTypeEnumTypeTransformer._();

  String encode(SetupStatusStorageTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SetupStatusStorageTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SetupStatusStorageTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'local': return SetupStatusStorageTypeEnum.local;
        case r's3': return SetupStatusStorageTypeEnum.s3;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SetupStatusStorageTypeEnumTypeTransformer] instance.
  static SetupStatusStorageTypeEnumTypeTransformer? _instance;
}



//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class ImportJobFailuresInner {
  /// Returns a new [ImportJobFailuresInner] instance.
  ImportJobFailuresInner({
    required this.path,
    required this.reason,
  });

  String path;

  ImportJobFailuresInnerReasonEnum reason;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ImportJobFailuresInner &&
    other.path == path &&
    other.reason == reason;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (path.hashCode) +
    (reason.hashCode);

  @override
  String toString() => 'ImportJobFailuresInner[path=$path, reason=$reason]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'path'] = this.path;
      json[r'reason'] = this.reason;
    return json;
  }

  /// Returns a new [ImportJobFailuresInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportJobFailuresInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ImportJobFailuresInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ImportJobFailuresInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ImportJobFailuresInner(
        path: mapValueOfType<String>(json, r'path')!,
        reason: ImportJobFailuresInnerReasonEnum.fromJson(json[r'reason'])!,
      );
    }
    return null;
  }

  static List<ImportJobFailuresInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ImportJobFailuresInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportJobFailuresInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportJobFailuresInner> mapFromJson(dynamic json) {
    final map = <String, ImportJobFailuresInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportJobFailuresInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportJobFailuresInner-objects as value to a dart map
  static Map<String, List<ImportJobFailuresInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ImportJobFailuresInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportJobFailuresInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'path',
    'reason',
  };
}


class ImportJobFailuresInnerReasonEnum {
  /// Instantiate a new enum with the provided [value].
  const ImportJobFailuresInnerReasonEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const unreadable = ImportJobFailuresInnerReasonEnum._(r'unreadable');
  static const tooLarge = ImportJobFailuresInnerReasonEnum._(r'too_large');
  static const suspiciousCompression = ImportJobFailuresInnerReasonEnum._(r'suspicious_compression');
  static const unsupported = ImportJobFailuresInnerReasonEnum._(r'unsupported');
  static const saveFailed = ImportJobFailuresInnerReasonEnum._(r'save_failed');

  /// List of all possible values in this [enum][ImportJobFailuresInnerReasonEnum].
  static const values = <ImportJobFailuresInnerReasonEnum>[
    unreadable,
    tooLarge,
    suspiciousCompression,
    unsupported,
    saveFailed,
  ];

  static ImportJobFailuresInnerReasonEnum? fromJson(dynamic value) => ImportJobFailuresInnerReasonEnumTypeTransformer().decode(value);

  static List<ImportJobFailuresInnerReasonEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ImportJobFailuresInnerReasonEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportJobFailuresInnerReasonEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ImportJobFailuresInnerReasonEnum] to String,
/// and [decode] dynamic data back to [ImportJobFailuresInnerReasonEnum].
class ImportJobFailuresInnerReasonEnumTypeTransformer {
  factory ImportJobFailuresInnerReasonEnumTypeTransformer() => _instance ??= const ImportJobFailuresInnerReasonEnumTypeTransformer._();

  const ImportJobFailuresInnerReasonEnumTypeTransformer._();

  String encode(ImportJobFailuresInnerReasonEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ImportJobFailuresInnerReasonEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ImportJobFailuresInnerReasonEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'unreadable': return ImportJobFailuresInnerReasonEnum.unreadable;
        case r'too_large': return ImportJobFailuresInnerReasonEnum.tooLarge;
        case r'suspicious_compression': return ImportJobFailuresInnerReasonEnum.suspiciousCompression;
        case r'unsupported': return ImportJobFailuresInnerReasonEnum.unsupported;
        case r'save_failed': return ImportJobFailuresInnerReasonEnum.saveFailed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ImportJobFailuresInnerReasonEnumTypeTransformer] instance.
  static ImportJobFailuresInnerReasonEnumTypeTransformer? _instance;
}



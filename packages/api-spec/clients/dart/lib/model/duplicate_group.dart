//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class DuplicateGroup {
  /// Returns a new [DuplicateGroup] instance.
  DuplicateGroup({
    required this.kind,
    required this.keep,
    this.items = const [],
  });

  DuplicateGroupKindEnum kind;

  /// Suggested item to keep (highest resolution, then largest file, then oldest upload).
  String keep;

  List<DuplicateItem> items;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DuplicateGroup &&
    other.kind == kind &&
    other.keep == keep &&
    _deepEquality.equals(other.items, items);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (kind.hashCode) +
    (keep.hashCode) +
    (items.hashCode);

  @override
  String toString() => 'DuplicateGroup[kind=$kind, keep=$keep, items=$items]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'kind'] = this.kind;
      json[r'keep'] = this.keep;
      json[r'items'] = this.items;
    return json;
  }

  /// Returns a new [DuplicateGroup] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DuplicateGroup? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "DuplicateGroup[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "DuplicateGroup[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return DuplicateGroup(
        kind: DuplicateGroupKindEnum.fromJson(json[r'kind'])!,
        keep: mapValueOfType<String>(json, r'keep')!,
        items: DuplicateItem.listFromJson(json[r'items']),
      );
    }
    return null;
  }

  static List<DuplicateGroup> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DuplicateGroup>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DuplicateGroup.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DuplicateGroup> mapFromJson(dynamic json) {
    final map = <String, DuplicateGroup>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DuplicateGroup.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DuplicateGroup-objects as value to a dart map
  static Map<String, List<DuplicateGroup>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DuplicateGroup>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DuplicateGroup.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'kind',
    'keep',
    'items',
  };
}


class DuplicateGroupKindEnum {
  /// Instantiate a new enum with the provided [value].
  const DuplicateGroupKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const identical = DuplicateGroupKindEnum._(r'identical');
  static const similar = DuplicateGroupKindEnum._(r'similar');

  /// List of all possible values in this [enum][DuplicateGroupKindEnum].
  static const values = <DuplicateGroupKindEnum>[
    identical,
    similar,
  ];

  static DuplicateGroupKindEnum? fromJson(dynamic value) => DuplicateGroupKindEnumTypeTransformer().decode(value);

  static List<DuplicateGroupKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DuplicateGroupKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DuplicateGroupKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DuplicateGroupKindEnum] to String,
/// and [decode] dynamic data back to [DuplicateGroupKindEnum].
class DuplicateGroupKindEnumTypeTransformer {
  factory DuplicateGroupKindEnumTypeTransformer() => _instance ??= const DuplicateGroupKindEnumTypeTransformer._();

  const DuplicateGroupKindEnumTypeTransformer._();

  String encode(DuplicateGroupKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a DuplicateGroupKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DuplicateGroupKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'identical': return DuplicateGroupKindEnum.identical;
        case r'similar': return DuplicateGroupKindEnum.similar;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [DuplicateGroupKindEnumTypeTransformer] instance.
  static DuplicateGroupKindEnumTypeTransformer? _instance;
}



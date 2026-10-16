//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class ListImportServerFiles200ResponseItemsInner {
  /// Returns a new [ListImportServerFiles200ResponseItemsInner] instance.
  ListImportServerFiles200ResponseItemsInner({
    required this.name,
    required this.kind,
    required this.size,
  });

  String name;

  ListImportServerFiles200ResponseItemsInnerKindEnum kind;

  /// Bytes (0 for folders).
  int size;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListImportServerFiles200ResponseItemsInner &&
    other.name == name &&
    other.kind == kind &&
    other.size == size;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (name.hashCode) +
    (kind.hashCode) +
    (size.hashCode);

  @override
  String toString() => 'ListImportServerFiles200ResponseItemsInner[name=$name, kind=$kind, size=$size]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'name'] = this.name;
      json[r'kind'] = this.kind;
      json[r'size'] = this.size;
    return json;
  }

  /// Returns a new [ListImportServerFiles200ResponseItemsInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListImportServerFiles200ResponseItemsInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ListImportServerFiles200ResponseItemsInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ListImportServerFiles200ResponseItemsInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ListImportServerFiles200ResponseItemsInner(
        name: mapValueOfType<String>(json, r'name')!,
        kind: ListImportServerFiles200ResponseItemsInnerKindEnum.fromJson(json[r'kind'])!,
        size: mapValueOfType<int>(json, r'size')!,
      );
    }
    return null;
  }

  static List<ListImportServerFiles200ResponseItemsInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListImportServerFiles200ResponseItemsInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListImportServerFiles200ResponseItemsInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListImportServerFiles200ResponseItemsInner> mapFromJson(dynamic json) {
    final map = <String, ListImportServerFiles200ResponseItemsInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListImportServerFiles200ResponseItemsInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListImportServerFiles200ResponseItemsInner-objects as value to a dart map
  static Map<String, List<ListImportServerFiles200ResponseItemsInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListImportServerFiles200ResponseItemsInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListImportServerFiles200ResponseItemsInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'name',
    'kind',
    'size',
  };
}


class ListImportServerFiles200ResponseItemsInnerKindEnum {
  /// Instantiate a new enum with the provided [value].
  const ListImportServerFiles200ResponseItemsInnerKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const zip = ListImportServerFiles200ResponseItemsInnerKindEnum._(r'zip');
  static const folder = ListImportServerFiles200ResponseItemsInnerKindEnum._(r'folder');

  /// List of all possible values in this [enum][ListImportServerFiles200ResponseItemsInnerKindEnum].
  static const values = <ListImportServerFiles200ResponseItemsInnerKindEnum>[
    zip,
    folder,
  ];

  static ListImportServerFiles200ResponseItemsInnerKindEnum? fromJson(dynamic value) => ListImportServerFiles200ResponseItemsInnerKindEnumTypeTransformer().decode(value);

  static List<ListImportServerFiles200ResponseItemsInnerKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListImportServerFiles200ResponseItemsInnerKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListImportServerFiles200ResponseItemsInnerKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListImportServerFiles200ResponseItemsInnerKindEnum] to String,
/// and [decode] dynamic data back to [ListImportServerFiles200ResponseItemsInnerKindEnum].
class ListImportServerFiles200ResponseItemsInnerKindEnumTypeTransformer {
  factory ListImportServerFiles200ResponseItemsInnerKindEnumTypeTransformer() => _instance ??= const ListImportServerFiles200ResponseItemsInnerKindEnumTypeTransformer._();

  const ListImportServerFiles200ResponseItemsInnerKindEnumTypeTransformer._();

  String encode(ListImportServerFiles200ResponseItemsInnerKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ListImportServerFiles200ResponseItemsInnerKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListImportServerFiles200ResponseItemsInnerKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'zip': return ListImportServerFiles200ResponseItemsInnerKindEnum.zip;
        case r'folder': return ListImportServerFiles200ResponseItemsInnerKindEnum.folder;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ListImportServerFiles200ResponseItemsInnerKindEnumTypeTransformer] instance.
  static ListImportServerFiles200ResponseItemsInnerKindEnumTypeTransformer? _instance;
}



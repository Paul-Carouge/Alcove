//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class PublicNode {
  /// Returns a new [PublicNode] instance.
  PublicNode({
    required this.id,
    required this.name,
    required this.kind,
    required this.size,
    required this.mime,
    required this.updated,
  });

  String id;

  String name;

  PublicNodeKindEnum kind;

  int size;

  String mime;

  String updated;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PublicNode &&
    other.id == id &&
    other.name == name &&
    other.kind == kind &&
    other.size == size &&
    other.mime == mime &&
    other.updated == updated;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (kind.hashCode) +
    (size.hashCode) +
    (mime.hashCode) +
    (updated.hashCode);

  @override
  String toString() => 'PublicNode[id=$id, name=$name, kind=$kind, size=$size, mime=$mime, updated=$updated]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
      json[r'kind'] = this.kind;
      json[r'size'] = this.size;
      json[r'mime'] = this.mime;
      json[r'updated'] = this.updated;
    return json;
  }

  /// Returns a new [PublicNode] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PublicNode? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PublicNode[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PublicNode[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PublicNode(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        kind: PublicNodeKindEnum.fromJson(json[r'kind'])!,
        size: mapValueOfType<int>(json, r'size')!,
        mime: mapValueOfType<String>(json, r'mime')!,
        updated: mapValueOfType<String>(json, r'updated')!,
      );
    }
    return null;
  }

  static List<PublicNode> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PublicNode>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PublicNode.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PublicNode> mapFromJson(dynamic json) {
    final map = <String, PublicNode>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PublicNode.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PublicNode-objects as value to a dart map
  static Map<String, List<PublicNode>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PublicNode>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PublicNode.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'kind',
    'size',
    'mime',
    'updated',
  };
}


class PublicNodeKindEnum {
  /// Instantiate a new enum with the provided [value].
  const PublicNodeKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const file = PublicNodeKindEnum._(r'file');
  static const folder = PublicNodeKindEnum._(r'folder');

  /// List of all possible values in this [enum][PublicNodeKindEnum].
  static const values = <PublicNodeKindEnum>[
    file,
    folder,
  ];

  static PublicNodeKindEnum? fromJson(dynamic value) => PublicNodeKindEnumTypeTransformer().decode(value);

  static List<PublicNodeKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PublicNodeKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PublicNodeKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PublicNodeKindEnum] to String,
/// and [decode] dynamic data back to [PublicNodeKindEnum].
class PublicNodeKindEnumTypeTransformer {
  factory PublicNodeKindEnumTypeTransformer() => _instance ??= const PublicNodeKindEnumTypeTransformer._();

  const PublicNodeKindEnumTypeTransformer._();

  String encode(PublicNodeKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PublicNodeKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PublicNodeKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'file': return PublicNodeKindEnum.file;
        case r'folder': return PublicNodeKindEnum.folder;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PublicNodeKindEnumTypeTransformer] instance.
  static PublicNodeKindEnumTypeTransformer? _instance;
}



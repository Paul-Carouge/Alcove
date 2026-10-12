//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class AlbumSummary {
  /// Returns a new [AlbumSummary] instance.
  AlbumSummary({
    required this.id,
    required this.name,
    required this.role,
    required this.owner,
    required this.count,
    required this.shared,
    required this.cover,
    required this.updated,
  });

  String id;

  String name;

  /// The caller's role.
  AlbumSummaryRoleEnum role;

  AlbumSummaryOwner owner;

  /// Items not in the trash.
  int count;

  /// The album has participants.
  bool shared;

  MediaFiles? cover;

  DateTime updated;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AlbumSummary &&
    other.id == id &&
    other.name == name &&
    other.role == role &&
    other.owner == owner &&
    other.count == count &&
    other.shared == shared &&
    other.cover == cover &&
    other.updated == updated;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (role.hashCode) +
    (owner.hashCode) +
    (count.hashCode) +
    (shared.hashCode) +
    (cover == null ? 0 : cover!.hashCode) +
    (updated.hashCode);

  @override
  String toString() => 'AlbumSummary[id=$id, name=$name, role=$role, owner=$owner, count=$count, shared=$shared, cover=$cover, updated=$updated]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
      json[r'role'] = this.role;
      json[r'owner'] = this.owner;
      json[r'count'] = this.count;
      json[r'shared'] = this.shared;
    if (this.cover != null) {
      json[r'cover'] = this.cover;
    } else {
      json[r'cover'] = null;
    }
      json[r'updated'] = this.updated.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [AlbumSummary] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AlbumSummary? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AlbumSummary[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AlbumSummary[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AlbumSummary(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        role: AlbumSummaryRoleEnum.fromJson(json[r'role'])!,
        owner: AlbumSummaryOwner.fromJson(json[r'owner'])!,
        count: mapValueOfType<int>(json, r'count')!,
        shared: mapValueOfType<bool>(json, r'shared')!,
        cover: MediaFiles.fromJson(json[r'cover']),
        updated: mapDateTime(json, r'updated', r'')!,
      );
    }
    return null;
  }

  static List<AlbumSummary> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AlbumSummary>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AlbumSummary.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AlbumSummary> mapFromJson(dynamic json) {
    final map = <String, AlbumSummary>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AlbumSummary.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AlbumSummary-objects as value to a dart map
  static Map<String, List<AlbumSummary>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AlbumSummary>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AlbumSummary.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'role',
    'owner',
    'count',
    'shared',
    'cover',
    'updated',
  };
}

/// The caller's role.
class AlbumSummaryRoleEnum {
  /// Instantiate a new enum with the provided [value].
  const AlbumSummaryRoleEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const owner = AlbumSummaryRoleEnum._(r'owner');
  static const contributor = AlbumSummaryRoleEnum._(r'contributor');
  static const viewer = AlbumSummaryRoleEnum._(r'viewer');

  /// List of all possible values in this [enum][AlbumSummaryRoleEnum].
  static const values = <AlbumSummaryRoleEnum>[
    owner,
    contributor,
    viewer,
  ];

  static AlbumSummaryRoleEnum? fromJson(dynamic value) => AlbumSummaryRoleEnumTypeTransformer().decode(value);

  static List<AlbumSummaryRoleEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AlbumSummaryRoleEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AlbumSummaryRoleEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AlbumSummaryRoleEnum] to String,
/// and [decode] dynamic data back to [AlbumSummaryRoleEnum].
class AlbumSummaryRoleEnumTypeTransformer {
  factory AlbumSummaryRoleEnumTypeTransformer() => _instance ??= const AlbumSummaryRoleEnumTypeTransformer._();

  const AlbumSummaryRoleEnumTypeTransformer._();

  String encode(AlbumSummaryRoleEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AlbumSummaryRoleEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AlbumSummaryRoleEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'owner': return AlbumSummaryRoleEnum.owner;
        case r'contributor': return AlbumSummaryRoleEnum.contributor;
        case r'viewer': return AlbumSummaryRoleEnum.viewer;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AlbumSummaryRoleEnumTypeTransformer] instance.
  static AlbumSummaryRoleEnumTypeTransformer? _instance;
}



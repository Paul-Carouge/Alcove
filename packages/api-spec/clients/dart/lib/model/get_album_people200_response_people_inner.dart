//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class GetAlbumPeople200ResponsePeopleInner {
  /// Returns a new [GetAlbumPeople200ResponsePeopleInner] instance.
  GetAlbumPeople200ResponsePeopleInner({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  String id;

  /// May be empty.
  String name;

  String email;

  GetAlbumPeople200ResponsePeopleInnerRoleEnum role;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GetAlbumPeople200ResponsePeopleInner &&
    other.id == id &&
    other.name == name &&
    other.email == email &&
    other.role == role;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (email.hashCode) +
    (role.hashCode);

  @override
  String toString() => 'GetAlbumPeople200ResponsePeopleInner[id=$id, name=$name, email=$email, role=$role]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
      json[r'email'] = this.email;
      json[r'role'] = this.role;
    return json;
  }

  /// Returns a new [GetAlbumPeople200ResponsePeopleInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GetAlbumPeople200ResponsePeopleInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GetAlbumPeople200ResponsePeopleInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GetAlbumPeople200ResponsePeopleInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GetAlbumPeople200ResponsePeopleInner(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        email: mapValueOfType<String>(json, r'email')!,
        role: GetAlbumPeople200ResponsePeopleInnerRoleEnum.fromJson(json[r'role'])!,
      );
    }
    return null;
  }

  static List<GetAlbumPeople200ResponsePeopleInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GetAlbumPeople200ResponsePeopleInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GetAlbumPeople200ResponsePeopleInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GetAlbumPeople200ResponsePeopleInner> mapFromJson(dynamic json) {
    final map = <String, GetAlbumPeople200ResponsePeopleInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GetAlbumPeople200ResponsePeopleInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GetAlbumPeople200ResponsePeopleInner-objects as value to a dart map
  static Map<String, List<GetAlbumPeople200ResponsePeopleInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GetAlbumPeople200ResponsePeopleInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GetAlbumPeople200ResponsePeopleInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'email',
    'role',
  };
}


class GetAlbumPeople200ResponsePeopleInnerRoleEnum {
  /// Instantiate a new enum with the provided [value].
  const GetAlbumPeople200ResponsePeopleInnerRoleEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const viewer = GetAlbumPeople200ResponsePeopleInnerRoleEnum._(r'viewer');
  static const contributor = GetAlbumPeople200ResponsePeopleInnerRoleEnum._(r'contributor');

  /// List of all possible values in this [enum][GetAlbumPeople200ResponsePeopleInnerRoleEnum].
  static const values = <GetAlbumPeople200ResponsePeopleInnerRoleEnum>[
    viewer,
    contributor,
  ];

  static GetAlbumPeople200ResponsePeopleInnerRoleEnum? fromJson(dynamic value) => GetAlbumPeople200ResponsePeopleInnerRoleEnumTypeTransformer().decode(value);

  static List<GetAlbumPeople200ResponsePeopleInnerRoleEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GetAlbumPeople200ResponsePeopleInnerRoleEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GetAlbumPeople200ResponsePeopleInnerRoleEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [GetAlbumPeople200ResponsePeopleInnerRoleEnum] to String,
/// and [decode] dynamic data back to [GetAlbumPeople200ResponsePeopleInnerRoleEnum].
class GetAlbumPeople200ResponsePeopleInnerRoleEnumTypeTransformer {
  factory GetAlbumPeople200ResponsePeopleInnerRoleEnumTypeTransformer() => _instance ??= const GetAlbumPeople200ResponsePeopleInnerRoleEnumTypeTransformer._();

  const GetAlbumPeople200ResponsePeopleInnerRoleEnumTypeTransformer._();

  String encode(GetAlbumPeople200ResponsePeopleInnerRoleEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a GetAlbumPeople200ResponsePeopleInnerRoleEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  GetAlbumPeople200ResponsePeopleInnerRoleEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'viewer': return GetAlbumPeople200ResponsePeopleInnerRoleEnum.viewer;
        case r'contributor': return GetAlbumPeople200ResponsePeopleInnerRoleEnum.contributor;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [GetAlbumPeople200ResponsePeopleInnerRoleEnumTypeTransformer] instance.
  static GetAlbumPeople200ResponsePeopleInnerRoleEnumTypeTransformer? _instance;
}



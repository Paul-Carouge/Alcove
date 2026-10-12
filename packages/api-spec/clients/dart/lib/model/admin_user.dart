//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class AdminUser {
  /// Returns a new [AdminUser] instance.
  AdminUser({
    required this.id,
    required this.email,
    required this.name,
    required this.admin,
    required this.quotaBytes,
    required this.usedBytes,
    required this.twoFactor,
    required this.created,
  });

  String id;

  String email;

  String name;

  bool admin;

  /// 0 = unlimited.
  int quotaBytes;

  /// Files, trash included.
  int usedBytes;

  /// Uses an authenticator app.
  bool twoFactor;

  String created;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminUser &&
    other.id == id &&
    other.email == email &&
    other.name == name &&
    other.admin == admin &&
    other.quotaBytes == quotaBytes &&
    other.usedBytes == usedBytes &&
    other.twoFactor == twoFactor &&
    other.created == created;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (email.hashCode) +
    (name.hashCode) +
    (admin.hashCode) +
    (quotaBytes.hashCode) +
    (usedBytes.hashCode) +
    (twoFactor.hashCode) +
    (created.hashCode);

  @override
  String toString() => 'AdminUser[id=$id, email=$email, name=$name, admin=$admin, quotaBytes=$quotaBytes, usedBytes=$usedBytes, twoFactor=$twoFactor, created=$created]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'email'] = this.email;
      json[r'name'] = this.name;
      json[r'admin'] = this.admin;
      json[r'quotaBytes'] = this.quotaBytes;
      json[r'usedBytes'] = this.usedBytes;
      json[r'twoFactor'] = this.twoFactor;
      json[r'created'] = this.created;
    return json;
  }

  /// Returns a new [AdminUser] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminUser? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminUser[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminUser[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminUser(
        id: mapValueOfType<String>(json, r'id')!,
        email: mapValueOfType<String>(json, r'email')!,
        name: mapValueOfType<String>(json, r'name')!,
        admin: mapValueOfType<bool>(json, r'admin')!,
        quotaBytes: mapValueOfType<int>(json, r'quotaBytes')!,
        usedBytes: mapValueOfType<int>(json, r'usedBytes')!,
        twoFactor: mapValueOfType<bool>(json, r'twoFactor')!,
        created: mapValueOfType<String>(json, r'created')!,
      );
    }
    return null;
  }

  static List<AdminUser> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminUser>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminUser.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminUser> mapFromJson(dynamic json) {
    final map = <String, AdminUser>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminUser.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminUser-objects as value to a dart map
  static Map<String, List<AdminUser>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminUser>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminUser.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'email',
    'name',
    'admin',
    'quotaBytes',
    'usedBytes',
    'twoFactor',
    'created',
  };
}


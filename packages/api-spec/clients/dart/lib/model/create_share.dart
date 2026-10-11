//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class CreateShare {
  /// Returns a new [CreateShare] instance.
  CreateShare({
    required this.node,
    this.expiresAt,
    this.password,
  });

  /// Id of a file or folder you own (not trashed).
  String node;

  /// Optional expiry, in the future and at most one year ahead.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? expiresAt;

  /// Optional password visitors must enter.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? password;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateShare &&
    other.node == node &&
    other.expiresAt == expiresAt &&
    other.password == password;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (node.hashCode) +
    (expiresAt == null ? 0 : expiresAt!.hashCode) +
    (password == null ? 0 : password!.hashCode);

  @override
  String toString() => 'CreateShare[node=$node, expiresAt=$expiresAt, password=$password]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'node'] = this.node;
    if (this.expiresAt != null) {
      json[r'expiresAt'] = this.expiresAt!.toUtc().toIso8601String();
    } else {
      json[r'expiresAt'] = null;
    }
    if (this.password != null) {
      json[r'password'] = this.password;
    } else {
      json[r'password'] = null;
    }
    return json;
  }

  /// Returns a new [CreateShare] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateShare? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CreateShare[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CreateShare[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CreateShare(
        node: mapValueOfType<String>(json, r'node')!,
        expiresAt: mapDateTime(json, r'expiresAt', r''),
        password: mapValueOfType<String>(json, r'password'),
      );
    }
    return null;
  }

  static List<CreateShare> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateShare>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateShare.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateShare> mapFromJson(dynamic json) {
    final map = <String, CreateShare>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateShare.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateShare-objects as value to a dart map
  static Map<String, List<CreateShare>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateShare>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreateShare.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'node',
  };
}


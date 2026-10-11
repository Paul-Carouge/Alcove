//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class CreatedShare {
  /// Returns a new [CreatedShare] instance.
  CreatedShare({
    required this.id,
    required this.token,
    required this.expiresAt,
    required this.hasPassword,
  });

  String id;

  /// Secret link token. Shown only once.
  String token;

  DateTime? expiresAt;

  bool hasPassword;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreatedShare &&
    other.id == id &&
    other.token == token &&
    other.expiresAt == expiresAt &&
    other.hasPassword == hasPassword;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (token.hashCode) +
    (expiresAt == null ? 0 : expiresAt!.hashCode) +
    (hasPassword.hashCode);

  @override
  String toString() => 'CreatedShare[id=$id, token=$token, expiresAt=$expiresAt, hasPassword=$hasPassword]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'token'] = this.token;
    if (this.expiresAt != null) {
      json[r'expiresAt'] = this.expiresAt!.toUtc().toIso8601String();
    } else {
      json[r'expiresAt'] = null;
    }
      json[r'hasPassword'] = this.hasPassword;
    return json;
  }

  /// Returns a new [CreatedShare] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreatedShare? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CreatedShare[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CreatedShare[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CreatedShare(
        id: mapValueOfType<String>(json, r'id')!,
        token: mapValueOfType<String>(json, r'token')!,
        expiresAt: mapDateTime(json, r'expiresAt', r''),
        hasPassword: mapValueOfType<bool>(json, r'hasPassword')!,
      );
    }
    return null;
  }

  static List<CreatedShare> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreatedShare>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreatedShare.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreatedShare> mapFromJson(dynamic json) {
    final map = <String, CreatedShare>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreatedShare.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreatedShare-objects as value to a dart map
  static Map<String, List<CreatedShare>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreatedShare>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreatedShare.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'token',
    'expiresAt',
    'hasPassword',
  };
}


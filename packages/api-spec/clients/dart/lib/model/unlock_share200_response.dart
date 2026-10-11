//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class UnlockShare200Response {
  /// Returns a new [UnlockShare200Response] instance.
  UnlockShare200Response({
    required this.access,
    required this.expiresAt,
  });

  /// Pass as `access` query parameter.
  String access;

  DateTime expiresAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UnlockShare200Response &&
    other.access == access &&
    other.expiresAt == expiresAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (access.hashCode) +
    (expiresAt.hashCode);

  @override
  String toString() => 'UnlockShare200Response[access=$access, expiresAt=$expiresAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'access'] = this.access;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [UnlockShare200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UnlockShare200Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UnlockShare200Response[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UnlockShare200Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UnlockShare200Response(
        access: mapValueOfType<String>(json, r'access')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
      );
    }
    return null;
  }

  static List<UnlockShare200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UnlockShare200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UnlockShare200Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UnlockShare200Response> mapFromJson(dynamic json) {
    final map = <String, UnlockShare200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UnlockShare200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UnlockShare200Response-objects as value to a dart map
  static Map<String, List<UnlockShare200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UnlockShare200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UnlockShare200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'access',
    'expiresAt',
  };
}


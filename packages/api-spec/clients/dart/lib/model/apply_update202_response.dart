//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class ApplyUpdate202Response {
  /// Returns a new [ApplyUpdate202Response] instance.
  ApplyUpdate202Response({
    required this.version,
  });

  /// Version being started.
  String version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ApplyUpdate202Response &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (version.hashCode);

  @override
  String toString() => 'ApplyUpdate202Response[version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'version'] = this.version;
    return json;
  }

  /// Returns a new [ApplyUpdate202Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ApplyUpdate202Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ApplyUpdate202Response[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ApplyUpdate202Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ApplyUpdate202Response(
        version: mapValueOfType<String>(json, r'version')!,
      );
    }
    return null;
  }

  static List<ApplyUpdate202Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ApplyUpdate202Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ApplyUpdate202Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ApplyUpdate202Response> mapFromJson(dynamic json) {
    final map = <String, ApplyUpdate202Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ApplyUpdate202Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ApplyUpdate202Response-objects as value to a dart map
  static Map<String, List<ApplyUpdate202Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ApplyUpdate202Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ApplyUpdate202Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'version',
  };
}


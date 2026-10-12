//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class GetAndroidApp200Response {
  /// Returns a new [GetAndroidApp200Response] instance.
  GetAndroidApp200Response({
    required this.version,
    required this.available,
    this.size,
  });

  /// The server's version, e.g. 0.19.0.
  String version;

  /// An APK for this version exists (development builds: false).
  bool available;

  /// APK size in bytes, when known.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? size;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GetAndroidApp200Response &&
    other.version == version &&
    other.available == available &&
    other.size == size;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (version.hashCode) +
    (available.hashCode) +
    (size == null ? 0 : size!.hashCode);

  @override
  String toString() => 'GetAndroidApp200Response[version=$version, available=$available, size=$size]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'version'] = this.version;
      json[r'available'] = this.available;
    if (this.size != null) {
      json[r'size'] = this.size;
    } else {
      json[r'size'] = null;
    }
    return json;
  }

  /// Returns a new [GetAndroidApp200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GetAndroidApp200Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GetAndroidApp200Response[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GetAndroidApp200Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GetAndroidApp200Response(
        version: mapValueOfType<String>(json, r'version')!,
        available: mapValueOfType<bool>(json, r'available')!,
        size: mapValueOfType<int>(json, r'size'),
      );
    }
    return null;
  }

  static List<GetAndroidApp200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GetAndroidApp200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GetAndroidApp200Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GetAndroidApp200Response> mapFromJson(dynamic json) {
    final map = <String, GetAndroidApp200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GetAndroidApp200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GetAndroidApp200Response-objects as value to a dart map
  static Map<String, List<GetAndroidApp200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GetAndroidApp200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GetAndroidApp200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'version',
    'available',
  };
}


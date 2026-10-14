//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class CreateZip200Response {
  /// Returns a new [CreateZip200Response] instance.
  CreateZip200Response({
    required this.url,
    required this.files,
    required this.expiresAt,
  });

  String url;

  int files;

  DateTime expiresAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateZip200Response &&
    other.url == url &&
    other.files == files &&
    other.expiresAt == expiresAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (url.hashCode) +
    (files.hashCode) +
    (expiresAt.hashCode);

  @override
  String toString() => 'CreateZip200Response[url=$url, files=$files, expiresAt=$expiresAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'url'] = this.url;
      json[r'files'] = this.files;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [CreateZip200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateZip200Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CreateZip200Response[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CreateZip200Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CreateZip200Response(
        url: mapValueOfType<String>(json, r'url')!,
        files: mapValueOfType<int>(json, r'files')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
      );
    }
    return null;
  }

  static List<CreateZip200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateZip200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateZip200Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateZip200Response> mapFromJson(dynamic json) {
    final map = <String, CreateZip200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateZip200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateZip200Response-objects as value to a dart map
  static Map<String, List<CreateZip200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateZip200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreateZip200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'url',
    'files',
    'expiresAt',
  };
}


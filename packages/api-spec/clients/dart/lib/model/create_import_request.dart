//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class CreateImportRequest {
  /// Returns a new [CreateImportRequest] instance.
  CreateImportRequest({
    this.uploads = const [],
    this.serverFiles = const [],
    this.user,
  });

  List<String> uploads;

  List<String> serverFiles;

  /// Receiving account (administrators, with serverFiles).
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? user;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateImportRequest &&
    _deepEquality.equals(other.uploads, uploads) &&
    _deepEquality.equals(other.serverFiles, serverFiles) &&
    other.user == user;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (uploads.hashCode) +
    (serverFiles.hashCode) +
    (user == null ? 0 : user!.hashCode);

  @override
  String toString() => 'CreateImportRequest[uploads=$uploads, serverFiles=$serverFiles, user=$user]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'uploads'] = this.uploads;
      json[r'serverFiles'] = this.serverFiles;
    if (this.user != null) {
      json[r'user'] = this.user;
    } else {
      json[r'user'] = null;
    }
    return json;
  }

  /// Returns a new [CreateImportRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateImportRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CreateImportRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CreateImportRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CreateImportRequest(
        uploads: json[r'uploads'] is Iterable
            ? (json[r'uploads'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        serverFiles: json[r'serverFiles'] is Iterable
            ? (json[r'serverFiles'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        user: mapValueOfType<String>(json, r'user'),
      );
    }
    return null;
  }

  static List<CreateImportRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateImportRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateImportRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateImportRequest> mapFromJson(dynamic json) {
    final map = <String, CreateImportRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateImportRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateImportRequest-objects as value to a dart map
  static Map<String, List<CreateImportRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateImportRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreateImportRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class CreateZipRequest {
  /// Returns a new [CreateZipRequest] instance.
  CreateZipRequest({
    this.nodes = const [],
    this.album,
    this.name,
  });

  /// Your files or folders.
  List<String> nodes;

  /// An album you own or are part of (instead of nodes).
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? album;

  /// Archive name without .zip.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? name;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateZipRequest &&
    _deepEquality.equals(other.nodes, nodes) &&
    other.album == album &&
    other.name == name;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (nodes.hashCode) +
    (album == null ? 0 : album!.hashCode) +
    (name == null ? 0 : name!.hashCode);

  @override
  String toString() => 'CreateZipRequest[nodes=$nodes, album=$album, name=$name]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'nodes'] = this.nodes;
    if (this.album != null) {
      json[r'album'] = this.album;
    } else {
      json[r'album'] = null;
    }
    if (this.name != null) {
      json[r'name'] = this.name;
    } else {
      json[r'name'] = null;
    }
    return json;
  }

  /// Returns a new [CreateZipRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateZipRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CreateZipRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CreateZipRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CreateZipRequest(
        nodes: json[r'nodes'] is Iterable
            ? (json[r'nodes'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        album: mapValueOfType<String>(json, r'album'),
        name: mapValueOfType<String>(json, r'name'),
      );
    }
    return null;
  }

  static List<CreateZipRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateZipRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateZipRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateZipRequest> mapFromJson(dynamic json) {
    final map = <String, CreateZipRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateZipRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateZipRequest-objects as value to a dart map
  static Map<String, List<CreateZipRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateZipRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreateZipRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class SetMapTilesRequest {
  /// Returns a new [SetMapTilesRequest] instance.
  SetMapTilesRequest({
    required this.osm,
  });

  bool osm;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SetMapTilesRequest &&
    other.osm == osm;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (osm.hashCode);

  @override
  String toString() => 'SetMapTilesRequest[osm=$osm]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'osm'] = this.osm;
    return json;
  }

  /// Returns a new [SetMapTilesRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SetMapTilesRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SetMapTilesRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SetMapTilesRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SetMapTilesRequest(
        osm: mapValueOfType<bool>(json, r'osm')!,
      );
    }
    return null;
  }

  static List<SetMapTilesRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SetMapTilesRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SetMapTilesRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SetMapTilesRequest> mapFromJson(dynamic json) {
    final map = <String, SetMapTilesRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SetMapTilesRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SetMapTilesRequest-objects as value to a dart map
  static Map<String, List<SetMapTilesRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SetMapTilesRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SetMapTilesRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'osm',
  };
}


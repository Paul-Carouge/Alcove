//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class MapConfigTiles {
  /// Returns a new [MapConfigTiles] instance.
  MapConfigTiles({
    required this.url,
    required this.attribution,
    required this.maxZoom,
  });

  String url;

  String attribution;

  int maxZoom;

  @override
  bool operator ==(Object other) => identical(this, other) || other is MapConfigTiles &&
    other.url == url &&
    other.attribution == attribution &&
    other.maxZoom == maxZoom;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (url.hashCode) +
    (attribution.hashCode) +
    (maxZoom.hashCode);

  @override
  String toString() => 'MapConfigTiles[url=$url, attribution=$attribution, maxZoom=$maxZoom]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'url'] = this.url;
      json[r'attribution'] = this.attribution;
      json[r'maxZoom'] = this.maxZoom;
    return json;
  }

  /// Returns a new [MapConfigTiles] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MapConfigTiles? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "MapConfigTiles[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "MapConfigTiles[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return MapConfigTiles(
        url: mapValueOfType<String>(json, r'url')!,
        attribution: mapValueOfType<String>(json, r'attribution')!,
        maxZoom: mapValueOfType<int>(json, r'maxZoom')!,
      );
    }
    return null;
  }

  static List<MapConfigTiles> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MapConfigTiles>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MapConfigTiles.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MapConfigTiles> mapFromJson(dynamic json) {
    final map = <String, MapConfigTiles>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MapConfigTiles.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MapConfigTiles-objects as value to a dart map
  static Map<String, List<MapConfigTiles>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<MapConfigTiles>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MapConfigTiles.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'url',
    'attribution',
    'maxZoom',
  };
}


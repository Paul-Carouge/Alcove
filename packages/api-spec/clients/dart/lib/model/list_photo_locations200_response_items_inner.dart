//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class ListPhotoLocations200ResponseItemsInner {
  /// Returns a new [ListPhotoLocations200ResponseItemsInner] instance.
  ListPhotoLocations200ResponseItemsInner({
    required this.id,
    required this.lat,
    required this.lon,
    required this.thumb,
    required this.takenAt,
  });

  String id;

  num lat;

  num lon;

  String thumb;

  String takenAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListPhotoLocations200ResponseItemsInner &&
    other.id == id &&
    other.lat == lat &&
    other.lon == lon &&
    other.thumb == thumb &&
    other.takenAt == takenAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (lat.hashCode) +
    (lon.hashCode) +
    (thumb.hashCode) +
    (takenAt.hashCode);

  @override
  String toString() => 'ListPhotoLocations200ResponseItemsInner[id=$id, lat=$lat, lon=$lon, thumb=$thumb, takenAt=$takenAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'lat'] = this.lat;
      json[r'lon'] = this.lon;
      json[r'thumb'] = this.thumb;
      json[r'taken_at'] = this.takenAt;
    return json;
  }

  /// Returns a new [ListPhotoLocations200ResponseItemsInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListPhotoLocations200ResponseItemsInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ListPhotoLocations200ResponseItemsInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ListPhotoLocations200ResponseItemsInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ListPhotoLocations200ResponseItemsInner(
        id: mapValueOfType<String>(json, r'id')!,
        lat: num.parse('${json[r'lat']}'),
        lon: num.parse('${json[r'lon']}'),
        thumb: mapValueOfType<String>(json, r'thumb')!,
        takenAt: mapValueOfType<String>(json, r'taken_at')!,
      );
    }
    return null;
  }

  static List<ListPhotoLocations200ResponseItemsInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListPhotoLocations200ResponseItemsInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListPhotoLocations200ResponseItemsInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListPhotoLocations200ResponseItemsInner> mapFromJson(dynamic json) {
    final map = <String, ListPhotoLocations200ResponseItemsInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListPhotoLocations200ResponseItemsInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListPhotoLocations200ResponseItemsInner-objects as value to a dart map
  static Map<String, List<ListPhotoLocations200ResponseItemsInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListPhotoLocations200ResponseItemsInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListPhotoLocations200ResponseItemsInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'lat',
    'lon',
    'thumb',
    'taken_at',
  };
}


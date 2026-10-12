//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class ListPhotoLocations200Response {
  /// Returns a new [ListPhotoLocations200Response] instance.
  ListPhotoLocations200Response({
    required this.collectionId,
    this.items = const [],
  });

  /// The media collection (for thumbnail URLs).
  String collectionId;

  List<ListPhotoLocations200ResponseItemsInner> items;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListPhotoLocations200Response &&
    other.collectionId == collectionId &&
    _deepEquality.equals(other.items, items);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (collectionId.hashCode) +
    (items.hashCode);

  @override
  String toString() => 'ListPhotoLocations200Response[collectionId=$collectionId, items=$items]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'collectionId'] = this.collectionId;
      json[r'items'] = this.items;
    return json;
  }

  /// Returns a new [ListPhotoLocations200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListPhotoLocations200Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ListPhotoLocations200Response[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ListPhotoLocations200Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ListPhotoLocations200Response(
        collectionId: mapValueOfType<String>(json, r'collectionId')!,
        items: ListPhotoLocations200ResponseItemsInner.listFromJson(json[r'items']),
      );
    }
    return null;
  }

  static List<ListPhotoLocations200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListPhotoLocations200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListPhotoLocations200Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListPhotoLocations200Response> mapFromJson(dynamic json) {
    final map = <String, ListPhotoLocations200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListPhotoLocations200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListPhotoLocations200Response-objects as value to a dart map
  static Map<String, List<ListPhotoLocations200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListPhotoLocations200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListPhotoLocations200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'collectionId',
    'items',
  };
}


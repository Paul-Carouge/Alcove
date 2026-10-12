//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class ListAlbumItems200Response {
  /// Returns a new [ListAlbumItems200Response] instance.
  ListAlbumItems200Response({
    required this.page,
    required this.perPage,
    required this.totalItems,
    this.items = const [],
  });

  int page;

  int perPage;

  int totalItems;

  List<AlbumItem> items;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListAlbumItems200Response &&
    other.page == page &&
    other.perPage == perPage &&
    other.totalItems == totalItems &&
    _deepEquality.equals(other.items, items);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (page.hashCode) +
    (perPage.hashCode) +
    (totalItems.hashCode) +
    (items.hashCode);

  @override
  String toString() => 'ListAlbumItems200Response[page=$page, perPage=$perPage, totalItems=$totalItems, items=$items]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'page'] = this.page;
      json[r'perPage'] = this.perPage;
      json[r'totalItems'] = this.totalItems;
      json[r'items'] = this.items;
    return json;
  }

  /// Returns a new [ListAlbumItems200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListAlbumItems200Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ListAlbumItems200Response[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ListAlbumItems200Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ListAlbumItems200Response(
        page: mapValueOfType<int>(json, r'page')!,
        perPage: mapValueOfType<int>(json, r'perPage')!,
        totalItems: mapValueOfType<int>(json, r'totalItems')!,
        items: AlbumItem.listFromJson(json[r'items']),
      );
    }
    return null;
  }

  static List<ListAlbumItems200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListAlbumItems200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListAlbumItems200Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListAlbumItems200Response> mapFromJson(dynamic json) {
    final map = <String, ListAlbumItems200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListAlbumItems200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListAlbumItems200Response-objects as value to a dart map
  static Map<String, List<ListAlbumItems200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListAlbumItems200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListAlbumItems200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'page',
    'perPage',
    'totalItems',
    'items',
  };
}


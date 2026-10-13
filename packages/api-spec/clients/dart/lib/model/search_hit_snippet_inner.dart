//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class SearchHitSnippetInner {
  /// Returns a new [SearchHitSnippetInner] instance.
  SearchHitSnippetInner({
    required this.text,
    this.hit,
  });

  String text;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? hit;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SearchHitSnippetInner &&
    other.text == text &&
    other.hit == hit;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (text.hashCode) +
    (hit == null ? 0 : hit!.hashCode);

  @override
  String toString() => 'SearchHitSnippetInner[text=$text, hit=$hit]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'text'] = this.text;
    if (this.hit != null) {
      json[r'hit'] = this.hit;
    } else {
      json[r'hit'] = null;
    }
    return json;
  }

  /// Returns a new [SearchHitSnippetInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SearchHitSnippetInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SearchHitSnippetInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SearchHitSnippetInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SearchHitSnippetInner(
        text: mapValueOfType<String>(json, r'text')!,
        hit: mapValueOfType<bool>(json, r'hit'),
      );
    }
    return null;
  }

  static List<SearchHitSnippetInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SearchHitSnippetInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SearchHitSnippetInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SearchHitSnippetInner> mapFromJson(dynamic json) {
    final map = <String, SearchHitSnippetInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SearchHitSnippetInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SearchHitSnippetInner-objects as value to a dart map
  static Map<String, List<SearchHitSnippetInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SearchHitSnippetInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SearchHitSnippetInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'text',
  };
}


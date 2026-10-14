//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class SearchHit {
  /// Returns a new [SearchHit] instance.
  SearchHit({
    required this.node,
    required this.match,
    this.tag,
    this.snippet = const [],
  });

  /// The `nodes` record, with `expand.parent` when it is in a folder.
  Object node;

  SearchHitMatchEnum match;

  /// Name of the matching tag (tag matches only).
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? tag;

  /// Text around the matching words (content matches only).
  List<SearchHitSnippetInner> snippet;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SearchHit &&
    other.node == node &&
    other.match == match &&
    other.tag == tag &&
    _deepEquality.equals(other.snippet, snippet);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (node.hashCode) +
    (match.hashCode) +
    (tag == null ? 0 : tag!.hashCode) +
    (snippet.hashCode);

  @override
  String toString() => 'SearchHit[node=$node, match=$match, tag=$tag, snippet=$snippet]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'node'] = this.node;
      json[r'match'] = this.match;
    if (this.tag != null) {
      json[r'tag'] = this.tag;
    } else {
      json[r'tag'] = null;
    }
      json[r'snippet'] = this.snippet;
    return json;
  }

  /// Returns a new [SearchHit] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SearchHit? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SearchHit[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SearchHit[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SearchHit(
        node: mapValueOfType<Object>(json, r'node')!,
        match: SearchHitMatchEnum.fromJson(json[r'match'])!,
        tag: mapValueOfType<String>(json, r'tag'),
        snippet: SearchHitSnippetInner.listFromJson(json[r'snippet']),
      );
    }
    return null;
  }

  static List<SearchHit> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SearchHit>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SearchHit.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SearchHit> mapFromJson(dynamic json) {
    final map = <String, SearchHit>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SearchHit.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SearchHit-objects as value to a dart map
  static Map<String, List<SearchHit>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SearchHit>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SearchHit.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'node',
    'match',
  };
}


class SearchHitMatchEnum {
  /// Instantiate a new enum with the provided [value].
  const SearchHitMatchEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const name = SearchHitMatchEnum._(r'name');
  static const tag = SearchHitMatchEnum._(r'tag');
  static const content = SearchHitMatchEnum._(r'content');

  /// List of all possible values in this [enum][SearchHitMatchEnum].
  static const values = <SearchHitMatchEnum>[
    name,
    tag,
    content,
  ];

  static SearchHitMatchEnum? fromJson(dynamic value) => SearchHitMatchEnumTypeTransformer().decode(value);

  static List<SearchHitMatchEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SearchHitMatchEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SearchHitMatchEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SearchHitMatchEnum] to String,
/// and [decode] dynamic data back to [SearchHitMatchEnum].
class SearchHitMatchEnumTypeTransformer {
  factory SearchHitMatchEnumTypeTransformer() => _instance ??= const SearchHitMatchEnumTypeTransformer._();

  const SearchHitMatchEnumTypeTransformer._();

  String encode(SearchHitMatchEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SearchHitMatchEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SearchHitMatchEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'name': return SearchHitMatchEnum.name;
        case r'tag': return SearchHitMatchEnum.tag;
        case r'content': return SearchHitMatchEnum.content;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SearchHitMatchEnumTypeTransformer] instance.
  static SearchHitMatchEnumTypeTransformer? _instance;
}



//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class SearchableJob {
  /// Returns a new [SearchableJob] instance.
  SearchableJob({
    required this.status,
    this.node,
    this.error,
  });

  SearchableJobStatusEnum status;

  /// Id of the new file (done).
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? node;

  /// Why it failed (failed).
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? error;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SearchableJob &&
    other.status == status &&
    other.node == node &&
    other.error == error;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (status.hashCode) +
    (node == null ? 0 : node!.hashCode) +
    (error == null ? 0 : error!.hashCode);

  @override
  String toString() => 'SearchableJob[status=$status, node=$node, error=$error]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'status'] = this.status;
    if (this.node != null) {
      json[r'node'] = this.node;
    } else {
      json[r'node'] = null;
    }
    if (this.error != null) {
      json[r'error'] = this.error;
    } else {
      json[r'error'] = null;
    }
    return json;
  }

  /// Returns a new [SearchableJob] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SearchableJob? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SearchableJob[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SearchableJob[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SearchableJob(
        status: SearchableJobStatusEnum.fromJson(json[r'status'])!,
        node: mapValueOfType<String>(json, r'node'),
        error: mapValueOfType<String>(json, r'error'),
      );
    }
    return null;
  }

  static List<SearchableJob> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SearchableJob>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SearchableJob.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SearchableJob> mapFromJson(dynamic json) {
    final map = <String, SearchableJob>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SearchableJob.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SearchableJob-objects as value to a dart map
  static Map<String, List<SearchableJob>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SearchableJob>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SearchableJob.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'status',
  };
}


class SearchableJobStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const SearchableJobStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const idle = SearchableJobStatusEnum._(r'idle');
  static const running = SearchableJobStatusEnum._(r'running');
  static const done = SearchableJobStatusEnum._(r'done');
  static const failed = SearchableJobStatusEnum._(r'failed');

  /// List of all possible values in this [enum][SearchableJobStatusEnum].
  static const values = <SearchableJobStatusEnum>[
    idle,
    running,
    done,
    failed,
  ];

  static SearchableJobStatusEnum? fromJson(dynamic value) => SearchableJobStatusEnumTypeTransformer().decode(value);

  static List<SearchableJobStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SearchableJobStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SearchableJobStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SearchableJobStatusEnum] to String,
/// and [decode] dynamic data back to [SearchableJobStatusEnum].
class SearchableJobStatusEnumTypeTransformer {
  factory SearchableJobStatusEnumTypeTransformer() => _instance ??= const SearchableJobStatusEnumTypeTransformer._();

  const SearchableJobStatusEnumTypeTransformer._();

  String encode(SearchableJobStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SearchableJobStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SearchableJobStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'idle': return SearchableJobStatusEnum.idle;
        case r'running': return SearchableJobStatusEnum.running;
        case r'done': return SearchableJobStatusEnum.done;
        case r'failed': return SearchableJobStatusEnum.failed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SearchableJobStatusEnumTypeTransformer] instance.
  static SearchableJobStatusEnumTypeTransformer? _instance;
}



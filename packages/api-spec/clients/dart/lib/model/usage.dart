//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class Usage {
  /// Returns a new [Usage] instance.
  Usage({
    required this.used,
    required this.trash,
    required this.quota,
  });

  /// Bytes used, trash included.
  int used;

  /// Bytes in the trash (part of used).
  int trash;

  /// Quota in bytes; 0 means unlimited.
  int quota;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Usage &&
    other.used == used &&
    other.trash == trash &&
    other.quota == quota;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (used.hashCode) +
    (trash.hashCode) +
    (quota.hashCode);

  @override
  String toString() => 'Usage[used=$used, trash=$trash, quota=$quota]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'used'] = this.used;
      json[r'trash'] = this.trash;
      json[r'quota'] = this.quota;
    return json;
  }

  /// Returns a new [Usage] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Usage? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "Usage[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "Usage[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return Usage(
        used: mapValueOfType<int>(json, r'used')!,
        trash: mapValueOfType<int>(json, r'trash')!,
        quota: mapValueOfType<int>(json, r'quota')!,
      );
    }
    return null;
  }

  static List<Usage> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Usage>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Usage.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Usage> mapFromJson(dynamic json) {
    final map = <String, Usage>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Usage.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Usage-objects as value to a dart map
  static Map<String, List<Usage>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Usage>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Usage.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'used',
    'trash',
    'quota',
  };
}


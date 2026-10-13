//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class OCRStatusCounts {
  /// Returns a new [OCRStatusCounts] instance.
  OCRStatusCounts({
    required this.pending,
    required this.ready,
    required this.skipped,
    required this.failed,
  });

  int pending;

  int ready;

  int skipped;

  int failed;

  @override
  bool operator ==(Object other) => identical(this, other) || other is OCRStatusCounts &&
    other.pending == pending &&
    other.ready == ready &&
    other.skipped == skipped &&
    other.failed == failed;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (pending.hashCode) +
    (ready.hashCode) +
    (skipped.hashCode) +
    (failed.hashCode);

  @override
  String toString() => 'OCRStatusCounts[pending=$pending, ready=$ready, skipped=$skipped, failed=$failed]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'pending'] = this.pending;
      json[r'ready'] = this.ready;
      json[r'skipped'] = this.skipped;
      json[r'failed'] = this.failed;
    return json;
  }

  /// Returns a new [OCRStatusCounts] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static OCRStatusCounts? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "OCRStatusCounts[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "OCRStatusCounts[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return OCRStatusCounts(
        pending: mapValueOfType<int>(json, r'pending')!,
        ready: mapValueOfType<int>(json, r'ready')!,
        skipped: mapValueOfType<int>(json, r'skipped')!,
        failed: mapValueOfType<int>(json, r'failed')!,
      );
    }
    return null;
  }

  static List<OCRStatusCounts> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OCRStatusCounts>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OCRStatusCounts.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, OCRStatusCounts> mapFromJson(dynamic json) {
    final map = <String, OCRStatusCounts>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = OCRStatusCounts.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of OCRStatusCounts-objects as value to a dart map
  static Map<String, List<OCRStatusCounts>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<OCRStatusCounts>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = OCRStatusCounts.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'pending',
    'ready',
    'skipped',
    'failed',
  };
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class OCRStatus {
  /// Returns a new [OCRStatus] instance.
  OCRStatus({
    required this.enabled,
    required this.tools,
    required this.bundle,
    required this.canInstall,
    required this.hint,
    required this.counts,
  });

  bool enabled;

  OCRStatusTools tools;

  /// Directory of Alcove's own OCR tools, empty when not used.
  String bundle;

  bool canInstall;

  /// Command installing the tools (macOS, Windows), or empty.
  String hint;

  OCRStatusCounts counts;

  @override
  bool operator ==(Object other) => identical(this, other) || other is OCRStatus &&
    other.enabled == enabled &&
    other.tools == tools &&
    other.bundle == bundle &&
    other.canInstall == canInstall &&
    other.hint == hint &&
    other.counts == counts;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (enabled.hashCode) +
    (tools.hashCode) +
    (bundle.hashCode) +
    (canInstall.hashCode) +
    (hint.hashCode) +
    (counts.hashCode);

  @override
  String toString() => 'OCRStatus[enabled=$enabled, tools=$tools, bundle=$bundle, canInstall=$canInstall, hint=$hint, counts=$counts]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'enabled'] = this.enabled;
      json[r'tools'] = this.tools;
      json[r'bundle'] = this.bundle;
      json[r'canInstall'] = this.canInstall;
      json[r'hint'] = this.hint;
      json[r'counts'] = this.counts;
    return json;
  }

  /// Returns a new [OCRStatus] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static OCRStatus? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "OCRStatus[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "OCRStatus[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return OCRStatus(
        enabled: mapValueOfType<bool>(json, r'enabled')!,
        tools: OCRStatusTools.fromJson(json[r'tools'])!,
        bundle: mapValueOfType<String>(json, r'bundle')!,
        canInstall: mapValueOfType<bool>(json, r'canInstall')!,
        hint: mapValueOfType<String>(json, r'hint')!,
        counts: OCRStatusCounts.fromJson(json[r'counts'])!,
      );
    }
    return null;
  }

  static List<OCRStatus> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OCRStatus>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OCRStatus.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, OCRStatus> mapFromJson(dynamic json) {
    final map = <String, OCRStatus>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = OCRStatus.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of OCRStatus-objects as value to a dart map
  static Map<String, List<OCRStatus>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<OCRStatus>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = OCRStatus.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'enabled',
    'tools',
    'bundle',
    'canInstall',
    'hint',
    'counts',
  };
}


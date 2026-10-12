//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class RecoveryCodes {
  /// Returns a new [RecoveryCodes] instance.
  RecoveryCodes({
    this.recoveryCodes = const [],
  });

  /// Single-use codes, shown only in this response.
  List<String> recoveryCodes;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RecoveryCodes &&
    _deepEquality.equals(other.recoveryCodes, recoveryCodes);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (recoveryCodes.hashCode);

  @override
  String toString() => 'RecoveryCodes[recoveryCodes=$recoveryCodes]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'recoveryCodes'] = this.recoveryCodes;
    return json;
  }

  /// Returns a new [RecoveryCodes] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RecoveryCodes? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "RecoveryCodes[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "RecoveryCodes[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return RecoveryCodes(
        recoveryCodes: json[r'recoveryCodes'] is Iterable
            ? (json[r'recoveryCodes'] as Iterable).cast<String>().toList(growable: false)
            : const [],
      );
    }
    return null;
  }

  static List<RecoveryCodes> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RecoveryCodes>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RecoveryCodes.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RecoveryCodes> mapFromJson(dynamic json) {
    final map = <String, RecoveryCodes>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RecoveryCodes.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RecoveryCodes-objects as value to a dart map
  static Map<String, List<RecoveryCodes>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RecoveryCodes>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RecoveryCodes.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'recoveryCodes',
  };
}


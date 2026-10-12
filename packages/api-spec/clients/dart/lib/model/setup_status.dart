//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class SetupStatus {
  /// Returns a new [SetupStatus] instance.
  SetupStatus({
    required this.storage,
  });

  SetupStatusStorage storage;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SetupStatus &&
    other.storage == storage;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (storage.hashCode);

  @override
  String toString() => 'SetupStatus[storage=$storage]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'storage'] = this.storage;
    return json;
  }

  /// Returns a new [SetupStatus] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SetupStatus? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SetupStatus[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SetupStatus[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SetupStatus(
        storage: SetupStatusStorage.fromJson(json[r'storage'])!,
      );
    }
    return null;
  }

  static List<SetupStatus> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SetupStatus>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SetupStatus.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SetupStatus> mapFromJson(dynamic json) {
    final map = <String, SetupStatus>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SetupStatus.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SetupStatus-objects as value to a dart map
  static Map<String, List<SetupStatus>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SetupStatus>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SetupStatus.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'storage',
  };
}


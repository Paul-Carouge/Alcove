//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class TotpConfirm {
  /// Returns a new [TotpConfirm] instance.
  TotpConfirm({
    required this.password,
    required this.code,
  });

  String password;

  /// 6-digit code or a recovery code.
  String code;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TotpConfirm &&
    other.password == password &&
    other.code == code;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (password.hashCode) +
    (code.hashCode);

  @override
  String toString() => 'TotpConfirm[password=$password, code=$code]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'password'] = this.password;
      json[r'code'] = this.code;
    return json;
  }

  /// Returns a new [TotpConfirm] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TotpConfirm? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "TotpConfirm[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "TotpConfirm[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return TotpConfirm(
        password: mapValueOfType<String>(json, r'password')!,
        code: mapValueOfType<String>(json, r'code')!,
      );
    }
    return null;
  }

  static List<TotpConfirm> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TotpConfirm>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TotpConfirm.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TotpConfirm> mapFromJson(dynamic json) {
    final map = <String, TotpConfirm>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TotpConfirm.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TotpConfirm-objects as value to a dart map
  static Map<String, List<TotpConfirm>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TotpConfirm>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TotpConfirm.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'password',
    'code',
  };
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class TestSetupSmtpRequest {
  /// Returns a new [TestSetupSmtpRequest] instance.
  TestSetupSmtpRequest({
    required this.token,
    required this.smtp,
    required this.to,
  });

  String token;

  SmtpSettings smtp;

  String to;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TestSetupSmtpRequest &&
    other.token == token &&
    other.smtp == smtp &&
    other.to == to;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (token.hashCode) +
    (smtp.hashCode) +
    (to.hashCode);

  @override
  String toString() => 'TestSetupSmtpRequest[token=$token, smtp=$smtp, to=$to]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'token'] = this.token;
      json[r'smtp'] = this.smtp;
      json[r'to'] = this.to;
    return json;
  }

  /// Returns a new [TestSetupSmtpRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TestSetupSmtpRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "TestSetupSmtpRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "TestSetupSmtpRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return TestSetupSmtpRequest(
        token: mapValueOfType<String>(json, r'token')!,
        smtp: SmtpSettings.fromJson(json[r'smtp'])!,
        to: mapValueOfType<String>(json, r'to')!,
      );
    }
    return null;
  }

  static List<TestSetupSmtpRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TestSetupSmtpRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TestSetupSmtpRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TestSetupSmtpRequest> mapFromJson(dynamic json) {
    final map = <String, TestSetupSmtpRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TestSetupSmtpRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TestSetupSmtpRequest-objects as value to a dart map
  static Map<String, List<TestSetupSmtpRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TestSetupSmtpRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TestSetupSmtpRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'token',
    'smtp',
    'to',
  };
}


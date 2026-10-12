//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class CompleteSetupRequest {
  /// Returns a new [CompleteSetupRequest] instance.
  CompleteSetupRequest({
    required this.token,
    required this.admin,
    this.smtp,
  });

  String token;

  CompleteSetupRequestAllOfAdmin admin;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  SmtpSettings? smtp;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CompleteSetupRequest &&
    other.token == token &&
    other.admin == admin &&
    other.smtp == smtp;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (token.hashCode) +
    (admin.hashCode) +
    (smtp == null ? 0 : smtp!.hashCode);

  @override
  String toString() => 'CompleteSetupRequest[token=$token, admin=$admin, smtp=$smtp]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'token'] = this.token;
      json[r'admin'] = this.admin;
    if (this.smtp != null) {
      json[r'smtp'] = this.smtp;
    } else {
      json[r'smtp'] = null;
    }
    return json;
  }

  /// Returns a new [CompleteSetupRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CompleteSetupRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CompleteSetupRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CompleteSetupRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CompleteSetupRequest(
        token: mapValueOfType<String>(json, r'token')!,
        admin: CompleteSetupRequestAllOfAdmin.fromJson(json[r'admin'])!,
        smtp: SmtpSettings.fromJson(json[r'smtp']),
      );
    }
    return null;
  }

  static List<CompleteSetupRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CompleteSetupRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CompleteSetupRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CompleteSetupRequest> mapFromJson(dynamic json) {
    final map = <String, CompleteSetupRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CompleteSetupRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CompleteSetupRequest-objects as value to a dart map
  static Map<String, List<CompleteSetupRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CompleteSetupRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CompleteSetupRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'token',
    'admin',
  };
}


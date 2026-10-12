//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class SmtpSettings {
  /// Returns a new [SmtpSettings] instance.
  SmtpSettings({
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.tls,
    required this.senderAddress,
    this.senderName,
  });

  String host;

  /// Minimum value: 1
  /// Maximum value: 65535
  int port;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? username;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? password;

  /// Implicit TLS (usually port 465); STARTTLS is used otherwise when offered.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? tls;

  String senderAddress;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? senderName;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SmtpSettings &&
    other.host == host &&
    other.port == port &&
    other.username == username &&
    other.password == password &&
    other.tls == tls &&
    other.senderAddress == senderAddress &&
    other.senderName == senderName;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (host.hashCode) +
    (port.hashCode) +
    (username == null ? 0 : username!.hashCode) +
    (password == null ? 0 : password!.hashCode) +
    (tls == null ? 0 : tls!.hashCode) +
    (senderAddress.hashCode) +
    (senderName == null ? 0 : senderName!.hashCode);

  @override
  String toString() => 'SmtpSettings[host=$host, port=$port, username=$username, password=$password, tls=$tls, senderAddress=$senderAddress, senderName=$senderName]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'host'] = this.host;
      json[r'port'] = this.port;
    if (this.username != null) {
      json[r'username'] = this.username;
    } else {
      json[r'username'] = null;
    }
    if (this.password != null) {
      json[r'password'] = this.password;
    } else {
      json[r'password'] = null;
    }
    if (this.tls != null) {
      json[r'tls'] = this.tls;
    } else {
      json[r'tls'] = null;
    }
      json[r'senderAddress'] = this.senderAddress;
    if (this.senderName != null) {
      json[r'senderName'] = this.senderName;
    } else {
      json[r'senderName'] = null;
    }
    return json;
  }

  /// Returns a new [SmtpSettings] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SmtpSettings? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SmtpSettings[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SmtpSettings[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SmtpSettings(
        host: mapValueOfType<String>(json, r'host')!,
        port: mapValueOfType<int>(json, r'port')!,
        username: mapValueOfType<String>(json, r'username'),
        password: mapValueOfType<String>(json, r'password'),
        tls: mapValueOfType<bool>(json, r'tls'),
        senderAddress: mapValueOfType<String>(json, r'senderAddress')!,
        senderName: mapValueOfType<String>(json, r'senderName'),
      );
    }
    return null;
  }

  static List<SmtpSettings> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SmtpSettings>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SmtpSettings.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SmtpSettings> mapFromJson(dynamic json) {
    final map = <String, SmtpSettings>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SmtpSettings.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SmtpSettings-objects as value to a dart map
  static Map<String, List<SmtpSettings>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SmtpSettings>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SmtpSettings.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'host',
    'port',
    'senderAddress',
  };
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class KnownHashesRequest {
  /// Returns a new [KnownHashesRequest] instance.
  KnownHashesRequest({
    this.hashes = const [],
  });

  List<String> hashes;

  @override
  bool operator ==(Object other) => identical(this, other) || other is KnownHashesRequest &&
    _deepEquality.equals(other.hashes, hashes);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (hashes.hashCode);

  @override
  String toString() => 'KnownHashesRequest[hashes=$hashes]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'hashes'] = this.hashes;
    return json;
  }

  /// Returns a new [KnownHashesRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static KnownHashesRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "KnownHashesRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "KnownHashesRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return KnownHashesRequest(
        hashes: json[r'hashes'] is Iterable
            ? (json[r'hashes'] as Iterable).cast<String>().toList(growable: false)
            : const [],
      );
    }
    return null;
  }

  static List<KnownHashesRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <KnownHashesRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = KnownHashesRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, KnownHashesRequest> mapFromJson(dynamic json) {
    final map = <String, KnownHashesRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = KnownHashesRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of KnownHashesRequest-objects as value to a dart map
  static Map<String, List<KnownHashesRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<KnownHashesRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = KnownHashesRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'hashes',
  };
}


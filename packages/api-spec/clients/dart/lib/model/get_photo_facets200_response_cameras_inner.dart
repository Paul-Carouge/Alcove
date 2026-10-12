//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class GetPhotoFacets200ResponseCamerasInner {
  /// Returns a new [GetPhotoFacets200ResponseCamerasInner] instance.
  GetPhotoFacets200ResponseCamerasInner({
    required this.make,
    required this.model,
    required this.count,
  });

  String make;

  String model;

  int count;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GetPhotoFacets200ResponseCamerasInner &&
    other.make == make &&
    other.model == model &&
    other.count == count;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (make.hashCode) +
    (model.hashCode) +
    (count.hashCode);

  @override
  String toString() => 'GetPhotoFacets200ResponseCamerasInner[make=$make, model=$model, count=$count]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'make'] = this.make;
      json[r'model'] = this.model;
      json[r'count'] = this.count;
    return json;
  }

  /// Returns a new [GetPhotoFacets200ResponseCamerasInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GetPhotoFacets200ResponseCamerasInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GetPhotoFacets200ResponseCamerasInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GetPhotoFacets200ResponseCamerasInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GetPhotoFacets200ResponseCamerasInner(
        make: mapValueOfType<String>(json, r'make')!,
        model: mapValueOfType<String>(json, r'model')!,
        count: mapValueOfType<int>(json, r'count')!,
      );
    }
    return null;
  }

  static List<GetPhotoFacets200ResponseCamerasInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GetPhotoFacets200ResponseCamerasInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GetPhotoFacets200ResponseCamerasInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GetPhotoFacets200ResponseCamerasInner> mapFromJson(dynamic json) {
    final map = <String, GetPhotoFacets200ResponseCamerasInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GetPhotoFacets200ResponseCamerasInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GetPhotoFacets200ResponseCamerasInner-objects as value to a dart map
  static Map<String, List<GetPhotoFacets200ResponseCamerasInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GetPhotoFacets200ResponseCamerasInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GetPhotoFacets200ResponseCamerasInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'make',
    'model',
    'count',
  };
}


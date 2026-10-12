//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class MediaFiles {
  /// Returns a new [MediaFiles] instance.
  MediaFiles({
    required this.id,
    required this.collectionId,
    required this.thumb,
    required this.preview,
  });

  String id;

  String collectionId;

  String thumb;

  String preview;

  @override
  bool operator ==(Object other) => identical(this, other) || other is MediaFiles &&
    other.id == id &&
    other.collectionId == collectionId &&
    other.thumb == thumb &&
    other.preview == preview;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (collectionId.hashCode) +
    (thumb.hashCode) +
    (preview.hashCode);

  @override
  String toString() => 'MediaFiles[id=$id, collectionId=$collectionId, thumb=$thumb, preview=$preview]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'collectionId'] = this.collectionId;
      json[r'thumb'] = this.thumb;
      json[r'preview'] = this.preview;
    return json;
  }

  /// Returns a new [MediaFiles] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MediaFiles? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "MediaFiles[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "MediaFiles[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return MediaFiles(
        id: mapValueOfType<String>(json, r'id')!,
        collectionId: mapValueOfType<String>(json, r'collectionId')!,
        thumb: mapValueOfType<String>(json, r'thumb')!,
        preview: mapValueOfType<String>(json, r'preview')!,
      );
    }
    return null;
  }

  static List<MediaFiles> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MediaFiles>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MediaFiles.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MediaFiles> mapFromJson(dynamic json) {
    final map = <String, MediaFiles>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MediaFiles.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MediaFiles-objects as value to a dart map
  static Map<String, List<MediaFiles>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<MediaFiles>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MediaFiles.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'collectionId',
    'thumb',
    'preview',
  };
}


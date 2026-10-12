//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class PublicShare {
  /// Returns a new [PublicShare] instance.
  PublicShare({
    this.item,
    this.album,
    this.media = const [],
    required this.expiresAt,
    this.folder,
    this.path = const [],
    this.children = const [],
  });

  /// The shared file or folder (absent for albums).
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  PublicNode? item;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  PublicShareAlbum? album;

  /// The album's photos and videos, newest first (album links only).
  List<PublicMedia> media;

  DateTime? expiresAt;

  /// The folder being listed (shared folders only).
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  PublicNode? folder;

  /// Folders from the shared root down to `folder`.
  List<PublicNode> path;

  List<PublicNode> children;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PublicShare &&
    other.item == item &&
    other.album == album &&
    _deepEquality.equals(other.media, media) &&
    other.expiresAt == expiresAt &&
    other.folder == folder &&
    _deepEquality.equals(other.path, path) &&
    _deepEquality.equals(other.children, children);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (item == null ? 0 : item!.hashCode) +
    (album == null ? 0 : album!.hashCode) +
    (media.hashCode) +
    (expiresAt == null ? 0 : expiresAt!.hashCode) +
    (folder == null ? 0 : folder!.hashCode) +
    (path.hashCode) +
    (children.hashCode);

  @override
  String toString() => 'PublicShare[item=$item, album=$album, media=$media, expiresAt=$expiresAt, folder=$folder, path=$path, children=$children]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.item != null) {
      json[r'item'] = this.item;
    } else {
      json[r'item'] = null;
    }
    if (this.album != null) {
      json[r'album'] = this.album;
    } else {
      json[r'album'] = null;
    }
      json[r'media'] = this.media;
    if (this.expiresAt != null) {
      json[r'expiresAt'] = this.expiresAt!.toUtc().toIso8601String();
    } else {
      json[r'expiresAt'] = null;
    }
    if (this.folder != null) {
      json[r'folder'] = this.folder;
    } else {
      json[r'folder'] = null;
    }
      json[r'path'] = this.path;
      json[r'children'] = this.children;
    return json;
  }

  /// Returns a new [PublicShare] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PublicShare? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PublicShare[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PublicShare[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PublicShare(
        item: PublicNode.fromJson(json[r'item']),
        album: PublicShareAlbum.fromJson(json[r'album']),
        media: PublicMedia.listFromJson(json[r'media']),
        expiresAt: mapDateTime(json, r'expiresAt', r''),
        folder: PublicNode.fromJson(json[r'folder']),
        path: PublicNode.listFromJson(json[r'path']),
        children: PublicNode.listFromJson(json[r'children']),
      );
    }
    return null;
  }

  static List<PublicShare> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PublicShare>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PublicShare.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PublicShare> mapFromJson(dynamic json) {
    final map = <String, PublicShare>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PublicShare.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PublicShare-objects as value to a dart map
  static Map<String, List<PublicShare>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PublicShare>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PublicShare.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expiresAt',
  };
}


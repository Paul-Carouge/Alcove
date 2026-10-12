//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class SystemInfo {
  /// Returns a new [SystemInfo] instance.
  SystemInfo({
    required this.version,
    required this.installMode,
    required this.canSelfUpdate,
    this.updateCommand,
    required this.ffmpeg,
    required this.update,
  });

  String version;

  /// native = installed by `alcove install`; manual = started by hand.
  SystemInfoInstallModeEnum installMode;

  /// The \"Update now\" button can be used.
  bool canSelfUpdate;

  /// Command to run on the host when self-update is not possible.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? updateCommand;

  /// ffmpeg is available (video and HEIC thumbnails).
  bool ffmpeg;

  SystemInfoUpdate update;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SystemInfo &&
    other.version == version &&
    other.installMode == installMode &&
    other.canSelfUpdate == canSelfUpdate &&
    other.updateCommand == updateCommand &&
    other.ffmpeg == ffmpeg &&
    other.update == update;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (version.hashCode) +
    (installMode.hashCode) +
    (canSelfUpdate.hashCode) +
    (updateCommand == null ? 0 : updateCommand!.hashCode) +
    (ffmpeg.hashCode) +
    (update.hashCode);

  @override
  String toString() => 'SystemInfo[version=$version, installMode=$installMode, canSelfUpdate=$canSelfUpdate, updateCommand=$updateCommand, ffmpeg=$ffmpeg, update=$update]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'version'] = this.version;
      json[r'installMode'] = this.installMode;
      json[r'canSelfUpdate'] = this.canSelfUpdate;
    if (this.updateCommand != null) {
      json[r'updateCommand'] = this.updateCommand;
    } else {
      json[r'updateCommand'] = null;
    }
      json[r'ffmpeg'] = this.ffmpeg;
      json[r'update'] = this.update;
    return json;
  }

  /// Returns a new [SystemInfo] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SystemInfo? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SystemInfo[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SystemInfo[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SystemInfo(
        version: mapValueOfType<String>(json, r'version')!,
        installMode: SystemInfoInstallModeEnum.fromJson(json[r'installMode'])!,
        canSelfUpdate: mapValueOfType<bool>(json, r'canSelfUpdate')!,
        updateCommand: mapValueOfType<String>(json, r'updateCommand'),
        ffmpeg: mapValueOfType<bool>(json, r'ffmpeg')!,
        update: SystemInfoUpdate.fromJson(json[r'update'])!,
      );
    }
    return null;
  }

  static List<SystemInfo> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SystemInfo>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SystemInfo.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SystemInfo> mapFromJson(dynamic json) {
    final map = <String, SystemInfo>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SystemInfo.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SystemInfo-objects as value to a dart map
  static Map<String, List<SystemInfo>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SystemInfo>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SystemInfo.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'version',
    'installMode',
    'canSelfUpdate',
    'ffmpeg',
    'update',
  };
}

/// native = installed by `alcove install`; manual = started by hand.
class SystemInfoInstallModeEnum {
  /// Instantiate a new enum with the provided [value].
  const SystemInfoInstallModeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const native_ = SystemInfoInstallModeEnum._(r'native');
  static const docker = SystemInfoInstallModeEnum._(r'docker');
  static const manual = SystemInfoInstallModeEnum._(r'manual');

  /// List of all possible values in this [enum][SystemInfoInstallModeEnum].
  static const values = <SystemInfoInstallModeEnum>[
    native_,
    docker,
    manual,
  ];

  static SystemInfoInstallModeEnum? fromJson(dynamic value) => SystemInfoInstallModeEnumTypeTransformer().decode(value);

  static List<SystemInfoInstallModeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SystemInfoInstallModeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SystemInfoInstallModeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SystemInfoInstallModeEnum] to String,
/// and [decode] dynamic data back to [SystemInfoInstallModeEnum].
class SystemInfoInstallModeEnumTypeTransformer {
  factory SystemInfoInstallModeEnumTypeTransformer() => _instance ??= const SystemInfoInstallModeEnumTypeTransformer._();

  const SystemInfoInstallModeEnumTypeTransformer._();

  String encode(SystemInfoInstallModeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SystemInfoInstallModeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SystemInfoInstallModeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'native': return SystemInfoInstallModeEnum.native_;
        case r'docker': return SystemInfoInstallModeEnum.docker;
        case r'manual': return SystemInfoInstallModeEnum.manual;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SystemInfoInstallModeEnumTypeTransformer] instance.
  static SystemInfoInstallModeEnumTypeTransformer? _instance;
}



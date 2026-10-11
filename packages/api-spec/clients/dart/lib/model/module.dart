//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;


class Module {
  /// Instantiate a new enum with the provided [value].
  const Module._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const core = Module._(r'core');
  static const drive = Module._(r'drive');
  static const photos = Module._(r'photos');
  static const documents = Module._(r'documents');
  static const ocr = Module._(r'ocr');
  static const faces = Module._(r'faces');
  static const notes = Module._(r'notes');
  static const calendar = Module._(r'calendar');
  static const contacts = Module._(r'contacts');

  /// List of all possible values in this [enum][Module].
  static const values = <Module>[
    core,
    drive,
    photos,
    documents,
    ocr,
    faces,
    notes,
    calendar,
    contacts,
  ];

  static Module? fromJson(dynamic value) => ModuleTypeTransformer().decode(value);

  static List<Module> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Module>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Module.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [Module] to String,
/// and [decode] dynamic data back to [Module].
class ModuleTypeTransformer {
  factory ModuleTypeTransformer() => _instance ??= const ModuleTypeTransformer._();

  const ModuleTypeTransformer._();

  String encode(Module data) => data.value;

  /// Decodes a [dynamic value][data] to a Module.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  Module? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'core': return Module.core;
        case r'drive': return Module.drive;
        case r'photos': return Module.photos;
        case r'documents': return Module.documents;
        case r'ocr': return Module.ocr;
        case r'faces': return Module.faces;
        case r'notes': return Module.notes;
        case r'calendar': return Module.calendar;
        case r'contacts': return Module.contacts;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ModuleTypeTransformer] instance.
  static ModuleTypeTransformer? _instance;
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class ImportJob {
  /// Returns a new [ImportJob] instance.
  ImportJob({
    required this.id,
    required this.owner,
    this.createdBy,
    required this.source_,
    this.files = const [],
    required this.status,
    this.error,
    required this.total,
    required this.processed,
    required this.imported,
    required this.duplicates,
    required this.skipped,
    required this.undated,
    required this.failed,
    required this.albums,
    this.failures = const [],
    this.startedAt,
    this.finishedAt,
    this.created,
    this.updated,
  });

  String id;

  /// Account receiving the photos.
  String owner;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? createdBy;

  ImportJobSource_Enum source_;

  List<String> files;

  ImportJobStatusEnum status;

  /// Why a job failed: `quota_exceeded`, `disk_full`, `no_photos`, `unreadable`, `too_many_entries`, `unsafe_archive` (overlapping entries, oversized central directory, decompression budget exceeded), `interrupted` (stopped by three restarts in a row), `internal`; empty otherwise. 
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? error;

  /// Photos and videos found in the archives.
  int total;

  int processed;

  int imported;

  /// Already in the account (same SHA-256).
  int duplicates;

  /// In Google's trash.
  int skipped;

  /// Imported without a Google date (EXIF or upload date used).
  int undated;

  int failed;

  /// Albums created or completed.
  int albums;

  /// The first 1000 failures.
  List<ImportJobFailuresInner> failures;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? startedAt;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? finishedAt;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? created;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? updated;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ImportJob &&
    other.id == id &&
    other.owner == owner &&
    other.createdBy == createdBy &&
    other.source_ == source_ &&
    _deepEquality.equals(other.files, files) &&
    other.status == status &&
    other.error == error &&
    other.total == total &&
    other.processed == processed &&
    other.imported == imported &&
    other.duplicates == duplicates &&
    other.skipped == skipped &&
    other.undated == undated &&
    other.failed == failed &&
    other.albums == albums &&
    _deepEquality.equals(other.failures, failures) &&
    other.startedAt == startedAt &&
    other.finishedAt == finishedAt &&
    other.created == created &&
    other.updated == updated;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (owner.hashCode) +
    (createdBy == null ? 0 : createdBy!.hashCode) +
    (source_.hashCode) +
    (files.hashCode) +
    (status.hashCode) +
    (error == null ? 0 : error!.hashCode) +
    (total.hashCode) +
    (processed.hashCode) +
    (imported.hashCode) +
    (duplicates.hashCode) +
    (skipped.hashCode) +
    (undated.hashCode) +
    (failed.hashCode) +
    (albums.hashCode) +
    (failures.hashCode) +
    (startedAt == null ? 0 : startedAt!.hashCode) +
    (finishedAt == null ? 0 : finishedAt!.hashCode) +
    (created == null ? 0 : created!.hashCode) +
    (updated == null ? 0 : updated!.hashCode);

  @override
  String toString() => 'ImportJob[id=$id, owner=$owner, createdBy=$createdBy, source_=$source_, files=$files, status=$status, error=$error, total=$total, processed=$processed, imported=$imported, duplicates=$duplicates, skipped=$skipped, undated=$undated, failed=$failed, albums=$albums, failures=$failures, startedAt=$startedAt, finishedAt=$finishedAt, created=$created, updated=$updated]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'owner'] = this.owner;
    if (this.createdBy != null) {
      json[r'created_by'] = this.createdBy;
    } else {
      json[r'created_by'] = null;
    }
      json[r'source'] = this.source_;
      json[r'files'] = this.files;
      json[r'status'] = this.status;
    if (this.error != null) {
      json[r'error'] = this.error;
    } else {
      json[r'error'] = null;
    }
      json[r'total'] = this.total;
      json[r'processed'] = this.processed;
      json[r'imported'] = this.imported;
      json[r'duplicates'] = this.duplicates;
      json[r'skipped'] = this.skipped;
      json[r'undated'] = this.undated;
      json[r'failed'] = this.failed;
      json[r'albums'] = this.albums;
      json[r'failures'] = this.failures;
    if (this.startedAt != null) {
      json[r'started_at'] = this.startedAt;
    } else {
      json[r'started_at'] = null;
    }
    if (this.finishedAt != null) {
      json[r'finished_at'] = this.finishedAt;
    } else {
      json[r'finished_at'] = null;
    }
    if (this.created != null) {
      json[r'created'] = this.created;
    } else {
      json[r'created'] = null;
    }
    if (this.updated != null) {
      json[r'updated'] = this.updated;
    } else {
      json[r'updated'] = null;
    }
    return json;
  }

  /// Returns a new [ImportJob] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportJob? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ImportJob[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ImportJob[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ImportJob(
        id: mapValueOfType<String>(json, r'id')!,
        owner: mapValueOfType<String>(json, r'owner')!,
        createdBy: mapValueOfType<String>(json, r'created_by'),
        source_: ImportJobSource_Enum.fromJson(json[r'source'])!,
        files: json[r'files'] is Iterable
            ? (json[r'files'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        status: ImportJobStatusEnum.fromJson(json[r'status'])!,
        error: mapValueOfType<String>(json, r'error'),
        total: mapValueOfType<int>(json, r'total')!,
        processed: mapValueOfType<int>(json, r'processed')!,
        imported: mapValueOfType<int>(json, r'imported')!,
        duplicates: mapValueOfType<int>(json, r'duplicates')!,
        skipped: mapValueOfType<int>(json, r'skipped')!,
        undated: mapValueOfType<int>(json, r'undated')!,
        failed: mapValueOfType<int>(json, r'failed')!,
        albums: mapValueOfType<int>(json, r'albums')!,
        failures: ImportJobFailuresInner.listFromJson(json[r'failures']),
        startedAt: mapValueOfType<String>(json, r'started_at'),
        finishedAt: mapValueOfType<String>(json, r'finished_at'),
        created: mapValueOfType<String>(json, r'created'),
        updated: mapValueOfType<String>(json, r'updated'),
      );
    }
    return null;
  }

  static List<ImportJob> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ImportJob>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportJob.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportJob> mapFromJson(dynamic json) {
    final map = <String, ImportJob>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportJob.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportJob-objects as value to a dart map
  static Map<String, List<ImportJob>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ImportJob>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportJob.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'owner',
    'source',
    'status',
    'total',
    'processed',
    'imported',
    'duplicates',
    'skipped',
    'undated',
    'failed',
    'albums',
  };
}


class ImportJobSource_Enum {
  /// Instantiate a new enum with the provided [value].
  const ImportJobSource_Enum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const upload = ImportJobSource_Enum._(r'upload');
  static const server = ImportJobSource_Enum._(r'server');

  /// List of all possible values in this [enum][ImportJobSource_Enum].
  static const values = <ImportJobSource_Enum>[
    upload,
    server,
  ];

  static ImportJobSource_Enum? fromJson(dynamic value) => ImportJobSource_EnumTypeTransformer().decode(value);

  static List<ImportJobSource_Enum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ImportJobSource_Enum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportJobSource_Enum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ImportJobSource_Enum] to String,
/// and [decode] dynamic data back to [ImportJobSource_Enum].
class ImportJobSource_EnumTypeTransformer {
  factory ImportJobSource_EnumTypeTransformer() => _instance ??= const ImportJobSource_EnumTypeTransformer._();

  const ImportJobSource_EnumTypeTransformer._();

  String encode(ImportJobSource_Enum data) => data.value;

  /// Decodes a [dynamic value][data] to a ImportJobSource_Enum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ImportJobSource_Enum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'upload': return ImportJobSource_Enum.upload;
        case r'server': return ImportJobSource_Enum.server;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ImportJobSource_EnumTypeTransformer] instance.
  static ImportJobSource_EnumTypeTransformer? _instance;
}



class ImportJobStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const ImportJobStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const queued = ImportJobStatusEnum._(r'queued');
  static const scanning = ImportJobStatusEnum._(r'scanning');
  static const running = ImportJobStatusEnum._(r'running');
  static const done = ImportJobStatusEnum._(r'done');
  static const failed = ImportJobStatusEnum._(r'failed');
  static const cancelled = ImportJobStatusEnum._(r'cancelled');

  /// List of all possible values in this [enum][ImportJobStatusEnum].
  static const values = <ImportJobStatusEnum>[
    queued,
    scanning,
    running,
    done,
    failed,
    cancelled,
  ];

  static ImportJobStatusEnum? fromJson(dynamic value) => ImportJobStatusEnumTypeTransformer().decode(value);

  static List<ImportJobStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ImportJobStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportJobStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ImportJobStatusEnum] to String,
/// and [decode] dynamic data back to [ImportJobStatusEnum].
class ImportJobStatusEnumTypeTransformer {
  factory ImportJobStatusEnumTypeTransformer() => _instance ??= const ImportJobStatusEnumTypeTransformer._();

  const ImportJobStatusEnumTypeTransformer._();

  String encode(ImportJobStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ImportJobStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ImportJobStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'queued': return ImportJobStatusEnum.queued;
        case r'scanning': return ImportJobStatusEnum.scanning;
        case r'running': return ImportJobStatusEnum.running;
        case r'done': return ImportJobStatusEnum.done;
        case r'failed': return ImportJobStatusEnum.failed;
        case r'cancelled': return ImportJobStatusEnum.cancelled;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ImportJobStatusEnumTypeTransformer] instance.
  static ImportJobStatusEnumTypeTransformer? _instance;
}



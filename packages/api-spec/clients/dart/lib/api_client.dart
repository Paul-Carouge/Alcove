//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;

class ApiClient {
  ApiClient({this.basePath = 'http://localhost:8090', this.authentication,});

  final String basePath;
  final Authentication? authentication;

  var _client = Client();
  final _defaultHeaderMap = <String, String>{};

  /// Returns the current HTTP [Client] instance to use in this class.
  ///
  /// The return value is guaranteed to never be null.
  Client get client => _client;

  /// Requests to use a new HTTP [Client] in this class.
  set client(Client newClient) {
    _client = newClient;
  }

  Map<String, String> get defaultHeaderMap => _defaultHeaderMap;

  void addDefaultHeader(String key, String value) {
     _defaultHeaderMap[key] = value;
  }

  // We don't use a Map<String, String> for queryParams.
  // If collectionFormat is 'multi', a key might appear multiple times.
  Future<Response> invokeAPI(
    String path,
    String method,
    List<QueryParam> queryParams,
    Object? body,
    Map<String, String> headerParams,
    Map<String, String> formParams,
    String? contentType,
  ) async {
    await authentication?.applyToParams(queryParams, headerParams);

    headerParams.addAll(_defaultHeaderMap);
    if (contentType != null) {
      headerParams['Content-Type'] = contentType;
    }

    final urlEncodedQueryParams = queryParams.map((param) => '$param');
    final queryString = urlEncodedQueryParams.isNotEmpty ? '?${urlEncodedQueryParams.join('&')}' : '';
    final uri = Uri.parse('$basePath$path$queryString');

    try {
      // Special case for uploading a single file which isn't a 'multipart/form-data'.
      if (
        body is MultipartFile && (contentType == null ||
        !contentType.toLowerCase().startsWith('multipart/form-data'))
      ) {
        final request = StreamedRequest(method, uri);
        request.headers.addAll(headerParams);
        request.contentLength = body.length;
        body.finalize().listen(
          request.sink.add,
          onDone: request.sink.close,
          // ignore: avoid_types_on_closure_parameters
          onError: (Object error, StackTrace trace) => request.sink.close(),
          cancelOnError: true,
        );
        final response = await _client.send(request);
        return Response.fromStream(response);
      }

      if (body is MultipartRequest) {
        final request = MultipartRequest(method, uri);
        request.fields.addAll(body.fields);
        request.files.addAll(body.files);
        request.headers.addAll(body.headers);
        request.headers.addAll(headerParams);
        final response = await _client.send(request);
        return Response.fromStream(response);
      }

      final msgBody = contentType == 'application/x-www-form-urlencoded'
        ? formParams
        : await serializeAsync(body);
      final nullableHeaderParams = headerParams.isEmpty ? null : headerParams;

      switch(method) {
        case 'POST': return await _client.post(uri, headers: nullableHeaderParams, body: msgBody,);
        case 'PUT': return await _client.put(uri, headers: nullableHeaderParams, body: msgBody,);
        case 'DELETE': return await _client.delete(uri, headers: nullableHeaderParams, body: msgBody,);
        case 'PATCH': return await _client.patch(uri, headers: nullableHeaderParams, body: msgBody,);
        case 'HEAD': return await _client.head(uri, headers: nullableHeaderParams,);
        case 'GET': return await _client.get(uri, headers: nullableHeaderParams,);
      }
    } on SocketException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'Socket operation failed: $method $path',
        error,
        trace,
      );
    } on TlsException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'TLS/SSL communication failed: $method $path',
        error,
        trace,
      );
    } on IOException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'I/O operation failed: $method $path',
        error,
        trace,
      );
    } on ClientException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'HTTP connection failed: $method $path',
        error,
        trace,
      );
    } on Exception catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'Exception occurred: $method $path',
        error,
        trace,
      );
    }

    throw ApiException(
      HttpStatus.badRequest,
      'Invalid HTTP operation: $method $path',
    );
  }

  Future<dynamic> deserializeAsync(String value, String targetType, {bool growable = false,}) async =>
    // ignore: deprecated_member_use_from_same_package
    deserialize(value, targetType, growable: growable);

  @Deprecated('Scheduled for removal in OpenAPI Generator 6.x. Use deserializeAsync() instead.')
  dynamic deserialize(String value, String targetType, {bool growable = false,}) {
    // Remove all spaces. Necessary for regular expressions as well.
    targetType = targetType.replaceAll(' ', ''); // ignore: parameter_assignments

    // If the expected target type is String, nothing to do...
    return targetType == 'String'
      ? value
      : fromJson(json.decode(value), targetType, growable: growable);
  }

  // ignore: deprecated_member_use_from_same_package
  Future<String> serializeAsync(Object? value) async => serialize(value);

  @Deprecated('Scheduled for removal in OpenAPI Generator 6.x. Use serializeAsync() instead.')
  String serialize(Object? value) => value == null ? '' : json.encode(value);

  /// Returns a native instance of an OpenAPI class matching the [specified type][targetType].
  static dynamic fromJson(dynamic value, String targetType, {bool growable = false,}) {
    try {
      switch (targetType) {
        case 'String':
          return value is String ? value : value.toString();
        case 'int':
          return value is int ? value : int.parse('$value');
        case 'double':
          return value is double ? value : double.parse('$value');
        case 'bool':
          if (value is bool) {
            return value;
          }
          final valueString = '$value'.toLowerCase();
          return valueString == 'true' || valueString == '1';
        case 'DateTime':
          return value is DateTime ? value : DateTime.tryParse(value);
        case 'AdminUser':
          return AdminUser.fromJson(value);
        case 'AlbumItem':
          return AlbumItem.fromJson(value);
        case 'AlbumSummary':
          return AlbumSummary.fromJson(value);
        case 'AlbumSummaryOwner':
          return AlbumSummaryOwner.fromJson(value);
        case 'ApiRange':
          return ApiRange.fromJson(value);
        case 'ApplyUpdate202Response':
          return ApplyUpdate202Response.fromJson(value);
        case 'CompleteSetupRequest':
          return CompleteSetupRequest.fromJson(value);
        case 'CompleteSetupRequestAllOfAdmin':
          return CompleteSetupRequestAllOfAdmin.fromJson(value);
        case 'CreateImportRequest':
          return CreateImportRequest.fromJson(value);
        case 'CreateShare':
          return CreateShare.fromJson(value);
        case 'CreateUserRequest':
          return CreateUserRequest.fromJson(value);
        case 'CreateZip200Response':
          return CreateZip200Response.fromJson(value);
        case 'CreateZipRequest':
          return CreateZipRequest.fromJson(value);
        case 'CreatedShare':
          return CreatedShare.fromJson(value);
        case 'DismissDuplicatesRequest':
          return DismissDuplicatesRequest.fromJson(value);
        case 'DuplicateGroup':
          return DuplicateGroup.fromJson(value);
        case 'DuplicateItem':
          return DuplicateItem.fromJson(value);
        case 'EnableTotpRequest':
          return EnableTotpRequest.fromJson(value);
        case 'Error':
          return Error.fromJson(value);
        case 'GetAlbumPeople200Response':
          return GetAlbumPeople200Response.fromJson(value);
        case 'GetAlbumPeople200ResponsePeopleInner':
          return GetAlbumPeople200ResponsePeopleInner.fromJson(value);
        case 'GetAndroidApp200Response':
          return GetAndroidApp200Response.fromJson(value);
        case 'GetMemories200Response':
          return GetMemories200Response.fromJson(value);
        case 'GetMemories200ResponseMemoriesInner':
          return GetMemories200ResponseMemoriesInner.fromJson(value);
        case 'GetPhotoFacets200Response':
          return GetPhotoFacets200Response.fromJson(value);
        case 'GetPhotoFacets200ResponseCamerasInner':
          return GetPhotoFacets200ResponseCamerasInner.fromJson(value);
        case 'GetPhotoFacets200ResponseYearsInner':
          return GetPhotoFacets200ResponseYearsInner.fromJson(value);
        case 'Health':
          return Health.fromJson(value);
        case 'ImportJob':
          return ImportJob.fromJson(value);
        case 'ImportJobFailuresInner':
          return ImportJobFailuresInner.fromJson(value);
        case 'ImportUpload':
          return ImportUpload.fromJson(value);
        case 'KnownHashes200Response':
          return KnownHashes200Response.fromJson(value);
        case 'KnownHashesRequest':
          return KnownHashesRequest.fromJson(value);
        case 'ListAlbumItems200Response':
          return ListAlbumItems200Response.fromJson(value);
        case 'ListAlbums200Response':
          return ListAlbums200Response.fromJson(value);
        case 'ListDuplicates200Response':
          return ListDuplicates200Response.fromJson(value);
        case 'ListImportServerFiles200Response':
          return ListImportServerFiles200Response.fromJson(value);
        case 'ListImportServerFiles200ResponseItemsInner':
          return ListImportServerFiles200ResponseItemsInner.fromJson(value);
        case 'ListImportUploads200Response':
          return ListImportUploads200Response.fromJson(value);
        case 'ListPhotoLocations200Response':
          return ListPhotoLocations200Response.fromJson(value);
        case 'ListPhotoLocations200ResponseItemsInner':
          return ListPhotoLocations200ResponseItemsInner.fromJson(value);
        case 'ListUsers200Response':
          return ListUsers200Response.fromJson(value);
        case 'MapConfig':
          return MapConfig.fromJson(value);
        case 'MapConfigTiles':
          return MapConfigTiles.fromJson(value);
        case 'MediaFiles':
          return MediaFiles.fromJson(value);
        case 'MediaRecord':
          return MediaRecord.fromJson(value);
        case 'Module':
          return ModuleTypeTransformer().decode(value);
        case 'OCRStatus':
          return OCRStatus.fromJson(value);
        case 'OCRStatusCounts':
          return OCRStatusCounts.fromJson(value);
        case 'OCRStatusTools':
          return OCRStatusTools.fromJson(value);
        case 'Person':
          return Person.fromJson(value);
        case 'PublicMedia':
          return PublicMedia.fromJson(value);
        case 'PublicNode':
          return PublicNode.fromJson(value);
        case 'PublicShare':
          return PublicShare.fromJson(value);
        case 'PublicShareAlbum':
          return PublicShareAlbum.fromJson(value);
        case 'RecoveryCodes':
          return RecoveryCodes.fromJson(value);
        case 'Search200Response':
          return Search200Response.fromJson(value);
        case 'SearchHit':
          return SearchHit.fromJson(value);
        case 'SearchHitSnippetInner':
          return SearchHitSnippetInner.fromJson(value);
        case 'SearchableJob':
          return SearchableJob.fromJson(value);
        case 'SetFavoriteRequest':
          return SetFavoriteRequest.fromJson(value);
        case 'SetMapTilesRequest':
          return SetMapTilesRequest.fromJson(value);
        case 'SetOCRRequest':
          return SetOCRRequest.fromJson(value);
        case 'SetupStatus':
          return SetupStatus.fromJson(value);
        case 'SetupStatusStorage':
          return SetupStatusStorage.fromJson(value);
        case 'SetupToken':
          return SetupToken.fromJson(value);
        case 'SmtpSettings':
          return SmtpSettings.fromJson(value);
        case 'SystemInfo':
          return SystemInfo.fromJson(value);
        case 'SystemInfoUpdate':
          return SystemInfoUpdate.fromJson(value);
        case 'TestSetupSmtpRequest':
          return TestSetupSmtpRequest.fromJson(value);
        case 'TotpConfirm':
          return TotpConfirm.fromJson(value);
        case 'TotpSetup':
          return TotpSetup.fromJson(value);
        case 'TotpStatus':
          return TotpStatus.fromJson(value);
        case 'UnlockShare200Response':
          return UnlockShare200Response.fromJson(value);
        case 'UnlockShareRequest':
          return UnlockShareRequest.fromJson(value);
        case 'UpdateUserRequest':
          return UpdateUserRequest.fromJson(value);
        case 'Usage':
          return Usage.fromJson(value);
        default:
          dynamic match;
          if (value is List && (match = _regList.firstMatch(targetType)?.group(1)) != null) {
            return value
              .map<dynamic>((dynamic v) => fromJson(v, match, growable: growable,))
              .toList(growable: growable);
          }
          if (value is Set && (match = _regSet.firstMatch(targetType)?.group(1)) != null) {
            return value
              .map<dynamic>((dynamic v) => fromJson(v, match, growable: growable,))
              .toSet();
          }
          if (value is Map && (match = _regMap.firstMatch(targetType)?.group(1)) != null) {
            return Map<String, dynamic>.fromIterables(
              value.keys.cast<String>(),
              value.values.map<dynamic>((dynamic v) => fromJson(v, match, growable: growable,)),
            );
          }
      }
    } on Exception catch (error, trace) {
      throw ApiException.withInner(HttpStatus.internalServerError, 'Exception during deserialization.', error, trace,);
    }
    throw ApiException(HttpStatus.internalServerError, 'Could not find a suitable class for deserialization',);
  }
}

/// Primarily intended for use in an isolate.
class DeserializationMessage {
  const DeserializationMessage({
    required this.json,
    required this.targetType,
    this.growable = false,
  });

  /// The JSON value to deserialize.
  final String json;

  /// Target type to deserialize to.
  final String targetType;

  /// Whether to make deserialized lists or maps growable.
  final bool growable;
}

/// Primarily intended for use in an isolate.
Future<dynamic> decodeAsync(DeserializationMessage message) async {
  // Remove all spaces. Necessary for regular expressions as well.
  final targetType = message.targetType.replaceAll(' ', '');

  // If the expected target type is String, nothing to do...
  return targetType == 'String'
    ? message.json
    : json.decode(message.json);
}

/// Primarily intended for use in an isolate.
Future<dynamic> deserializeAsync(DeserializationMessage message) async {
  // Remove all spaces. Necessary for regular expressions as well.
  final targetType = message.targetType.replaceAll(' ', '');

  // If the expected target type is String, nothing to do...
  return targetType == 'String'
    ? message.json
    : ApiClient.fromJson(
        json.decode(message.json),
        targetType,
        growable: message.growable,
      );
}

/// Primarily intended for use in an isolate.
Future<String> serializeAsync(Object? value) async => value == null ? '' : json.encode(value);

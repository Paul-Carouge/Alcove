//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;


class UploadsApi {
  UploadsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Append a chunk (max 64 MiB per request).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] tusResumable (required):
  ///
  /// * [int] uploadOffset (required):
  ///
  /// * [String] uploadId (required):
  ///
  /// * [MultipartFile] body (required):
  Future<Response> appendUploadWithHttpInfo(String tusResumable, int uploadOffset, String uploadId, MultipartFile body,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/uploads/{uploadId}'
      .replaceAll('{uploadId}', uploadId);

    // ignore: prefer_final_locals
    Object? postBody = body;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Tus-Resumable'] = parameterToString(tusResumable);
    headerParams[r'Upload-Offset'] = parameterToString(uploadOffset);

    const contentTypes = <String>['application/offset+octet-stream'];


    return apiClient.invokeAPI(
      path,
      'PATCH',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Append a chunk (max 64 MiB per request).
  ///
  /// Parameters:
  ///
  /// * [String] tusResumable (required):
  ///
  /// * [int] uploadOffset (required):
  ///
  /// * [String] uploadId (required):
  ///
  /// * [MultipartFile] body (required):
  Future<void> appendUpload(String tusResumable, int uploadOffset, String uploadId, MultipartFile body,) async {
    final response = await appendUploadWithHttpInfo(tusResumable, uploadOffset, uploadId, body,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Cancel an upload and delete its partial data.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] tusResumable (required):
  ///
  /// * [String] uploadId (required):
  Future<Response> cancelUploadWithHttpInfo(String tusResumable, String uploadId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/uploads/{uploadId}'
      .replaceAll('{uploadId}', uploadId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Tus-Resumable'] = parameterToString(tusResumable);

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Cancel an upload and delete its partial data.
  ///
  /// Parameters:
  ///
  /// * [String] tusResumable (required):
  ///
  /// * [String] uploadId (required):
  Future<void> cancelUpload(String tusResumable, String uploadId,) async {
    final response = await cancelUploadWithHttpInfo(tusResumable, uploadId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Start a resumable upload (tus creation).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] tusResumable (required):
  ///
  /// * [int] uploadLength (required):
  ///   Total size in bytes (deferred length is not supported). Max 64 GiB.
  ///
  /// * [String] uploadMetadata (required):
  ///   tus metadata (comma-separated `key base64(value)` pairs). Keys: `filename` (required, a valid node name), `parent` (optional, id of a folder owned by the caller; empty = root). Other keys are ignored. 
  Future<Response> createUploadWithHttpInfo(String tusResumable, int uploadLength, String uploadMetadata,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/uploads/';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Tus-Resumable'] = parameterToString(tusResumable);
    headerParams[r'Upload-Length'] = parameterToString(uploadLength);
    headerParams[r'Upload-Metadata'] = parameterToString(uploadMetadata);

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Start a resumable upload (tus creation).
  ///
  /// Parameters:
  ///
  /// * [String] tusResumable (required):
  ///
  /// * [int] uploadLength (required):
  ///   Total size in bytes (deferred length is not supported). Max 64 GiB.
  ///
  /// * [String] uploadMetadata (required):
  ///   tus metadata (comma-separated `key base64(value)` pairs). Keys: `filename` (required, a valid node name), `parent` (optional, id of a folder owned by the caller; empty = root). Other keys are ignored. 
  Future<void> createUpload(String tusResumable, int uploadLength, String uploadMetadata,) async {
    final response = await createUploadWithHttpInfo(tusResumable, uploadLength, uploadMetadata,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Get the current offset of an upload (to resume).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] tusResumable (required):
  ///
  /// * [String] uploadId (required):
  Future<Response> getUploadOffsetWithHttpInfo(String tusResumable, String uploadId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/uploads/{uploadId}'
      .replaceAll('{uploadId}', uploadId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Tus-Resumable'] = parameterToString(tusResumable);

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'HEAD',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Get the current offset of an upload (to resume).
  ///
  /// Parameters:
  ///
  /// * [String] tusResumable (required):
  ///
  /// * [String] uploadId (required):
  Future<void> getUploadOffset(String tusResumable, String uploadId,) async {
    final response = await getUploadOffsetWithHttpInfo(tusResumable, uploadId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }
}

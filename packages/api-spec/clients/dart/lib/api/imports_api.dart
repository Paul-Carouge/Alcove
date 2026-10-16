//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;


class ImportsApi {
  ImportsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Cancel an unfinished import.
  ///
  /// Photos already imported stay. Uploaded archives are kept (listed by `listImportUploads`, deleted after a day without use); files in the server's import folder are never deleted. Administrators can cancel any job. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] importId (required):
  Future<Response> cancelImportWithHttpInfo(String importId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/imports/{importId}/cancel'
      .replaceAll('{importId}', importId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

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

  /// Cancel an unfinished import.
  ///
  /// Photos already imported stay. Uploaded archives are kept (listed by `listImportUploads`, deleted after a day without use); files in the server's import folder are never deleted. Administrators can cancel any job. 
  ///
  /// Parameters:
  ///
  /// * [String] importId (required):
  Future<void> cancelImport(String importId,) async {
    final response = await cancelImportWithHttpInfo(importId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Start importing a Google Photos library from Takeout archives.
  ///
  /// Give either `uploads` (ids of your finished `purpose=import` uploads) or `serverFiles` (names of `.zip` files or extracted folders in the server's import folder; administrators only). With `serverFiles`, `user` chooses the account receiving the photos (default: the caller). The job starts `queued`; a user can have one unfinished import at a time. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CreateImportRequest] createImportRequest (required):
  Future<Response> createImportWithHttpInfo(CreateImportRequest createImportRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/imports/google';

    // ignore: prefer_final_locals
    Object? postBody = createImportRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


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

  /// Start importing a Google Photos library from Takeout archives.
  ///
  /// Give either `uploads` (ids of your finished `purpose=import` uploads) or `serverFiles` (names of `.zip` files or extracted folders in the server's import folder; administrators only). With `serverFiles`, `user` chooses the account receiving the photos (default: the caller). The job starts `queued`; a user can have one unfinished import at a time. 
  ///
  /// Parameters:
  ///
  /// * [CreateImportRequest] createImportRequest (required):
  Future<ImportJob?> createImport(CreateImportRequest createImportRequest,) async {
    final response = await createImportWithHttpInfo(createImportRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ImportJob',) as ImportJob;
    
    }
    return null;
  }

  /// Delete one of your import archives to free the space.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] uploadId (required):
  Future<Response> deleteImportUploadWithHttpInfo(String uploadId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/imports/google/uploads/{uploadId}'
      .replaceAll('{uploadId}', uploadId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

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

  /// Delete one of your import archives to free the space.
  ///
  /// Parameters:
  ///
  /// * [String] uploadId (required):
  Future<void> deleteImportUpload(String uploadId,) async {
    final response = await deleteImportUploadWithHttpInfo(uploadId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// The Takeout archives and folders an administrator dropped in the server's import folder.
  ///
  /// Only `.zip` files and folders at the top level; hidden entries and symbolic links are ignored.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> listImportServerFilesWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/imports/google/server-files';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// The Takeout archives and folders an administrator dropped in the server's import folder.
  ///
  /// Only `.zip` files and folders at the top level; hidden entries and symbolic links are ignored.
  Future<ListImportServerFiles200Response?> listImportServerFiles() async {
    final response = await listImportServerFilesWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListImportServerFiles200Response',) as ListImportServerFiles200Response;
    
    }
    return null;
  }

  /// Your finished import archives that no unfinished job uses.
  ///
  /// Archives stay after a failed or cancelled import so a new job can use them; they are deleted after a successful import, or once nothing was uploaded for a day. 
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> listImportUploadsWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/imports/google/uploads';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Your finished import archives that no unfinished job uses.
  ///
  /// Archives stay after a failed or cancelled import so a new job can use them; they are deleted after a successful import, or once nothing was uploaded for a day. 
  Future<ListImportUploads200Response?> listImportUploads() async {
    final response = await listImportUploadsWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListImportUploads200Response',) as ListImportUploads200Response;
    
    }
    return null;
  }
}

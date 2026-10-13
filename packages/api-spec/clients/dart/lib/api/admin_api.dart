//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;


class AdminApi {
  AdminApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Install the latest release and restart (native installs only).
  ///
  /// Downloads the release, verifies its signature and checksum, backs up the database, swaps the binary and exits so the service manager restarts the new version. Answers 202 once the new binary is in place; clients then poll `/health` until `version` changes. 
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> applyUpdateWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/updates/apply';

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

  /// Install the latest release and restart (native installs only).
  ///
  /// Downloads the release, verifies its signature and checksum, backs up the database, swaps the binary and exits so the service manager restarts the new version. Answers 202 once the new binary is in place; clients then poll `/health` until `version` changes. 
  Future<ApplyUpdate202Response?> applyUpdate() async {
    final response = await applyUpdateWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApplyUpdate202Response',) as ApplyUpdate202Response;
    
    }
    return null;
  }

  /// Check for a new release now.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> checkUpdatesWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/updates/check';

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

  /// Check for a new release now.
  Future<SystemInfo?> checkUpdates() async {
    final response = await checkUpdatesWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SystemInfo',) as SystemInfo;
    
    }
    return null;
  }

  /// Create an account (verified, ready to sign in).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CreateUserRequest] createUserRequest (required):
  Future<Response> createUserWithHttpInfo(CreateUserRequest createUserRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/users';

    // ignore: prefer_final_locals
    Object? postBody = createUserRequest;

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

  /// Create an account (verified, ready to sign in).
  ///
  /// Parameters:
  ///
  /// * [CreateUserRequest] createUserRequest (required):
  Future<AdminUser?> createUser(CreateUserRequest createUserRequest,) async {
    final response = await createUserWithHttpInfo(createUserRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminUser',) as AdminUser;
    
    }
    return null;
  }

  /// Delete an account and everything it owns (files, photos, albums, links).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<Response> deleteUserWithHttpInfo(String userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/users/{userId}'
      .replaceAll('{userId}', userId);

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

  /// Delete an account and everything it owns (files, photos, albums, links).
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<void> deleteUser(String userId,) async {
    final response = await deleteUserWithHttpInfo(userId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// OCR status, installed tools and document counts.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getOCRWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/ocr';

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

  /// OCR status, installed tools and document counts.
  Future<OCRStatus?> getOCR() async {
    final response = await getOCRWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'OCRStatus',) as OCRStatus;
    
    }
    return null;
  }

  /// Version, installation and update status.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getSystemWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/system';

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

  /// Version, installation and update status.
  Future<SystemInfo?> getSystem() async {
    final response = await getSystemWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SystemInfo',) as SystemInfo;
    
    }
    return null;
  }

  /// Install the OCR tools of this server's release (native Linux installs).
  ///
  /// Downloads `ocr_linux_<arch>.tar.gz`, verifies it against the signed checksums like an update and activates it without a restart. Only when `canInstall` is true. 
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> installOCRWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/ocr/install';

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

  /// Install the OCR tools of this server's release (native Linux installs).
  ///
  /// Downloads `ocr_linux_<arch>.tar.gz`, verifies it against the signed checksums like an update and activates it without a restart. Only when `canInstall` is true. 
  Future<OCRStatus?> installOCR() async {
    final response = await installOCRWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'OCRStatus',) as OCRStatus;
    
    }
    return null;
  }

  /// Every account of this server, with its storage use.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> listUsersWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/users';

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

  /// Every account of this server, with its storage use.
  Future<ListUsers200Response?> listUsers() async {
    final response = await listUsersWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListUsers200Response',) as ListUsers200Response;
    
    }
    return null;
  }

  /// Enable or disable OpenStreetMap tiles for every user's map.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [SetMapTilesRequest] setMapTilesRequest (required):
  Future<Response> setMapTilesWithHttpInfo(SetMapTilesRequest setMapTilesRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/map';

    // ignore: prefer_final_locals
    Object? postBody = setMapTilesRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Enable or disable OpenStreetMap tiles for every user's map.
  ///
  /// Parameters:
  ///
  /// * [SetMapTilesRequest] setMapTilesRequest (required):
  Future<MapConfig?> setMapTiles(SetMapTilesRequest setMapTilesRequest,) async {
    final response = await setMapTilesWithHttpInfo(setMapTilesRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'MapConfig',) as MapConfig;
    
    }
    return null;
  }

  /// Turn OCR of scans and images on or off (on by default when the tools are installed).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [SetOCRRequest] setOCRRequest (required):
  Future<Response> setOCRWithHttpInfo(SetOCRRequest setOCRRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/ocr';

    // ignore: prefer_final_locals
    Object? postBody = setOCRRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Turn OCR of scans and images on or off (on by default when the tools are installed).
  ///
  /// Parameters:
  ///
  /// * [SetOCRRequest] setOCRRequest (required):
  Future<OCRStatus?> setOCR(SetOCRRequest setOCRRequest,) async {
    final response = await setOCRWithHttpInfo(setOCRRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'OCRStatus',) as OCRStatus;
    
    }
    return null;
  }

  /// Change an account's name, quota, role or password.
  ///
  /// Setting `password` signs the account out everywhere. Administrators cannot remove their own admin role, and the last administrator cannot be demoted. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [UpdateUserRequest] updateUserRequest (required):
  Future<Response> updateUserWithHttpInfo(String userId, UpdateUserRequest updateUserRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/users/{userId}'
      .replaceAll('{userId}', userId);

    // ignore: prefer_final_locals
    Object? postBody = updateUserRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


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

  /// Change an account's name, quota, role or password.
  ///
  /// Setting `password` signs the account out everywhere. Administrators cannot remove their own admin role, and the last administrator cannot be demoted. 
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [UpdateUserRequest] updateUserRequest (required):
  Future<AdminUser?> updateUser(String userId, UpdateUserRequest updateUserRequest,) async {
    final response = await updateUserWithHttpInfo(userId, updateUserRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminUser',) as AdminUser;
    
    }
    return null;
  }
}

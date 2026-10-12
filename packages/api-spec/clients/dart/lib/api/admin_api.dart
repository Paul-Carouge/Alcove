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
}

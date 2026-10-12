//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;


class SystemApi {
  SystemApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Download the Android app for this server's version.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///   A file token (from `POST /api/files/token`), so the URL works in a plain link.
  Future<Response> downloadAndroidAppWithHttpInfo(String token,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/app/android.apk';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'token', token));

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

  /// Download the Android app for this server's version.
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///   A file token (from `POST /api/files/token`), so the URL works in a plain link.
  Future<MultipartFile?> downloadAndroidApp(String token,) async {
    final response = await downloadAndroidAppWithHttpInfo(token,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'MultipartFile',) as MultipartFile;
    
    }
    return null;
  }

  /// The Android app matching this server's version (in-app updates, ADR 0024).
  ///
  /// The mobile app compares `version` with its own and offers to update when the server is newer and `available` is true. The APK comes from the GitHub release of the server's version, cached by the server; Android itself refuses an update signed with another key. 
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getAndroidAppWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/app/android';

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

  /// The Android app matching this server's version (in-app updates, ADR 0024).
  ///
  /// The mobile app compares `version` with its own and offers to update when the server is newer and `available` is true. The APK comes from the GitHub release of the server's version, cached by the server; Android itself refuses an update signed with another key. 
  Future<GetAndroidApp200Response?> getAndroidApp() async {
    final response = await getAndroidAppWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GetAndroidApp200Response',) as GetAndroidApp200Response;
    
    }
    return null;
  }

  /// Server health, version and compatibility information.
  ///
  /// Unauthenticated. Clients call it when the user enters a server URL and on every app start, then refuse to continue if their own supported API version is outside `[api.min, api.max]`. 
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getHealthWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/health';

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

  /// Server health, version and compatibility information.
  ///
  /// Unauthenticated. Clients call it when the user enters a server URL and on every app start, then refuse to continue if their own supported API version is outside `[api.min, api.max]`. 
  Future<Health?> getHealth() async {
    final response = await getHealthWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Health',) as Health;
    
    }
    return null;
  }
}

//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;


class PublicApi {
  PublicApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Download (or display) a file that is the shared item or inside the shared folder.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///   The link token (43 URL-safe characters).
  ///
  /// * [String] nodeId (required):
  ///
  /// * [String] access:
  ///   Access token from `unlock` (password-protected links only).
  ///
  /// * [String] inline:
  ///   Same passive-type rules as `/api/v1/nodes/{nodeId}/download`.
  ///
  /// * [String] thumb:
  ///   The generated JPEG thumbnail of a photo or video instead of the file (404 if none).
  Future<Response> downloadSharedFileWithHttpInfo(String token, String nodeId, { String? access, String? inline, String? thumb, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/public/shares/{token}/files/{nodeId}'
      .replaceAll('{token}', token)
      .replaceAll('{nodeId}', nodeId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (access != null) {
      queryParams.addAll(_queryParams('', 'access', access));
    }
    if (inline != null) {
      queryParams.addAll(_queryParams('', 'inline', inline));
    }
    if (thumb != null) {
      queryParams.addAll(_queryParams('', 'thumb', thumb));
    }

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

  /// Download (or display) a file that is the shared item or inside the shared folder.
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///   The link token (43 URL-safe characters).
  ///
  /// * [String] nodeId (required):
  ///
  /// * [String] access:
  ///   Access token from `unlock` (password-protected links only).
  ///
  /// * [String] inline:
  ///   Same passive-type rules as `/api/v1/nodes/{nodeId}/download`.
  ///
  /// * [String] thumb:
  ///   The generated JPEG thumbnail of a photo or video instead of the file (404 if none).
  Future<MultipartFile?> downloadSharedFile(String token, String nodeId, { String? access, String? inline, String? thumb, }) async {
    final response = await downloadSharedFileWithHttpInfo(token, nodeId,  access: access, inline: inline, thumb: thumb, );
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

  /// Describe a shared item (and list a shared folder's or album's content).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///   The link token (43 URL-safe characters).
  ///
  /// * [String] folder:
  ///   Folder inside a shared folder to list (default: the shared folder itself).
  ///
  /// * [String] access:
  ///   Access token from `unlock` (password-protected links only).
  Future<Response> getPublicShareWithHttpInfo(String token, { String? folder, String? access, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/public/shares/{token}'
      .replaceAll('{token}', token);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (folder != null) {
      queryParams.addAll(_queryParams('', 'folder', folder));
    }
    if (access != null) {
      queryParams.addAll(_queryParams('', 'access', access));
    }

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

  /// Describe a shared item (and list a shared folder's or album's content).
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///   The link token (43 URL-safe characters).
  ///
  /// * [String] folder:
  ///   Folder inside a shared folder to list (default: the shared folder itself).
  ///
  /// * [String] access:
  ///   Access token from `unlock` (password-protected links only).
  Future<PublicShare?> getPublicShare(String token, { String? folder, String? access, }) async {
    final response = await getPublicShareWithHttpInfo(token,  folder: folder, access: access, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PublicShare',) as PublicShare;
    
    }
    return null;
  }

  /// An image or video of a shared album.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///   The link token (43 URL-safe characters).
  ///
  /// * [String] mediaId (required):
  ///
  /// * [String] variant (required):
  ///   `thumb` (360 px high) and `preview` (1600 px) are generated JPEGs without metadata. `video` streams the original video (Range requests supported). Original photos are never served. 
  ///
  /// * [String] access:
  ///   Access token from `unlock` (password-protected links only).
  Future<Response> getSharedMediaWithHttpInfo(String token, String mediaId, String variant, { String? access, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/public/shares/{token}/media/{mediaId}/{variant}'
      .replaceAll('{token}', token)
      .replaceAll('{mediaId}', mediaId)
      .replaceAll('{variant}', variant);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (access != null) {
      queryParams.addAll(_queryParams('', 'access', access));
    }

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

  /// An image or video of a shared album.
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///   The link token (43 URL-safe characters).
  ///
  /// * [String] mediaId (required):
  ///
  /// * [String] variant (required):
  ///   `thumb` (360 px high) and `preview` (1600 px) are generated JPEGs without metadata. `video` streams the original video (Range requests supported). Original photos are never served. 
  ///
  /// * [String] access:
  ///   Access token from `unlock` (password-protected links only).
  Future<MultipartFile?> getSharedMedia(String token, String mediaId, String variant, { String? access, }) async {
    final response = await getSharedMediaWithHttpInfo(token, mediaId, variant,  access: access, );
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

  /// Exchange the link password for a 1-hour access token.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///   The link token (43 URL-safe characters).
  ///
  /// * [UnlockShareRequest] unlockShareRequest (required):
  Future<Response> unlockShareWithHttpInfo(String token, UnlockShareRequest unlockShareRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/public/shares/{token}/unlock'
      .replaceAll('{token}', token);

    // ignore: prefer_final_locals
    Object? postBody = unlockShareRequest;

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

  /// Exchange the link password for a 1-hour access token.
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///   The link token (43 URL-safe characters).
  ///
  /// * [UnlockShareRequest] unlockShareRequest (required):
  Future<UnlockShare200Response?> unlockShare(String token, UnlockShareRequest unlockShareRequest,) async {
    final response = await unlockShareWithHttpInfo(token, unlockShareRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'UnlockShare200Response',) as UnlockShare200Response;
    
    }
    return null;
  }
}

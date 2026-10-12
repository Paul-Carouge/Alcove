//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;


class DriveApi {
  DriveApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Download a file under its drive name.
  ///
  /// Authenticated with a short-lived **file token** in the query string (from PocketBase `POST /api/files/token`), so the URL can be used in a plain link (or `<img>`/`<video>`). Served as an attachment unless `inline=1` for a passive type; supports Range requests. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] nodeId (required):
  ///
  /// * [String] token (required):
  ///   File token of the node's owner (expires after a few minutes).
  ///
  /// * [String] inline:
  ///   `1` to display instead of download. Only honored for passive types (JPEG, PNG, GIF, WebP, AVIF, PDF, plain text, MP4/WebM video, common audio); everything else, notably HTML and SVG, is always an attachment. Inline responses carry a restrictive CSP. 
  Future<Response> downloadNodeWithHttpInfo(String nodeId, String token, { String? inline, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/nodes/{nodeId}/download'
      .replaceAll('{nodeId}', nodeId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'token', token));
    if (inline != null) {
      queryParams.addAll(_queryParams('', 'inline', inline));
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

  /// Download a file under its drive name.
  ///
  /// Authenticated with a short-lived **file token** in the query string (from PocketBase `POST /api/files/token`), so the URL can be used in a plain link (or `<img>`/`<video>`). Served as an attachment unless `inline=1` for a passive type; supports Range requests. 
  ///
  /// Parameters:
  ///
  /// * [String] nodeId (required):
  ///
  /// * [String] token (required):
  ///   File token of the node's owner (expires after a few minutes).
  ///
  /// * [String] inline:
  ///   `1` to display instead of download. Only honored for passive types (JPEG, PNG, GIF, WebP, AVIF, PDF, plain text, MP4/WebM video, common audio); everything else, notably HTML and SVG, is always an attachment. Inline responses carry a restrictive CSP. 
  Future<MultipartFile?> downloadNode(String nodeId, String token, { String? inline, }) async {
    final response = await downloadNodeWithHttpInfo(nodeId, token,  inline: inline, );
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

  /// Storage used by the signed-in user, and their quota.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getMyUsageWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/me/usage';

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

  /// Storage used by the signed-in user, and their quota.
  Future<Usage?> getMyUsage() async {
    final response = await getMyUsageWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Usage',) as Usage;
    
    }
    return null;
  }

  /// Which of these file fingerprints you already have (phone backup deduplication).
  ///
  /// The mobile app sends the SHA-256 of photos it is about to back up and skips those you already have anywhere in your drive, trash included (a deleted photo is not brought back). 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [KnownHashesRequest] knownHashesRequest (required):
  Future<Response> knownHashesWithHttpInfo(KnownHashesRequest knownHashesRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/backup/known';

    // ignore: prefer_final_locals
    Object? postBody = knownHashesRequest;

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

  /// Which of these file fingerprints you already have (phone backup deduplication).
  ///
  /// The mobile app sends the SHA-256 of photos it is about to back up and skips those you already have anywhere in your drive, trash included (a deleted photo is not brought back). 
  ///
  /// Parameters:
  ///
  /// * [KnownHashesRequest] knownHashesRequest (required):
  Future<KnownHashes200Response?> knownHashes(KnownHashesRequest knownHashesRequest,) async {
    final response = await knownHashesWithHttpInfo(knownHashesRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'KnownHashes200Response',) as KnownHashes200Response;
    
    }
    return null;
  }
}

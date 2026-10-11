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
  /// Authenticated with a short-lived **file token** in the query string (from PocketBase `POST /api/files/token`), so the URL can be used in a plain link. Always served as an attachment; supports Range requests. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] nodeId (required):
  ///
  /// * [String] token (required):
  ///   File token of the node's owner (expires after a few minutes).
  Future<Response> downloadNodeWithHttpInfo(String nodeId, String token,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/nodes/{nodeId}/download'
      .replaceAll('{nodeId}', nodeId);

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

  /// Download a file under its drive name.
  ///
  /// Authenticated with a short-lived **file token** in the query string (from PocketBase `POST /api/files/token`), so the URL can be used in a plain link. Always served as an attachment; supports Range requests. 
  ///
  /// Parameters:
  ///
  /// * [String] nodeId (required):
  ///
  /// * [String] token (required):
  ///   File token of the node's owner (expires after a few minutes).
  Future<MultipartFile?> downloadNode(String nodeId, String token,) async {
    final response = await downloadNodeWithHttpInfo(nodeId, token,);
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
}

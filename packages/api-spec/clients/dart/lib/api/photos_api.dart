//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;


class PhotosApi {
  PhotosApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Mark or unmark a photo or video as favorite.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] mediaId (required):
  ///
  /// * [SetFavoriteRequest] setFavoriteRequest (required):
  Future<Response> setFavoriteWithHttpInfo(String mediaId, SetFavoriteRequest setFavoriteRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/media/{mediaId}/favorite'
      .replaceAll('{mediaId}', mediaId);

    // ignore: prefer_final_locals
    Object? postBody = setFavoriteRequest;

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

  /// Mark or unmark a photo or video as favorite.
  ///
  /// Parameters:
  ///
  /// * [String] mediaId (required):
  ///
  /// * [SetFavoriteRequest] setFavoriteRequest (required):
  Future<void> setFavorite(String mediaId, SetFavoriteRequest setFavoriteRequest,) async {
    final response = await setFavoriteWithHttpInfo(mediaId, setFavoriteRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }
}

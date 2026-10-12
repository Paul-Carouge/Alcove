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

  /// Mark a group as \"not duplicates\"; it is hidden until another similar photo joins it.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DismissDuplicatesRequest] dismissDuplicatesRequest (required):
  Future<Response> dismissDuplicatesWithHttpInfo(DismissDuplicatesRequest dismissDuplicatesRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/photos/duplicates/dismiss';

    // ignore: prefer_final_locals
    Object? postBody = dismissDuplicatesRequest;

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

  /// Mark a group as \"not duplicates\"; it is hidden until another similar photo joins it.
  ///
  /// Parameters:
  ///
  /// * [DismissDuplicatesRequest] dismissDuplicatesRequest (required):
  Future<void> dismissDuplicates(DismissDuplicatesRequest dismissDuplicatesRequest,) async {
    final response = await dismissDuplicatesWithHttpInfo(dismissDuplicatesRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// The owner and participants of an album.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] albumId (required):
  Future<Response> getAlbumPeopleWithHttpInfo(String albumId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/albums/{albumId}/people'
      .replaceAll('{albumId}', albumId);

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

  /// The owner and participants of an album.
  ///
  /// Parameters:
  ///
  /// * [String] albumId (required):
  Future<GetAlbumPeople200Response?> getAlbumPeople(String albumId,) async {
    final response = await getAlbumPeopleWithHttpInfo(albumId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GetAlbumPeople200Response',) as GetAlbumPeople200Response;
    
    }
    return null;
  }

  /// The original file of a photo or video, for its owner and the people of albums it is in.
  ///
  /// Authenticated with a short-lived **file token** in the query string, like `/api/v1/nodes/{nodeId}/download`. Access follows the `media` view rule (ADR 0018), so album participants can play or download a shared item without access to the owner's drive. Attachment unless `inline=1` for a passive type; supports Range requests. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] mediaId (required):
  ///
  /// * [String] token (required):
  ///
  /// * [String] inline:
  Future<Response> getMediaOriginalWithHttpInfo(String mediaId, String token, { String? inline, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/media/{mediaId}/original'
      .replaceAll('{mediaId}', mediaId);

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

  /// The original file of a photo or video, for its owner and the people of albums it is in.
  ///
  /// Authenticated with a short-lived **file token** in the query string, like `/api/v1/nodes/{nodeId}/download`. Access follows the `media` view rule (ADR 0018), so album participants can play or download a shared item without access to the owner's drive. Attachment unless `inline=1` for a passive type; supports Range requests. 
  ///
  /// Parameters:
  ///
  /// * [String] mediaId (required):
  ///
  /// * [String] token (required):
  ///
  /// * [String] inline:
  Future<MultipartFile?> getMediaOriginal(String mediaId, String token, { String? inline, }) async {
    final response = await getMediaOriginalWithHttpInfo(mediaId, token,  inline: inline, );
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

  /// Stop taking part in an album shared with you (your photos are removed from it).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] albumId (required):
  Future<Response> leaveAlbumWithHttpInfo(String albumId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/albums/{albumId}/leave'
      .replaceAll('{albumId}', albumId);

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

  /// Stop taking part in an album shared with you (your photos are removed from it).
  ///
  /// Parameters:
  ///
  /// * [String] albumId (required):
  Future<void> leaveAlbum(String albumId,) async {
    final response = await leaveAlbumWithHttpInfo(albumId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Photos and videos of an album, newest first (items in the trash are left out).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] albumId (required):
  ///
  /// * [int] page:
  ///
  /// * [int] perPage:
  Future<Response> listAlbumItemsWithHttpInfo(String albumId, { int? page, int? perPage, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/albums/{albumId}/items'
      .replaceAll('{albumId}', albumId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (page != null) {
      queryParams.addAll(_queryParams('', 'page', page));
    }
    if (perPage != null) {
      queryParams.addAll(_queryParams('', 'perPage', perPage));
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

  /// Photos and videos of an album, newest first (items in the trash are left out).
  ///
  /// Parameters:
  ///
  /// * [String] albumId (required):
  ///
  /// * [int] page:
  ///
  /// * [int] perPage:
  Future<ListAlbumItems200Response?> listAlbumItems(String albumId, { int? page, int? perPage, }) async {
    final response = await listAlbumItemsWithHttpInfo(albumId,  page: page, perPage: perPage, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListAlbumItems200Response',) as ListAlbumItems200Response;
    
    }
    return null;
  }

  /// Albums the caller owns or takes part in, most recently updated first.
  ///
  /// Albums are created, renamed, shared and deleted through the `albums` collection (`/api/collections/albums/records`); items are added and removed through `album_items`. This read adds what collection rules cannot: item counts, covers and the owner's name. 
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> listAlbumsWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/albums';

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

  /// Albums the caller owns or takes part in, most recently updated first.
  ///
  /// Albums are created, renamed, shared and deleted through the `albums` collection (`/api/collections/albums/records`); items are added and removed through `album_items`. This read adds what collection rules cannot: item counts, covers and the owner's name. 
  Future<ListAlbums200Response?> listAlbums() async {
    final response = await listAlbumsWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListAlbums200Response',) as ListAlbums200Response;
    
    }
    return null;
  }

  /// Groups of identical files and visually similar photos among your own items.
  ///
  /// Identical = same SHA-256. Similar = images whose perceptual hashes (dHash) differ by at most a few bits (resized or recompressed copies, bursts). Items in the trash and groups you dismissed are left out. Nothing is deleted by the server: clients move the unwanted files to the trash. 
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> listDuplicatesWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/photos/duplicates';

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

  /// Groups of identical files and visually similar photos among your own items.
  ///
  /// Identical = same SHA-256. Similar = images whose perceptual hashes (dHash) differ by at most a few bits (resized or recompressed copies, bursts). Items in the trash and groups you dismissed are left out. Nothing is deleted by the server: clients move the unwanted files to the trash. 
  Future<ListDuplicates200Response?> listDuplicates() async {
    final response = await listDuplicatesWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListDuplicates200Response',) as ListDuplicates200Response;
    
    }
    return null;
  }

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

//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;


class DocumentsApi {
  DocumentsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Progress of the searchable copy of a scan.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] nodeId (required):
  Future<Response> getSearchablePDFWithHttpInfo(String nodeId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/documents/{nodeId}/searchable'
      .replaceAll('{nodeId}', nodeId);

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

  /// Progress of the searchable copy of a scan.
  ///
  /// Parameters:
  ///
  /// * [String] nodeId (required):
  Future<SearchableJob?> getSearchablePDF(String nodeId,) async {
    final response = await getSearchablePDFWithHttpInfo(nodeId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SearchableJob',) as SearchableJob;
    
    }
    return null;
  }

  /// Make a copy of a scan whose text can be selected and searched.
  ///
  /// Runs in the background: each page is recognised and saved as a PDF with an invisible text layer over the picture, next to the original as `<name> (OCR).pdf` (first 100 pages). Poll the GET operation; the new file also arrives through the `nodes` realtime subscription. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] nodeId (required):
  Future<Response> makeSearchablePDFWithHttpInfo(String nodeId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/documents/{nodeId}/searchable'
      .replaceAll('{nodeId}', nodeId);

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

  /// Make a copy of a scan whose text can be selected and searched.
  ///
  /// Runs in the background: each page is recognised and saved as a PDF with an invisible text layer over the picture, next to the original as `<name> (OCR).pdf` (first 100 pages). Poll the GET operation; the new file also arrives through the `nodes` realtime subscription. 
  ///
  /// Parameters:
  ///
  /// * [String] nodeId (required):
  Future<SearchableJob?> makeSearchablePDF(String nodeId,) async {
    final response = await makeSearchablePDFWithHttpInfo(nodeId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SearchableJob',) as SearchableJob;
    
    }
    return null;
  }

  /// Find your files and folders by name, then documents by their text.
  ///
  /// Name matches (substring, folders first) come first, then files carrying a tag whose name starts with the query, then documents whose text contains every word as a prefix, accents and case ignored, best matches first. Trashed items are left out. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] q (required):
  Future<Response> searchWithHttpInfo(String q,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/search';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'q', q));

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

  /// Find your files and folders by name, then documents by their text.
  ///
  /// Name matches (substring, folders first) come first, then files carrying a tag whose name starts with the query, then documents whose text contains every word as a prefix, accents and case ignored, best matches first. Trashed items are left out. 
  ///
  /// Parameters:
  ///
  /// * [String] q (required):
  Future<Search200Response?> search(String q,) async {
    final response = await searchWithHttpInfo(q,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Search200Response',) as Search200Response;
    
    }
    return null;
  }
}

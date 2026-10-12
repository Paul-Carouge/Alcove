//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;


class SetupApi {
  SetupApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Create the administrator (admin UI + app account) and save optional settings.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CompleteSetupRequest] completeSetupRequest (required):
  Future<Response> completeSetupWithHttpInfo(CompleteSetupRequest completeSetupRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/setup';

    // ignore: prefer_final_locals
    Object? postBody = completeSetupRequest;

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

  /// Create the administrator (admin UI + app account) and save optional settings.
  ///
  /// Parameters:
  ///
  /// * [CompleteSetupRequest] completeSetupRequest (required):
  Future<void> completeSetup(CompleteSetupRequest completeSetupRequest,) async {
    final response = await completeSetupWithHttpInfo(completeSetupRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Check the setup token and the storage before creating the administrator.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [SetupToken] setupToken (required):
  Future<Response> getSetupStatusWithHttpInfo(SetupToken setupToken,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/setup/status';

    // ignore: prefer_final_locals
    Object? postBody = setupToken;

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

  /// Check the setup token and the storage before creating the administrator.
  ///
  /// Parameters:
  ///
  /// * [SetupToken] setupToken (required):
  Future<SetupStatus?> getSetupStatus(SetupToken setupToken,) async {
    final response = await getSetupStatusWithHttpInfo(setupToken,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SetupStatus',) as SetupStatus;
    
    }
    return null;
  }

  /// Send a test email with SMTP settings (not saved).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [TestSetupSmtpRequest] testSetupSmtpRequest (required):
  Future<Response> testSetupSmtpWithHttpInfo(TestSetupSmtpRequest testSetupSmtpRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/setup/smtp-test';

    // ignore: prefer_final_locals
    Object? postBody = testSetupSmtpRequest;

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

  /// Send a test email with SMTP settings (not saved).
  ///
  /// Parameters:
  ///
  /// * [TestSetupSmtpRequest] testSetupSmtpRequest (required):
  Future<void> testSetupSmtp(TestSetupSmtpRequest testSetupSmtpRequest,) async {
    final response = await testSetupSmtpWithHttpInfo(testSetupSmtpRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }
}

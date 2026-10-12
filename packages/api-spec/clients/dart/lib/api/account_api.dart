//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of alcove_api;


class AccountApi {
  AccountApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Turn two-factor off (password and a code required).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [TotpConfirm] totpConfirm (required):
  Future<Response> disableTotpWithHttpInfo(TotpConfirm totpConfirm,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/me/totp/disable';

    // ignore: prefer_final_locals
    Object? postBody = totpConfirm;

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

  /// Turn two-factor off (password and a code required).
  ///
  /// Parameters:
  ///
  /// * [TotpConfirm] totpConfirm (required):
  Future<void> disableTotp(TotpConfirm totpConfirm,) async {
    final response = await disableTotpWithHttpInfo(totpConfirm,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Confirm enrolment with a first code; returns recovery codes once.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [EnableTotpRequest] enableTotpRequest (required):
  Future<Response> enableTotpWithHttpInfo(EnableTotpRequest enableTotpRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/me/totp/enable';

    // ignore: prefer_final_locals
    Object? postBody = enableTotpRequest;

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

  /// Confirm enrolment with a first code; returns recovery codes once.
  ///
  /// Parameters:
  ///
  /// * [EnableTotpRequest] enableTotpRequest (required):
  Future<RecoveryCodes?> enableTotp(EnableTotpRequest enableTotpRequest,) async {
    final response = await enableTotpWithHttpInfo(enableTotpRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'RecoveryCodes',) as RecoveryCodes;
    
    }
    return null;
  }

  /// Two-factor status of the signed-in user.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getTotpStatusWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/me/totp';

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

  /// Two-factor status of the signed-in user.
  Future<TotpStatus?> getTotpStatus() async {
    final response = await getTotpStatusWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TotpStatus',) as TotpStatus;
    
    }
    return null;
  }

  /// Replace all recovery codes (password and a code required).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [TotpConfirm] totpConfirm (required):
  Future<Response> regenerateRecoveryCodesWithHttpInfo(TotpConfirm totpConfirm,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/me/totp/recovery-codes';

    // ignore: prefer_final_locals
    Object? postBody = totpConfirm;

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

  /// Replace all recovery codes (password and a code required).
  ///
  /// Parameters:
  ///
  /// * [TotpConfirm] totpConfirm (required):
  Future<RecoveryCodes?> regenerateRecoveryCodes(TotpConfirm totpConfirm,) async {
    final response = await regenerateRecoveryCodesWithHttpInfo(totpConfirm,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'RecoveryCodes',) as RecoveryCodes;
    
    }
    return null;
  }

  /// Start enrolment (new secret, not active until confirmed).
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> setupTotpWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/me/totp/setup';

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

  /// Start enrolment (new secret, not active until confirmed).
  Future<TotpSetup?> setupTotp() async {
    final response = await setupTotpWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TotpSetup',) as TotpSetup;
    
    }
    return null;
  }
}

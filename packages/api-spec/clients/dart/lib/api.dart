//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

library alcove_api;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

part 'api_client.dart';
part 'api_helper.dart';
part 'api_exception.dart';
part 'auth/authentication.dart';
part 'auth/api_key_auth.dart';
part 'auth/oauth.dart';
part 'auth/http_basic_auth.dart';
part 'auth/http_bearer_auth.dart';

part 'api/account_api.dart';
part 'api/admin_api.dart';
part 'api/drive_api.dart';
part 'api/photos_api.dart';
part 'api/public_api.dart';
part 'api/setup_api.dart';
part 'api/shares_api.dart';
part 'api/system_api.dart';
part 'api/uploads_api.dart';

part 'model/admin_user.dart';
part 'model/album_item.dart';
part 'model/album_summary.dart';
part 'model/album_summary_owner.dart';
part 'model/api_range.dart';
part 'model/apply_update202_response.dart';
part 'model/complete_setup_request.dart';
part 'model/complete_setup_request_all_of_admin.dart';
part 'model/create_share.dart';
part 'model/create_user_request.dart';
part 'model/created_share.dart';
part 'model/dismiss_duplicates_request.dart';
part 'model/duplicate_group.dart';
part 'model/duplicate_item.dart';
part 'model/enable_totp_request.dart';
part 'model/error.dart';
part 'model/get_album_people200_response.dart';
part 'model/get_album_people200_response_people_inner.dart';
part 'model/get_android_app200_response.dart';
part 'model/get_photo_facets200_response.dart';
part 'model/get_photo_facets200_response_cameras_inner.dart';
part 'model/get_photo_facets200_response_years_inner.dart';
part 'model/health.dart';
part 'model/known_hashes200_response.dart';
part 'model/known_hashes_request.dart';
part 'model/list_album_items200_response.dart';
part 'model/list_albums200_response.dart';
part 'model/list_duplicates200_response.dart';
part 'model/list_photo_locations200_response.dart';
part 'model/list_photo_locations200_response_items_inner.dart';
part 'model/list_users200_response.dart';
part 'model/map_config.dart';
part 'model/map_config_tiles.dart';
part 'model/media_files.dart';
part 'model/module.dart';
part 'model/person.dart';
part 'model/public_media.dart';
part 'model/public_node.dart';
part 'model/public_share.dart';
part 'model/public_share_album.dart';
part 'model/recovery_codes.dart';
part 'model/set_favorite_request.dart';
part 'model/set_map_tiles_request.dart';
part 'model/setup_status.dart';
part 'model/setup_status_storage.dart';
part 'model/setup_token.dart';
part 'model/smtp_settings.dart';
part 'model/system_info.dart';
part 'model/system_info_update.dart';
part 'model/test_setup_smtp_request.dart';
part 'model/totp_confirm.dart';
part 'model/totp_setup.dart';
part 'model/totp_status.dart';
part 'model/unlock_share200_response.dart';
part 'model/unlock_share_request.dart';
part 'model/update_user_request.dart';
part 'model/usage.dart';


/// An [ApiClient] instance that uses the default values obtained from
/// the OpenAPI specification file.
var defaultApiClient = ApiClient();

const _delimiters = {'csv': ',', 'ssv': ' ', 'tsv': '\t', 'pipes': '|'};
const _dateEpochMarker = 'epoch';
const _deepEquality = DeepCollectionEquality();
final _dateFormatter = DateFormat('yyyy-MM-dd');
final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

bool _isEpochMarker(String? pattern) => pattern == _dateEpochMarker || pattern == '/$_dateEpochMarker/';

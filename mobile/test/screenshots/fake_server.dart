import 'dart:convert';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// A believable library for screenshots: three months of photos, videos and favorites.
List<Map<String, dynamic>> fakeMedia() {
  final out = <Map<String, dynamic>>[];
  const shapes = [(4032, 3024), (3024, 4032), (4000, 2250), (3000, 3000)];
  var n = 0;
  for (final (month, count) in [(10, 11), (9, 14), (7, 9)]) {
    for (var i = 0; i < count; i++) {
      final (w, h) = shapes[n % shapes.length];
      final video = n % 7 == 3;
      out.add({
        'id': 'm$n',
        'collectionId': 'media1',
        'collectionName': 'media',
        'node': 'n$n',
        'owner': 'u1',
        'kind': video ? 'video' : 'image',
        'status': 'ready',
        'taken_at':
            '2026-${month.toString().padLeft(2, '0')}-${(28 - i).toString().padLeft(2, '0')} 10:00:00.000Z',
        'width': w,
        'height': h,
        'duration': video ? 14.0 + n : 0,
        'favorite': n % 5 == 1,
        'thumb': 'thumb$n.jpg',
        'preview': 'preview$n.jpg',
        'camera_make': 'OPPO',
        'camera_model': 'Find X9 Pro',
        'lens': '',
        'exposure': '1/120 s · f/1.8 · ISO 100',
        'has_location': n % 3 == 0,
        'lat': 45.7640,
        'lon': 4.8357,
        'expand': {
          'node': {
            'id': 'n$n',
            'collectionId': 'nodes',
            'name': 'IMG_20261${month}0${i}_$n.heic',
            'size': 2400000 + n * 9000,
          },
        },
      });
      n++;
    }
  }
  return out;
}

http.Response fakeAlcove(http.Request req) {
  final path = req.url.path;
  if (path == '/api/files/token') return _json({'token': 'ft'});
  if (path == '/api/collections/users/auth-refresh') {
    return _json({'token': fakeToken, 'record': fakeUser});
  }
  if (path == '/api/collections/media/records') {
    final items = fakeMedia();
    return _json({
      'page': 1,
      'perPage': 120,
      'totalItems': items.length,
      'totalPages': 1,
      'items': items,
    });
  }
  if (path == '/api/v1/albums') {
    return _json({
      'items': [
        for (final (i, name, count, role, owner, shared) in [
          (0, 'Été en Provence', 42, 'owner', 'Paul Carouge', true),
          (1, 'Lyon', 18, 'owner', 'Paul Carouge', false),
          (2, 'Montagne', 25, 'viewer', 'Camille Martin', true),
          (3, 'Anniversaire de Léa', 64, 'contributor', 'Léa Martin', true),
        ])
          {
            'id': 'al$i',
            'name': name,
            'role': role,
            'owner': {'id': 'u$i', 'name': owner},
            'count': count,
            'shared': shared,
            'cover': {
              'id': 'm$i',
              'collectionId': 'media1',
              'thumb': 'thumb$i.jpg',
              'preview': 'p$i.jpg',
            },
            'updated': '2026-10-12 10:00:00.000Z',
          },
      ],
    });
  }
  if (path.startsWith('/api/v1/albums/') && path.endsWith('/items')) {
    final media = fakeMedia().sublist(0, 14);
    return _json({
      'items': [
        for (final m in media)
          {...m, 'addedBy': 'u1', 'name': 'IMG_${m['id']}.jpg', 'size': 2400000},
      ],
    });
  }
  if (path == '/api/collections/tags/records') {
    return _json({
      'page': 1,
      'perPage': 1000,
      'totalItems': 3,
      'totalPages': 1,
      'items': [
        for (final (id, name, color) in [
          ('t1', 'Factures', 'green'),
          ('t2', 'Logement', 'blue'),
          ('t3', 'Impôts', 'orange'),
        ])
          {'id': id, 'collectionId': 'tags', 'name': name, 'color': color, 'owner': 'u1'},
      ],
    });
  }
  if (path == '/api/v1/photos/memories') {
    final media = fakeMedia();
    return _json({
      'memories': [
        {'yearsAgo': 1, 'year': 2025, 'items': media.sublist(2, 9)},
        {'yearsAgo': 3, 'year': 2023, 'items': media.sublist(12, 16)},
        {'yearsAgo': 6, 'year': 2020, 'items': media.sublist(20, 22)},
      ],
    });
  }
  if (path == '/api/v1/search') {
    Map<String, dynamic> node(String id, String name, String kind, String mime) => {
      'id': id,
      'collectionId': 'nodes',
      'collectionName': 'nodes',
      'name': name,
      'kind': kind,
      'mime': mime,
      'size': 384000,
      'updated': '2026-10-03 10:00:00.000Z',
    };
    return _json({
      'items': [
        {'node': node('d9', 'Factures', 'folder', ''), 'match': 'name'},
        {
          'node': node('f1', 'Contrat de location.pdf', 'file', 'application/pdf'),
          'match': 'content',
          'snippet': [
            {'text': '…Le montant de la '},
            {'text': 'facture', 'hit': true},
            {'text': ' d’électricité est inclus dans les charges…'},
          ],
        },
        {
          'node': node('f7', 'Capture 2026-03-02.png', 'file', 'image/png'),
          'match': 'content',
          'snippet': [
            {'text': '…'},
            {'text': 'Facture', 'hit': true},
            {'text': ' numéro 2024-117 · Montant total : 84,20 euros…'},
          ],
        },
      ],
    });
  }
  if (path == '/api/collections/nodes/records') {
    return _json({
      'page': 1,
      'perPage': 1000,
      'totalItems': 6,
      'totalPages': 1,
      'items': [
        for (final (id, name, kind, mime, size) in [
          ('d1', 'Sauvegarde du téléphone', 'folder', '', 0),
          ('d2', 'Documents', 'folder', '', 0),
          ('d3', 'Vacances 2025', 'folder', '', 0),
          ('f1', 'Contrat de location.pdf', 'file', 'application/pdf', 384000),
          ('f2', 'Lyon.jpg', 'file', 'image/jpeg', 2480000),
          ('f3', 'Notes de réunion.txt', 'file', 'text/plain', 4200),
        ])
          {
            'id': id,
            'collectionId': 'nodes',
            'name': name,
            'kind': kind,
            'mime': mime,
            'size': size,
            'blob': kind == 'file' ? 'blob.bin' : '',
            'tags': id == 'f1' ? ['t1', 't2'] : <String>[],
            'updated': '2026-10-0${id.hashCode % 9 + 1} 10:00:00.000Z',
          },
      ],
    });
  }
  return http.Response('{"status":404}', 404);
}

final fakeToken =
    '${base64Url.encode(utf8.encode('{"alg":"HS256"}')).replaceAll('=', '')}.'
    '${base64Url.encode(utf8.encode('{"exp":4102444800,"id":"u1","type":"auth"}')).replaceAll('=', '')}.sig';
const fakeUser = {
  'id': 'u1',
  'collectionId': '_pb_users_auth_',
  'collectionName': 'users',
  'email': 'paul@example.com',
  'name': 'Paul Carouge',
};

Future<Session> fakeSession({bool signedIn = true}) async {
  FlutterSecureStorage.setMockInitialValues({});
  final client = MockClient((r) async => fakeAlcove(r));
  final s = Session(
    store: SecureStore(const FlutterSecureStorage()),
    httpClientFactory: () => client,
  );
  await s.useServer(Uri.parse('https://cloud.example.com'));
  if (signedIn) s.pb.authStore.save(fakeToken, RecordModel.fromJson(fakeUser));
  return s;
}

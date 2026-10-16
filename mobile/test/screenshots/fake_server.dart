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
  http.Response page(List<Map<String, dynamic>> items) => _json({
    'page': 1,
    'perPage': 500,
    'totalItems': items.length,
    'totalPages': 1,
    'items': items,
  });
  if (path == '/api/collections/notes/records') {
    return page([
      for (final (id, title, body, pinned, day) in [
        ('n1', 'Courses', '- pain\n- café\n- tomates', true, '14'),
        ('n2', 'Idées de week-end', 'Annecy, le lac et le marché du dimanche', false, '13'),
        ('n3', 'Réunion copropriété', 'Ravalement de façade : devis à comparer', false, '10'),
        ('n4', '', 'Appeler le plombier pour la facture du chauffe-eau', false, '02'),
      ])
        {
          'id': id,
          'collectionId': 'notes',
          'collectionName': 'notes',
          'owner': 'u1',
          'title': title,
          'body': body,
          'pinned': pinned,
          'tags': <String>[],
          'trashed_at': '',
          'updated': '2026-10-$day 09:30:00.000Z',
        },
    ]);
  }
  if (path == '/api/collections/calendars/records') {
    return page([
      {
        'id': 'c1',
        'collectionId': 'calendars',
        'name': 'Paul',
        'color': 'green',
        'is_default': true,
      },
    ]);
  }
  if (path == '/api/collections/events/records') {
    Map<String, dynamic> ev(
      String id,
      String title,
      String start,
      String end, {
      bool allDay = false,
      String location = '',
    }) => {
      'id': id,
      'collectionId': 'events',
      'collectionName': 'events',
      'calendar': 'c1',
      'title': title,
      'description': '',
      'location': location,
      'start': start,
      'end': end,
      'all_day': allDay,
      'rrule': '',
    };
    return page([
      ev(
        'e1',
        'Dentiste',
        '2026-10-15 08:30:00.000Z',
        '2026-10-15 09:00:00.000Z',
        location: '12 rue de la République',
      ),
      ev('e2', 'Déjeuner avec Camille', '2026-10-16 10:30:00.000Z', '2026-10-16 12:00:00.000Z'),
      ev('e3', 'Vacances', '2026-10-24 00:00:00.000Z', '2026-10-27 00:00:00.000Z', allDay: true),
      ev('e4', 'Yoga', '2026-10-20 16:00:00.000Z', '2026-10-20 17:00:00.000Z'),
    ]);
  }
  if (path == '/api/collections/documents/records') {
    Map<String, dynamic> doc(String id, String name, String kind, String mime, String text) => {
      'id': 'doc$id',
      'collectionId': 'documents',
      'node': id,
      'kind': kind,
      'status': 'ready',
      'text': text,
      'updated': '2026-10-12 10:00:00.000Z',
      'expand': {
        'node': {
          'id': id,
          'collectionId': 'nodes',
          'collectionName': 'nodes',
          'name': name,
          'kind': 'file',
          'mime': mime,
          'size': 384000,
          'updated': '2026-10-12 10:00:00.000Z',
        },
      },
    };
    return page([
      doc(
        'f1',
        'Contrat de location.pdf',
        'pdf',
        'application/pdf',
        'Le présent bail est consenti pour une durée de trois ans à compter du 1er septembre…',
      ),
      doc(
        'f7',
        'Capture 2026-03-02.png',
        'image',
        'image/png',
        'Facture numéro 2024-117 · Montant total : 84,20 euros',
      ),
      doc(
        'f3',
        'Notes de réunion.txt',
        'text',
        'text/plain',
        'Ordre du jour : budget 2027, travaux de la cage d’escalier, questions diverses.',
      ),
      doc(
        'f9',
        'Attestation d’assurance.pdf',
        'pdf',
        'application/pdf',
        'Nous certifions que M. Paul Carouge est assuré au titre du contrat habitation…',
      ),
    ]);
  }
  if (path == '/api/collections/nodes/records' &&
      (req.url.queryParameters['filter'] ?? '').contains('kind = "file"')) {
    // The "Recent" strip of Files.
    Map<String, dynamic> f(String id, String name, String mime, String day) => {
      'id': id,
      'collectionId': 'nodes',
      'collectionName': 'nodes',
      'name': name,
      'kind': 'file',
      'mime': mime,
      'size': 120000,
      'blob': 'blob.bin',
      'updated': '2026-10-$day 10:00:00.000Z',
    };
    return page([
      f('f1', 'Contrat de location.pdf', 'application/pdf', '14'),
      f('f3', 'Notes de réunion.txt', 'text/plain', '13'),
      f('f8', 'Budget 2027.csv', 'text/csv', '11'),
      f('f9', 'Attestation d’assurance.pdf', 'application/pdf', '09'),
    ]);
  }
  if (path == '/api/collections/nodes/records') {
    final foldersOnly = (req.url.queryParameters['filter'] ?? '').contains('kind = "folder"');
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
        ].where((n) => !foldersOnly || n.$3 == 'folder'))
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

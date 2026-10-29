import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medminder/services/api_client.dart';

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  test('lists medicines from the API', () async {
    final api = ApiClient('http://x', client: MockClient((req) async {
      expect(req.url.path, '/api/medicines');
      return _json([
        {'id': 1, 'name': 'A', 'dosage': '1 tablet', 'start_date': '2026-10-01', 'times': ['08:00']}
      ], 200);
    }));
    final meds = await api.listMedicines();
    expect(meds.single.name, 'A');
  });

  test('maps a 422 validation error with field messages', () async {
    final api = ApiClient('http://x', client: MockClient((_) async => _json({
          'error': {'code': 'validation_error', 'message': 'Validation failed', 'fields': {'name': 'Name is required.'}}
        }, 422)));
    try {
      await api.createMedicine({});
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.status, 422);
      expect(e.fields?['name'], 'Name is required.');
    }
  });

  test('network failure becomes a friendly ApiException', () async {
    final api = ApiClient('http://x',
        client: MockClient((_) async => throw http.ClientException('boom')));
    expect(() => api.health(), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'network')));
  });

  test('204 delete succeeds with an empty body', () async {
    final api = ApiClient('http://x/', client: MockClient((req) async {
      expect(req.url.toString(), 'http://x/api/medicines/3');
      return http.Response('', 204);
    }));
    await api.deleteMedicine(3);
  });

  test('conflict from recording a dose surfaces the server message', () async {
    final api = ApiClient('http://x', client: MockClient((_) async => _json({
          'error': {'code': 'invalid_transition', 'message': 'Dose already recorded; undo it first.'}
        }, 409)));
    expect(() => api.record('1|2026-10-28|08:00', 'skipped'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)));
  });
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.code, this.message, {this.status, this.fields});
  final String code, message;
  final int? status;
  final Map<String, String>? fields;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  static const _timeout = Duration(seconds: 10);

  Future<dynamic> _send(String method, String path,
      {Map<String, String>? query, Object? body}) async {
    final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$root/api$path').replace(queryParameters: query);
    final http.Response res;
    try {
      final req = http.Request(method, uri)..headers['Content-Type'] = 'application/json';
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _client.send(req).timeout(_timeout));
    } catch (_) {
      throw ApiException('network',
          'Cannot reach the MedMinder server at $baseUrl. Check the address in Settings and that the API is running.');
    }
    if (res.body.isEmpty) {
      if (res.statusCode >= 400) {
        throw ApiException('http_${res.statusCode}', 'Request failed (${res.statusCode}).',
            status: res.statusCode);
      }
      return null;
    }
    final dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw ApiException('bad_response', 'The server sent an unreadable response.',
          status: res.statusCode);
    }
    if (res.statusCode >= 400) {
      final e = data is Map ? data['error'] : null;
      final fields = (e is Map && e['fields'] is Map)
          ? (e['fields'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
          : null;
      throw ApiException(
        (e is Map ? e['code'] : null)?.toString() ?? 'http_${res.statusCode}',
        (e is Map ? e['message'] : null)?.toString() ?? 'Request failed (${res.statusCode}).',
        status: res.statusCode,
        fields: fields,
      );
    }
    return data;
  }

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) f) =>
      (data as List).map((e) => f(e as Map<String, dynamic>)).toList();

  Future<Map<String, dynamic>> health() async =>
      (await _send('GET', '/health')) as Map<String, dynamic>;

  Future<List<Medicine>> listMedicines() async =>
      _list(await _send('GET', '/medicines'), Medicine.fromJson);

  Future<MedicineDetail> getMedicine(int id) async =>
      MedicineDetail.fromJson((await _send('GET', '/medicines/$id')) as Map<String, dynamic>);

  Future<Medicine> createMedicine(Map<String, dynamic> body) async => Medicine.fromJson(
      (await _send('POST', '/medicines', body: body)) as Map<String, dynamic>);

  Future<Medicine> updateMedicine(int id, Map<String, dynamic> body) async =>
      Medicine.fromJson((await _send('PUT', '/medicines/$id', body: body)) as Map<String, dynamic>);

  Future<void> deleteMedicine(int id) => _send('DELETE', '/medicines/$id');

  Future<void> setPaused(int id, bool paused) =>
      _send('POST', '/medicines/$id/${paused ? 'pause' : 'resume'}');

  Future<List<Dose>> dosesForDay(String date) async =>
      _list(await _send('GET', '/doses', query: {'date': date}), Dose.fromJson);

  Future<Dose> record(String doseId, String outcome) async => Dose.fromJson((await _send(
          'POST', '/doses/record', body: {'dose_id': doseId, 'outcome': outcome}))
      as Map<String, dynamic>);

  Future<void> undo(String doseId) => _send('POST', '/doses/undo', body: {'dose_id': doseId});

  Future<HistoryResult> history(String from, String to, {int? medicineId}) async {
    final j = (await _send('GET', '/history', query: {
      'from': from,
      'to': to,
      if (medicineId != null) 'medicine_id': '$medicineId',
    })) as Map<String, dynamic>;
    return HistoryResult(_list(j['doses'], Dose.fromJson),
        Adherence.fromJson(j['adherence'] as Map<String, dynamic>));
  }

  Future<void> loadDemo() => _send('POST', '/demo/load');
  Future<void> clearDemo() => _send('DELETE', '/demo');
}

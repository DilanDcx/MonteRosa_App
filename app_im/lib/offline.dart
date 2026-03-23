import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OfflineService {
  static const String boxName = 'pendientesBox';

  // ==========================================
  // 1. EL RADAR (Ahora es público para usarlo en botones)
  // ==========================================
  static Future<bool> tieneInternet() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    return true;
  }

  // ==========================================
  // 2. INTERCEPTOR DE TEXTO (JSON)
  // ==========================================
  static Future<bool> peticionSegura({required String url, required String metodo, required Map<String, dynamic> body}) async {
    bool conectado = await tieneInternet();

    if (conectado) {
      try {
        final uri = Uri.parse(url);
        http.Response response;
        if (metodo == 'PATCH') {
          response = await http.patch(uri, headers: {"Content-Type": "application/json"}, body: json.encode(body)).timeout(const Duration(seconds: 8));
        } else {
          response = await http.post(uri, headers: {"Content-Type": "application/json"}, body: json.encode(body)).timeout(const Duration(seconds: 8));
        }

        if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
          return true; 
        } else {
          await _guardarEnBoveda(url, metodo, body, false);
          return false;
        }
      } catch (e) {
        await _guardarEnBoveda(url, metodo, body, false);
        return false;
      }
    } else {
      await _guardarEnBoveda(url, metodo, body, false);
      return false;
    }
  }

  // ==========================================
  // 3. NUEVO: INTERCEPTOR DE FOTOS (MULTIPART)
  // ==========================================
  static Future<bool> subirFotoSegura({required String url, required String imagePath, required Map<String, String> fields}) async {
    bool conectado = await tieneInternet();

    if (conectado) {
      try {
        var request = http.MultipartRequest('POST', Uri.parse(url));
        request.fields.addAll(fields);
        request.files.add(await http.MultipartFile.fromPath('foto', imagePath));

        var response = await request.send().timeout(const Duration(seconds: 15));
        if (response.statusCode == 201 || response.statusCode == 200) {
          print("🌐 [ONLINE] Foto enviada con éxito.");
          return true;
        } else {
          await _guardarFotoEnBoveda(url, imagePath, fields);
          return false;
        }
      } catch (e) {
        await _guardarFotoEnBoveda(url, imagePath, fields);
        return false;
      }
    } else {
      await _guardarFotoEnBoveda(url, imagePath, fields);
      return false;
    }
  }

  // ==========================================
  // 4. LAS BÓVEDAS (Texto y Fotos)
  // ==========================================
  static Future<void> _guardarEnBoveda(String url, String metodo, Map<String, dynamic> body, bool esFoto) async {
    var box = Hive.box(boxName);
    await box.add({'es_foto': false, 'url': url, 'metodo': metodo, 'body': body, 'fecha_guardado': DateTime.now().toIso8601String()});
  }

  static Future<void> _guardarFotoEnBoveda(String url, String path, Map<String, String> fields) async {
    var box = Hive.box(boxName);
    await box.add({'es_foto': true, 'url': url, 'path': path, 'fields': fields, 'fecha_guardado': DateTime.now().toIso8601String()});
    print("💾 [OFFLINE] Foto guardada en la bóveda local.");
  }

  // ==========================================
  // 5. MOTOR DE SINCRONIZACIÓN ACTUALIZADO
  // ==========================================
  static Future<void> sincronizarPendientes() async {
    bool conectado = await tieneInternet();
    if (!conectado) return; 

    var box = Hive.box(boxName);
    if (box.isEmpty) return; 

    print("🔄 [SYNC] Sincronizando ${box.length} elementos...");
    List<dynamic> keys = box.keys.toList();
    
    for (var key in keys) {
      var peticion = box.get(key);
      bool esFoto = peticion['es_foto'] ?? false;
      String url = peticion['url'];

      try {
        if (esFoto) {
          // PROCESAR FOTO
          String path = peticion['path'];
          Map<String, String> fields = Map<String, String>.from(peticion['fields']);
          var request = http.MultipartRequest('POST', Uri.parse(url));
          request.fields.addAll(fields);
          request.files.add(await http.MultipartFile.fromPath('foto', path));
          
          var response = await request.send();
          if (response.statusCode == 200 || response.statusCode == 201) await box.delete(key);
        } else {
          // PROCESAR TEXTO/JSON
          String metodo = peticion['metodo'];
          Map<String, dynamic> body = Map<String, dynamic>.from(peticion['body']);
          final uri = Uri.parse(url);
          http.Response response;
          
          if (metodo == 'PATCH') {
            response = await http.patch(uri, headers: {"Content-Type": "application/json"}, body: json.encode(body));
          } else {
            response = await http.post(uri, headers: {"Content-Type": "application/json"}, body: json.encode(body));
          }
          if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) await box.delete(key);
        }
      } catch (e) {
        print("❌ [SYNC] Error en elemento $key. Se reintentará luego.");
      }
    }
  }
}
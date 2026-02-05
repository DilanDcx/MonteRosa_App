import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// =========================================================
// 1. CONFIGURACIÓN GLOBAL Y LOGIN (BLINDADO)
// =========================================================
const String baseUrl = "http://192.168.137.62:8000"; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monte Rosa App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00529B)),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool cargando = false;
  final _opCodigoController = TextEditingController();
  final _adminUserController = TextEditingController();
  final _adminPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _opCodigoController.dispose();
    _adminUserController.dispose();
    _adminPassController.dispose();
    super.dispose();
  }

  // --- LOGIN OPERARIO (CON DETECCIÓN DE "SIN NOMBRE") ---
  Future<void> _loginOperario() async {
    FocusScope.of(context).unfocus();
    if (_opCodigoController.text.isEmpty) return;

    setState(() => cargando = true);
    final url = Uri.parse('$baseUrl/api/login-operario/');
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"codigo": _opCodigoController.text.trim()}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {   
        final data = json.decode(response.body);
        String codigo = data['codigo'].toString();
        
        // 1. Limpiamos el nombre recibido
        var rawName = data['nombre'];
        String n = (rawName ?? "").toString().trim();
        String nLower = n.toLowerCase(); // Para comparar fácil

        // 2. LISTA NEGRA: Textos que NO son nombres válidos
        bool nombreInvalido = 
             n.isEmpty || 
             nLower == "null" || 
             nLower == "none" || 
             nLower.contains("sin nombre") || // <--- AQUÍ ESTÁ EL ARREGLO
             nLower.contains("no asignado") ||
             n.length < 3; // Nombres de menos de 3 letras sospechosos

        if (nombreInvalido) {
           // Si el servidor dice "Sin nombre", nosotros decimos "Preguntar"
           if (mounted) _mostrarDialogoPedirNombre(codigo);
        } else {
           // Si es un nombre real, pasamos
           _navegarAOrdenes(codigo, n); 
        }
      } else {
        _mostrarError("Acceso Denegado", "El código ingresado no existe.");
      }
    } catch (e) {
      _mostrarError("Error de Conexión", e.toString());
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  void _mostrarDialogoPedirNombre(String codigo) {
    final nombreController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("¡Bienvenido!"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Es tu primera vez. ¿Cuál es tu nombre?"),
            const SizedBox(height: 10),
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Tu Nombre Completo"), textCapitalization: TextCapitalization.words)
        ]),
        actions: [
          ElevatedButton(
            onPressed: () async {
              // Validamos que escriba algo decente
              if (nombreController.text.trim().length > 2) {
                Navigator.pop(ctx);
                await _actualizarNombreInicial(codigo, nombreController.text.trim());
              }
            },
            child: const Text("GUARDAR")
          )
        ],
      ),
    );
  }

  Future<void> _actualizarNombreInicial(String codigo, String nombre) async {
    setState(() => cargando = true);
    final url = Uri.parse('$baseUrl/api/login-operario/');
    try {
      // Forzamos al servidor a actualizar ese "Sin nombre" por el nombre real
      await http.post(url, headers: {"Content-Type": "application/json"}, body: json.encode({"codigo": codigo, "nombre": nombre}));
      _navegarAOrdenes(codigo, nombre);
    } catch (e) { print(e); }
  }

  void _navegarAOrdenes(String codigo, String nombre) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OrdenesScreen(codigoTrabajador: codigo, nombreTrabajador: nombre)));
  }

  // --- LOGIN ADMIN ---
  Future<void> _loginAdmin() async {
    FocusScope.of(context).unfocus();
    setState(() => cargando = true);
    final url = Uri.parse('$baseUrl/api/login-admin/');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"username": _adminUserController.text.trim(), "password": _adminPassController.text.trim()}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AdminDashboard(nombreAdmin: data['nombre'])));
      } else {
        _mostrarError("Error", "Credenciales incorrectas.");
      }
    } catch (e) {_mostrarError("Error", e.toString());} finally {if(mounted) setState(()=>cargando=false);}
  }
  
  void _mostrarError(String t, String m) {
      showDialog(context: context, builder: (ctx)=>AlertDialog(title:Text(t), content:Text(m), actions:[TextButton(onPressed: ()=>Navigator.pop(ctx), child:Text("OK"))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Icon(Icons.factory, size: 60, color: Color(0xFF00529B)),
            const SizedBox(height: 10),
            const Text("Ingenio Monte Rosa", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00529B))),
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Container(decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(25)), child: TabBar(controller: _tabController, indicator: BoxDecoration(color: const Color(0xFF00529B), borderRadius: BorderRadius.circular(25)), labelColor: Colors.white, unselectedLabelColor: Colors.grey[600], tabs: const [Tab(text: "Soy Operario"), Tab(text: "Soy Admin")]))),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
                        const Text("Ingreso de Personal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 30),
                        TextField(controller: _opCodigoController, decoration: const InputDecoration(labelText: "Código", prefixIcon: Icon(Icons.badge)), keyboardType: TextInputType.number),
                        const SizedBox(height: 30),
                        if (cargando) const CircularProgressIndicator() else ElevatedButton(onPressed: _loginOperario, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue[700], foregroundColor: Colors.white), child: const Text("INGRESAR")),
                  ])),
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
                        const Text("Acceso Admin", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 30),
                        TextField(controller: _adminUserController, decoration: const InputDecoration(labelText: "Usuario", prefixIcon: Icon(Icons.admin_panel_settings))),
                        const SizedBox(height: 15),
                        TextField(controller: _adminPassController, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock))),
                        const SizedBox(height: 30),
                        if (cargando) const CircularProgressIndicator() else ElevatedButton(onPressed: _loginAdmin, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white), child: const Text("INGRESAR")),
                  ])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ==========================================
// 2. PANEL DE ADMINISTRADOR (DASHBOARD)
// ==========================================
class AdminDashboard extends StatefulWidget {
  final String nombreAdmin;
  const AdminDashboard({super.key, required this.nombreAdmin});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<dynamic> pendientes = [];
  List<dynamic> completadas = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    fetchTodasLasOrdenes();
  }

  Future<void> fetchTodasLasOrdenes() async {
    final url = Uri.parse('$baseUrl/api/ordenes/');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        List<dynamic> todas = json.decode(response.body);
        if (mounted) {
          setState(() {
            pendientes = todas.where((o) => o['completada'] == false).toList();
            completadas = todas.where((o) => o['completada'] == true).toList();
            // Ordenar por ID descendente (nuevas arriba)
            pendientes.sort((a, b) => b['id'].compareTo(a['id']));
            completadas.sort((a, b) => b['id'].compareTo(a['id']));
            cargando = false;
          });
        }
      } else { if (mounted) _mostrarAlertaError("Error Servidor", response.body); }
    } catch (e) { if (mounted) _mostrarAlertaError("Error Conexión", e.toString()); }
  }

  void _mostrarAlertaError(String titulo, String mensaje) {
    setState(() => cargando = false);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(titulo, style: const TextStyle(color: Colors.red)), content: Text(mensaje), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Admin: ${widget.nombreAdmin}"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(labelColor: Colors.white, unselectedLabelColor: Colors.white70, tabs: [Tab(text: "PENDIENTES"), Tab(text: "HISTORIAL FINALIZADO")]),
          actions: [IconButton(icon: const Icon(Icons.exit_to_app), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())))],
        ),
        body: cargando ? const Center(child: CircularProgressIndicator()) : TabBarView(children: [_listaAdmin(pendientes, esHistorial: false), _listaAdmin(completadas, esHistorial: true)]),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.indigo, child: const Icon(Icons.add, color: Colors.white), tooltip: "Crear Nueva Orden",
          onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const CrearOrdenScreen())).then((_) { setState(() => cargando = true); fetchTodasLasOrdenes(); }); },
        ),
      ),
    );
  }

  Widget _listaAdmin(List<dynamic> lista, {required bool esHistorial}) {
    if (lista.isEmpty) return Center(child: Text(esHistorial ? "No hay historial" : "Todo al día", style: const TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final orden = lista[index];
        
        // LETRA DE LA UBICACIÓN
        String letraAvatar = "?";
        if (orden['ubicacion'] != null && orden['ubicacion'].toString().isNotEmpty) {
           letraAvatar = orden['ubicacion'][0].toUpperCase();
        }
        
        // COLOR PRIORIDAD
        Color colorAvatar = _colorPrioridad(orden['prioridad']);

        return Card(
          elevation: 3, margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorAvatar,
              child: Text(letraAvatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text("Orden #${orden['numero_orden']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Asignado a: ${orden['codigo_trabajador']}"),
                Text("Ubicación: ${orden['ubicacion']}"),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!esHistorial) IconButton(icon: const Icon(Icons.edit, color: Colors.indigo), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => EditarOrdenScreen(orden: orden))).then((_) { setState(() => cargando = true); fetchTodasLasOrdenes(); }); }),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ]),
            onTap: () { 
                // CORRECCIÓN: Pasamos "ADMIN" como nombreTrabajador para poder ver el detalle sin errores
                Navigator.push(context, MaterialPageRoute(builder: (context) => DetalleOrdenScreen(orden: orden, nombreTrabajador: "ADMIN"))).then((_) => fetchTodasLasOrdenes()); 
            },
          ),
        );
      },
    );
  }

  Color _colorPrioridad(String? p) {
    if (p == 'ALTA') return Colors.red;
    if (p == 'MEDIA') return Colors.orange;
    return Colors.green; 
  }
}

// ==========================================
// 3. FORMULARIO CREAR ORDEN
// ==========================================
class CrearOrdenScreen extends StatefulWidget {
  const CrearOrdenScreen({super.key});

  @override
  State<CrearOrdenScreen> createState() => _CrearOrdenScreenState();
}

class _CrearOrdenScreenState extends State<CrearOrdenScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- CONTROLADORES ---
  final _numeroController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _procesoController = TextEditingController(); 
  final _trabajadorController = TextEditingController();
  final _supervisorController = TextEditingController();

  String _prioridad = 'MEDIA';
  DateTime _inicio = DateTime.now();
  DateTime _fin = DateTime.now().add(const Duration(hours: 4));

  List<Map<String, dynamic>> _actividadesTemporales = [];

  Future<void> _seleccionarFechaHora(bool esInicio) async {
    DateTime base = esInicio ? _inicio : _fin;
    
    final DateTime? fecha = await showDatePicker(
      context: context, initialDate: base, firstDate: DateTime(2024), lastDate: DateTime(2030),
    );
    if (fecha == null) return;

    if (!mounted) return;
    final TimeOfDay? hora = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (hora == null) return;

    final DateTime finalDT = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
    
    setState(() {
      if (esInicio) _inicio = finalDT; else _fin = finalDT;
    });
  }

  void _mostrarDialogoActividad() {
    final descController = TextEditingController();
    final areaController = TextEditingController();
    final horasController = TextEditingController(text: "01");
    final minutosController = TextEditingController(text: "00");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Agregar Actividad"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descController, decoration: const InputDecoration(labelText: "Descripción")),
            const SizedBox(height: 10),
            TextField(controller: areaController, decoration: const InputDecoration(labelText: "Área")),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: horasController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Horas"))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: minutosController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Min"))),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (descController.text.isNotEmpty) {
                String duracion = "${horasController.text.padLeft(2,'0')}:${minutosController.text.padLeft(2,'0')}:00";
                
                setState(() {
                  _actividadesTemporales.add({
                    "descripcion": descController.text,
                    "area": areaController.text,
                    "tiempo_planificado": duracion,
                    "tiempo_real_acumulado": "00:00:00",
                    "en_progreso": false,
                    "completada": false
                  });
                });
                Navigator.pop(ctx);
              }
            }, 
            child: const Text("AGREGAR")
          )
        ],
      ),
    );
  }

  Future<void> _guardarOrden() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_actividadesTemporales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debe agregar al menos una actividad")));
      return;
    }

    final url = Uri.parse('$baseUrl/api/ordenes/');
    
    Map<String, dynamic> datos = {
      'numero_orden': _numeroController.text,
      'ubicacion': _ubicacionController.text,
      'ubicacion_tecnica': _ubicacionController.text, 
      'proceso': _procesoController.text,
      'codigo_trabajador': _trabajadorController.text,
      'supervisor_nombre': _supervisorController.text,
      'supervisor_codigo': "ADMIN", 
      'prioridad': _prioridad,
      'inicio_programado': _inicio.toIso8601String(),
      'fin_programado': _fin.toIso8601String(),
      'reserva': "N/A",
      'actividades': _actividadesTemporales 
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(datos),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Orden Creada Exitosamente")));
          Navigator.pop(context); 
        }
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${response.body}"), backgroundColor: Colors.red));
      }
    } catch (e) { 
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Conexión: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nueva Orden")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Datos Generales", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _numeroController, decoration: const InputDecoration(labelText: "N° Orden"), validator: (v) => v!.isEmpty ? "*" : null)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _trabajadorController, decoration: const InputDecoration(labelText: "Cód. Trabajador"), validator: (v) => v!.isEmpty ? "*" : null)),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(controller: _supervisorController, decoration: const InputDecoration(labelText: "Nombre Supervisor")),
              const SizedBox(height: 10),
              TextFormField(controller: _ubicacionController, decoration: const InputDecoration(labelText: "Ubicación"), validator: (v) => v!.isEmpty ? "*" : null),
              const SizedBox(height: 10),
              TextFormField(controller: _procesoController, decoration: const InputDecoration(labelText: "Proceso (Ej: Calderas)"), validator: (v) => v!.isEmpty ? "Requerido" : null),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _prioridad,
                decoration: const InputDecoration(labelText: "Prioridad"),
                items: ['ALTA', 'MEDIA', 'BAJA'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (val) => setState(() => _prioridad = val!),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _seleccionarFechaHora(true), icon: const Icon(Icons.calendar_today), label: Text("Inicio:\n${_inicio.toString().substring(0,16)}"))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: () => _seleccionarFechaHora(false), icon: const Icon(Icons.event_busy), label: Text("Fin:\n${_fin.toString().substring(0,16)}"))),
                ],
              ),
              const Divider(height: 30, thickness: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Actividades", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(onPressed: _mostrarDialogoActividad, icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 30))
                ],
              ),
              if (_actividadesTemporales.isEmpty) 
                const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("Sin actividades", style: TextStyle(color: Colors.grey))))
              else 
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _actividadesTemporales.length,
                  itemBuilder: (context, index) {
                    final act = _actividadesTemporales[index];
                    return Card(
                      color: Colors.grey[50],
                      child: ListTile(
                        leading: CircleAvatar(child: Text("${index + 1}")),
                        title: Text(act['descripcion']),
                        subtitle: Text("Plan: ${act['tiempo_planificado']}"),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _actividadesTemporales.removeAt(index))),
                      ),
                    );
                  }
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _guardarOrden,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                child: const Text("GUARDAR ORDEN"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
// ==========================================
// 4. PANTALLA MIS ÓRDENES (CON FILTRO DE SEGURIDAD ESTRICTO)
// ==========================================
class OrdenesScreen extends StatefulWidget {
  final String codigoTrabajador;
  final String nombreTrabajador; 

  const OrdenesScreen({
    super.key, 
    required this.codigoTrabajador, 
    required this.nombreTrabajador
  });

  @override
  State<OrdenesScreen> createState() => _OrdenesScreenState();
}

class _OrdenesScreenState extends State<OrdenesScreen> {
  List<dynamic> _pendientes = [];
  List<dynamic> _historial = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    fetchOrdenes();
  }

  Future<void> fetchOrdenes() async {
    // 1. Petición al servidor intentando filtrar
    final url = Uri.parse('$baseUrl/api/ordenes/?trabajador=${widget.codigoTrabajador}');
    
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        List<dynamic> todas = json.decode(response.body);
        
        // =======================================================
        // 🔒 FILTRO DE SEGURIDAD EN FRONTEND (CLIENT-SIDE)
        // =======================================================
        // Aunque el servidor debería filtrar, aquí nos aseguramos al 100%
        // de eliminar cualquier orden que no sea de este usuario.
        // Si el usuario es "0010", eliminamos cualquier orden que diga "0011", "0012", etc.
        List<dynamic> soloMias = todas.where((o) {
          String assignedWorker = (o['codigo_trabajador'] ?? "").toString().trim();
          String myCode = widget.codigoTrabajador.trim();
          return assignedWorker == myCode;
        }).toList();

        if (mounted) {
          setState(() {
            // Ahora repartimos en pestañas SOLO las que pasaron el filtro
            _pendientes = soloMias.where((o) => o['completada'] == false).toList();
            _historial = soloMias.where((o) => o['completada'] == true).toList();

            // Ordenar: Recientes primero
            _pendientes.sort((a, b) => b['id'].compareTo(a['id']));
            _historial.sort((a, b) => b['id'].compareTo(a['id']));
            
            cargando = false;
          });
        }
      } else {
        if(mounted) _mostrarAlertaError("Error Servidor", response.body);
      }
    } catch (e) {
      if(mounted) _mostrarAlertaError("Error Conexión", e.toString());
    }
  }

  void _mostrarAlertaError(String titulo, String mensaje) {
    setState(() => cargando = false);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(titulo, style: const TextStyle(color: Colors.red)), content: Text(mensaje), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Mis Asignaciones", style: TextStyle(fontSize: 16)),
              Text("${widget.nombreTrabajador} (${widget.codigoTrabajador})", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: "Cerrar Sesión",
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))
            )
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF00529B),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF00529B),
            tabs: [
              Tab(icon: Icon(Icons.work_history), text: "PENDIENTES"),
              Tab(icon: Icon(Icons.check_circle), text: "HISTORIAL"),
            ],
          ),
        ),
        body: cargando 
          ? const Center(child: CircularProgressIndicator()) 
          : TabBarView(
              children: [
                _buildListaOrdenes(_pendientes, esHistorial: false),
                _buildListaOrdenes(_historial, esHistorial: true),
              ],
            ),
      ),
    );
  }

  Widget _buildListaOrdenes(List<dynamic> lista, {required bool esHistorial}) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(esHistorial ? Icons.history : Icons.assignment_turned_in, size: 50, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              esHistorial ? "No tienes historial aún" : "¡Todo listo!\nNo tienes órdenes asignadas",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchOrdenes,
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final orden = lista[index];
          
          String letraAvatar = "?";
          if (orden['ubicacion'] != null && orden['ubicacion'].toString().isNotEmpty) {
             letraAvatar = orden['ubicacion'][0].toUpperCase();
          }
          
          Color colorAvatar = Colors.orange;
          if (orden['prioridad'] == 'ALTA') colorAvatar = Colors.red;
          if (orden['prioridad'] == 'BAJA') colorAvatar = Colors.green;
          Color colorFinal = esHistorial ? Colors.green : colorAvatar;

          return Card(
            elevation: 2, 
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colorFinal,
                child: esHistorial 
                    ? const Icon(Icons.check, color: Colors.white) 
                    : Text(letraAvatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text("Orden #${orden['numero_orden']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(orden['ubicacion'] ?? "Sin ubicación"),
                  // Mostramos el código del trabajador solo para confirmar que funcionó el filtro
                  if (!esHistorial) Text("Asignado a: ${orden['codigo_trabajador']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DetalleOrdenScreen(orden: orden, nombreTrabajador: widget.nombreTrabajador))
                ).then((_) { 
                  setState(() => cargando = true); 
                  fetchOrdenes(); 
                });
              },
            ),
          );
        },
      ),
    );
  }
}
// ==========================================
// 5. DETALLE DE ORDEN (SEPARADO Y CON NOMBRE)
// ==========================================
class DetalleOrdenScreen extends StatefulWidget {
  final Map<String, dynamic> orden;
  // ✅ CORRECCIÓN: Recibimos el nombre aquí también
  final String nombreTrabajador;

  const DetalleOrdenScreen({
    super.key, 
    required this.orden, 
    required this.nombreTrabajador
  });

  @override
  State<DetalleOrdenScreen> createState() => _DetalleOrdenScreenState();
}

class _DetalleOrdenScreenState extends State<DetalleOrdenScreen> {
  late Map<String, dynamic> ordenActual;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    ordenActual = widget.orden;
    _recargarOrden();
  }

  Future<void> _recargarOrden() async {
    final url = Uri.parse('$baseUrl/api/ordenes/${widget.orden['id']}/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) setState(() => ordenActual = json.decode(response.body));
      }
    } catch (e) { /* */ }
  }

  Future<void> _finalizarOrdenCompleta() async {
    bool? confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Finalizar Orden?"),
        content: const Text("La orden pasará al historial inmediatamente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("SÍ, FINALIZAR", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _enviando = true);
    final url = Uri.parse('$baseUrl/api/ordenes/${ordenActual['id']}/finalizar/');

    try {
      final response = await http.post(url, headers: {"Content-Type": "application/json"});
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Orden cerrada con éxito!")));
          Navigator.pop(context); 
        }
      } else {
        if (mounted) _mostrarError("Error Servidor", response.body);
      }
    } catch (e) {
      if (mounted) _mostrarError("Error Conexión", e.toString());
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarError(String t, String m) {
    showDialog(context: context, builder: (ctx)=>AlertDialog(title:Text(t, style:TextStyle(color:Colors.red)), content:Text(m), actions:[TextButton(onPressed:()=>Navigator.pop(ctx), child:Text("OK"))]));
  }

  String _calcularTiempoPausas(List<dynamic> bitacora) {
    if (bitacora.isEmpty) return "00:00:00";
    Duration tiempoPausadoTotal = Duration.zero;
    DateTime? inicioPausa;
    List<dynamic> eventos = List.from(bitacora);
    eventos.sort((a, b) => (a['fecha_hora'] ?? "").compareTo(b['fecha_hora'] ?? ""));

    for (var evento in eventos) {
      String tipo = evento['evento'];
      DateTime fecha = DateTime.parse(evento['fecha_hora']);
      if (tipo == 'PAUSA') {
        inicioPausa = fecha;
      } else if ((tipo == 'REANUDAR' || tipo == 'FINAL') && inicioPausa != null) {
        tiempoPausadoTotal += fecha.difference(inicioPausa);
        inicioPausa = null;
      }
    }
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(tiempoPausadoTotal.inHours)}:${twoDigits(tiempoPausadoTotal.inMinutes.remainder(60))}:${twoDigits(tiempoPausadoTotal.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    // 1. SEPARAMOS LISTAS: Pendientes y Terminadas
    List<dynamic> todas = ordenActual['actividades'] ?? [];
    List<dynamic> pendientes = todas.where((a) => a['completada'] == false).toList();
    List<dynamic> terminadas = todas.where((a) => a['completada'] == true).toList();
    
    bool ordenCerrada = ordenActual['completada'] ?? false;

    return Scaffold(
      appBar: AppBar(title: Text("Orden #${ordenActual['numero_orden']}")),
      body: Column(
        children: [
          // CABECERA
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Ubicación: ${ordenActual['ubicacion']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Proceso: ${ordenActual['proceso']}"),
                if (ordenCerrada) const Chip(label: Text("FINALIZADA", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green)
              ],
            ),
          ),
          
          // CUERPO DIVIDIDO
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                // SECCIÓN PENDIENTES
                if (pendientes.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("📌 ACTIVIDADES PENDIENTES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
                  ...pendientes.map((act) => _cardActividad(act, false)),
                ],

                // SECCIÓN TERMINADAS
                if (terminadas.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("✅ ACTIVIDADES REALIZADAS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                  ...terminadas.map((act) => _cardActividad(act, true)),
                ],

                if (pendientes.isEmpty && terminadas.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No hay actividades"))),
              ],
            ),
          ),
          
          // BOTÓN FINALIZAR ORDEN
          if (!ordenCerrada && pendientes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16), 
              child: _enviando 
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _finalizarOrdenCompleta, 
                    icon: const Icon(Icons.archive), 
                    label: const Text("FINALIZAR ORDEN"), 
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF00529B), foregroundColor: Colors.white)
                  )
            )
        ],
      ),
    );
  }

  Widget _cardActividad(dynamic act, bool completada) {
    List<dynamic> bitacora = act['bitacora'] ?? [];
    String tiempoPausas = completada ? _calcularTiempoPausas(bitacora) : "00:00";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      color: completada ? Colors.green[50] : Colors.white,
      child: ListTile(
        title: Text(act['descripcion'], style: TextStyle(decoration: completada ? TextDecoration.lineThrough : null)),
        subtitle: completada 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Ejecutor: ${act['nombre_ejecutor'] ?? 'Desconocido'}"),
                  Text("Tiempo Activo: ${act['tiempo_real_acumulado']}"),
                  Text("Tiempo Pausas: $tiempoPausas", style: TextStyle(color: Colors.orange[800])),
                ],
              )
            : Text("Plan: ${act['tiempo_planificado']}"),
        trailing: completada 
          ? const Icon(Icons.check_circle, color: Colors.green) 
          : ElevatedButton(
              child: const Text("ABRIR"),
              onPressed: () {
                // ✅ PASO FINAL DEL TESTIGO: Enviamos el nombre al cronómetro
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EjecucionActividadScreen(
                      actividad: act, 
                      nombreTrabajador: widget.nombreTrabajador // <--- NOMBRE ENVIADO
                    )
                  )
                ).then((_) => _recargarOrden()); // Auto-refresco al volver
              },
            ),
      ),
    );
  }
}

// ==========================================
// 6. PANTALLA DE EJECUCIÓN (CON CÁLCULO DE TIEMPO OFF-LINE)
// ==========================================
class EjecucionActividadScreen extends StatefulWidget {
  final Map<String, dynamic> actividad;
  final String nombreTrabajador; 

  const EjecucionActividadScreen({
    super.key, 
    required this.actividad,
    required this.nombreTrabajador
  });

  @override
  State<EjecucionActividadScreen> createState() => _EjecucionActividadScreenState();
}

class _EjecucionActividadScreenState extends State<EjecucionActividadScreen> with WidgetsBindingObserver {
  late Map<String, dynamic> actividadData;
  Timer? _timer;
  Duration _tiempoAcumulado = Duration.zero;
  bool _enProgreso = false;
  bool _finalizado = false;
  
  List<dynamic> _historialBitacora = [];
  final _notasController = TextEditingController();
  final _nombreManualController = TextEditingController(); 

  @override
  void initState() {
    super.initState();
    // Registramos el observador para detectar cuando la app se minimiza/abre
    WidgetsBinding.instance.addObserver(this);
    
    actividadData = widget.actividad;
    if (actividadData['bitacora'] != null) {
      _historialBitacora = List.from(actividadData['bitacora']);
      // Ordenamos la bitácora cronológicamente (antiguos primero, nuevos al final) para asegurar cálculos correctos
      _historialBitacora.sort((a, b) => (a['fecha_hora']??"").compareTo(b['fecha_hora']??""));
    }
    _sincronizarEstadoInicial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Detecta cuando la app vuelve del segundo plano
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Si el usuario vuelve a abrir la app, recalculamos el tiempo
      _sincronizarEstadoInicial();
    }
  }

  void _sincronizarEstadoInicial() {
    _timer?.cancel(); // Detenemos cualquier timer anterior para no duplicar

    // 1. Recuperamos el tiempo base guardado en la Base de Datos
    if (actividadData['tiempo_real_acumulado'] != null) {
      try {
        List<String> parts = actividadData['tiempo_real_acumulado'].split(':');
        _tiempoAcumulado = Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]), seconds: double.parse(parts[2]).toInt());
      } catch (e) { /* */ }
    }

    _enProgreso = actividadData['en_progreso'] ?? false;
    _finalizado = actividadData['completada'] ?? false;

    // 2. MAGIA MATEMÁTICA: Recuperar tiempo perdido
    // Si la tarea dice que está "en progreso", calculamos cuánto tiempo pasó desde el último evento
    if (_enProgreso && !_finalizado && _historialBitacora.isNotEmpty) {
      try {
        // Tomamos el último evento registrado (debería ser INICIO o REANUDAR)
        var ultimoEvento = _historialBitacora.last;
        
        if (ultimoEvento['fecha_hora'] != null) {
          DateTime fechaUltimoEvento = DateTime.parse(ultimoEvento['fecha_hora']);
          DateTime ahora = DateTime.now();
          
          // Calculamos la diferencia real
          Duration tiempoTranscurridoOffline = ahora.difference(fechaUltimoEvento);
          
          // Nota: El 'tiempo_real_acumulado' que viene de la BD es el acumulado HASTA el último guardado.
          // Pero si el backend guardó el tiempo acumulado viejo, necesitamos sumarle lo que pasó desde el último evento.
          // Para simplificar y evitar duplicados, reseteamos el acumulado al valor de la BD
          // y le sumamos la diferencia si el último evento fue reciente.
          
          // Lógica simplificada: 
          // El acumulado en la app debe ser: (Lo que había antes) + (Lo que pasó desde el último Play hasta hoy)
          // PERO como 'tiempo_real_acumulado' se actualiza al pausar, 
          // aquí asumimos que el tiempo acumulado en BD NO incluye el intervalo actual.
          
          // Ajuste: Solo sumamos si la fecha del evento es razonable (no negativa)
          if (!tiempoTranscurridoOffline.isNegative) {
             // IMPORTANTE: Aquí hay un truco. El backend suele guardar el acumulado "congelado".
             // Nosotros le sumamos el "tiempo vivo" que ha pasado desde el último Play.
             // Pero para no sumar doble al recargar, necesitamos saber si 'tiempo_real_acumulado' ya incluía esto.
             // Asumimos que Django solo actualiza 'tiempo_real_acumulado' cuando recibe un PATCH.
             
             // Por tanto: 
             // Tiempo Total = Tiempo Base (BD) + (Ahora - HoraInicioDeSesionActual)
             
             // Como no tenemos "HoraInicioDeSesionActual" separada, usamos la hora del último evento en bitácora.
             // PERO, si cerramos y abrimos la app, '_tiempoAcumulado' se reinicia al valor de BD.
             // Así que esto es correcto:
             
             _tiempoAcumulado += tiempoTranscurridoOffline;
          }
        }
      } catch (e) {
        print("Error calculando tiempo offline: $e");
      }
    }

    // 3. Si sigue en progreso, arrancamos el reloj visual para que siga sumando desde aquí
    if (_enProgreso && !_finalizado) _iniciarTimerVisual();
  }

  void _iniciarTimerVisual() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _tiempoAcumulado += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _registrarEventoBitacora(String tipoEvento) async {
    final url = Uri.parse('$baseUrl/api/bitacora/');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({'actividad': actividadData['id'], 'evento': tipoEvento})
      );
      if (response.statusCode == 201) {
        setState(() {
          _historialBitacora.add(json.decode(response.body));
          // Importante: Actualizamos el tiempo acumulado base en la variable local
          // para que si se minimiza justo ahora, el cálculo tenga referencia
        });
      }
    } catch (e) { print(e); }
  }

  Future<void> _actualizarActividadEnDjango(bool arrancando) async {
    // Al enviar a Django, enviamos el tiempo TOTAL calculado hasta este segundo
    String tiempoStr = _tiempoAcumulado.toString().split('.').first.padLeft(8, "0");
    Map<String, dynamic> datos = {'en_progreso': arrancando, 'tiempo_real_acumulado': tiempoStr};

    if (arrancando && actividadData['fecha_hora_inicio_real'] == null) {
      String nombreFinal = widget.nombreTrabajador;
      if (nombreFinal == "null" || nombreFinal.trim().isEmpty) {
          nombreFinal = _nombreManualController.text;
      }
      datos['nombre_ejecutor'] = nombreFinal;
      datos['fecha_hora_inicio_real'] = DateTime.now().toIso8601String();
    }

    final url = Uri.parse('$baseUrl/api/actividades/${actividadData['id']}/');
    try { 
      await http.patch(url, headers: {"Content-Type": "application/json"}, body: json.encode(datos)); 
      
      // Actualizamos datos locales para reflejar que se guardó en BD
      actividadData['en_progreso'] = arrancando;
      actividadData['tiempo_real_acumulado'] = tiempoStr; 
    } catch (e) { print(e); }

    setState(() {
      _enProgreso = arrancando;
      if (arrancando) _iniciarTimerVisual(); else _timer?.cancel();
    });
  }

  Future<void> _finalizarTareaEnDjango() async {
    _timer?.cancel();
    String tiempoStr = _tiempoAcumulado.toString().split('.').first.padLeft(8, "0");
    Map<String, dynamic> datos = {
      'en_progreso': false, 'completada': true, 'tiempo_real_acumulado': tiempoStr, 'fecha_hora_fin_real': DateTime.now().toIso8601String(), 'notas_operario': _notasController.text
    };

    final url = Uri.parse('$baseUrl/api/actividades/${actividadData['id']}/');
    try { 
      await http.patch(url, headers: {"Content-Type": "application/json"}, body: json.encode(datos));
      setState(() { _finalizado = true; _enProgreso = false; });
      if (mounted) Navigator.pop(context); 
    } catch (e) { print(e); }
  }

  // BOTÓN INICIAR INTELIGENTE
  Future<void> _botonIniciar() async {
    bool nombreInvalido = widget.nombreTrabajador == "null" || widget.nombreTrabajador.trim().isEmpty;
    bool faltaNombreManual = _nombreManualController.text.isEmpty;

    if (nombreInvalido && faltaNombreManual && actividadData['nombre_ejecutor'] == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Falta Identificación"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
             const Text("No se detectó tu nombre. Ingrésalo para continuar:"),
             const SizedBox(height: 10),
             TextField(controller: _nombreManualController, decoration: const InputDecoration(labelText: "Tu Nombre"))
          ]),
          actions: [
            ElevatedButton(onPressed: () { Navigator.pop(ctx); if (_nombreManualController.text.isNotEmpty) _botonIniciar(); }, child: const Text("GUARDAR E INICIAR"))
          ]
        )
      );
      return;
    }

    await _actualizarActividadEnDjango(true);
    String evento = _historialBitacora.isEmpty ? "INICIO" : "REANUDAR";
    await _registrarEventoBitacora(evento);
  }

  @override
  Widget build(BuildContext context) {
    String reloj = _tiempoAcumulado.toString().split('.').first.padLeft(8, "0");
    return Scaffold(
      appBar: AppBar(title: Text("Cód: ${actividadData['codigo_actividad']}")),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: Colors.white, width: double.infinity,
            child: Column(children: [
                Text(actividadData['descripcion'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(reloj, style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Color(0xFF00529B), fontFamily: 'monospace')),
                if (_finalizado) const Text("✅ FINALIZADA", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                else if (_enProgreso) const Text("🔥 TRABAJANDO...", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
            ]),
          ),
          
          Expanded(
            child: ListView.separated(
              itemCount: _historialBitacora.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                 // Mostramos lista invertida (más recientes arriba)
                 final ev = _historialBitacora[_historialBitacora.length - 1 - index];
                 String hora = "--:--";
                 if (ev['fecha_hora'] != null) { try { hora = ev['fecha_hora'].toString().split('T')[1].substring(0, 8); } catch(e){/* */} }
                 return ListTile(
                    dense: true,
                    leading: Icon(ev['evento'] == 'PAUSA' ? Icons.pause_circle : Icons.play_circle, color: ev['evento'] == 'PAUSA' ? Colors.orange : Colors.green),
                    title: Text(ev['evento'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text(hora),
                 );
              },
            ),
          ),

          if (!_finalizado) Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              if (!_enProgreso) 
                ElevatedButton.icon(onPressed: _botonIniciar, icon: const Icon(Icons.play_arrow), label: const Text("INICIAR / REANUDAR"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)))
              else 
                Column(children: [
                  ElevatedButton.icon(onPressed: () { _actualizarActividadEnDjango(false); _registrarEventoBitacora("PAUSA"); }, icon: const Icon(Icons.pause), label: const Text("PAUSAR"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50))),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(
                      title: const Text("Finalizar Tarea"),
                      content: TextField(controller: _notasController, decoration: const InputDecoration(labelText: "Notas Finales")),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(onPressed: () { Navigator.pop(ctx); _finalizarTareaEnDjango(); _registrarEventoBitacora("FINAL"); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("FINALIZAR"))]
                    )),
                    icon: const Icon(Icons.stop, color: Colors.red), label: const Text("FINALIZAR TAREA"),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), side: const BorderSide(color: Colors.red))
                  )
                ])
          ]))
        ],
      ),
    );
  }
}
// ==========================================
// 7. PANTALLA DE EDITAR ORDEN (MODO ADMIN/SUPERVISOR)
// ==========================================
class EditarOrdenScreen extends StatefulWidget {
  final Map<String, dynamic> orden;
  const EditarOrdenScreen({super.key, required this.orden});

  @override
  State<EditarOrdenScreen> createState() => _EditarOrdenScreenState();
}

class _EditarOrdenScreenState extends State<EditarOrdenScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // --- CONTROLADORES DE TEXTO ---
  late TextEditingController _numeroController;
  late TextEditingController _ubicacionController;
  late TextEditingController _ubicacionTecnicaController;
  
  // ✅ CAMPO PROCESO (Importante para que no se pierda al editar)
  late TextEditingController _procesoController;
  
  late TextEditingController _trabajadorController;
  late TextEditingController _supervisorController;
  
  // Variables de Estado
  late String _prioridad;
  late DateTime _inicio;
  late DateTime _fin;
  late String _supervisorCodigoOriginal; // Para no perder el ID del supervisor

  // Listas separadas:
  // 1. Actividades que ya venían del servidor (Solo Lectura / Bloqueadas)
  List<dynamic> _actividadesExistentes = [];
  // 2. Actividades nuevas que agregamos en esta edición
  List<Map<String, dynamic>> _actividadesNuevas = [];

  @override
  void initState() {
    super.initState();
    // Cargar datos de la orden que recibimos
    var o = widget.orden;
    
    _numeroController = TextEditingController(text: o['numero_orden']);
    _ubicacionController = TextEditingController(text: o['ubicacion']);
    // Si no hay ubicación técnica, usamos la ubicación normal por defecto
    _ubicacionTecnicaController = TextEditingController(text: o['ubicacion_tecnica'] ?? o['ubicacion']);
    _procesoController = TextEditingController(text: o['proceso']);
    _trabajadorController = TextEditingController(text: o['codigo_trabajador']);
    _supervisorController = TextEditingController(text: o['supervisor_nombre']);
    
    // Guardamos el código original del supervisor o "ADMIN" si no existe
    _supervisorCodigoOriginal = o['supervisor_codigo'] ?? "ADMIN";
    _prioridad = o['prioridad'];
    
    // Parseo seguro de fechas
    try {
      _inicio = DateTime.parse(o['inicio_programado']);
      _fin = DateTime.parse(o['fin_programado']);
    } catch (e) {
      _inicio = DateTime.now();
      _fin = DateTime.now().add(const Duration(hours: 4));
    }
    
    // Separamos las actividades existentes
    _actividadesExistentes = List.from(o['actividades'] ?? []);
  }

  // ---------------------------------------------------
  // LÓGICA: SELECTORES DE FECHA Y HORA
  // ---------------------------------------------------
  Future<void> _seleccionarFechaHora(bool esInicio) async {
    DateTime base = esInicio ? _inicio : _fin;
    
    // 1. Selector de Fecha
    final DateTime? fecha = await showDatePicker(
      context: context, 
      initialDate: base, 
      firstDate: DateTime(2024), 
      lastDate: DateTime(2030)
    );
    if (fecha == null) return;
    
    if (!mounted) return;
    
    // 2. Selector de Hora
    final TimeOfDay? hora = await showTimePicker(
      context: context, 
      initialTime: TimeOfDay.fromDateTime(base)
    );
    if (hora == null) return;
    
    setState(() {
      final dt = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
      if (esInicio) _inicio = dt; else _fin = dt;
    });
  }

  // ---------------------------------------------------
  // LÓGICA: AGREGAR NUEVA ACTIVIDAD (DIALOG)
  // ---------------------------------------------------
  void _mostrarDialogoActividad() {
    final descController = TextEditingController();
    final areaController = TextEditingController();
    final horasController = TextEditingController(text: "01");
    final minutosController = TextEditingController(text: "00");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Agregar Actividad Extra"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descController, decoration: const InputDecoration(labelText: "Descripción")),
            const SizedBox(height: 10),
            TextField(controller: areaController, decoration: const InputDecoration(labelText: "Área")),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: horasController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Horas"))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: minutosController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Min"))),
            ])
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (descController.text.isNotEmpty) {
                // Formato HH:MM:SS
                String duracion = "${horasController.text.padLeft(2,'0')}:${minutosController.text.padLeft(2,'0')}:00";
                
                setState(() {
                  _actividadesNuevas.add({
                    "descripcion": descController.text, 
                    "area": areaController.text,
                    "tiempo_planificado": duracion, 
                    "tiempo_real_acumulado": "00:00:00",
                    "en_progreso": false, 
                    "completada": false
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("AGREGAR")
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // LÓGICA: GUARDAR CAMBIOS (PUT REQUEST)
  // ---------------------------------------------------
  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    
    final url = Uri.parse('$baseUrl/api/ordenes/${widget.orden['id']}/');
    
    // Preparamos el JSON completo
    Map<String, dynamic> datos = {
      'numero_orden': _numeroController.text,
      'ubicacion': _ubicacionController.text,
      'ubicacion_tecnica': _ubicacionTecnicaController.text,
      'proceso': _procesoController.text,
      'codigo_trabajador': _trabajadorController.text,
      'supervisor_nombre': _supervisorController.text,
      'supervisor_codigo': _supervisorCodigoOriginal,
      'prioridad': _prioridad,
      'inicio_programado': _inicio.toIso8601String(),
      'fin_programado': _fin.toIso8601String(),
      // NOTA: Enviamos SOLO las nuevas en una lista separada si el backend lo requiere así, 
      // o usamos una lógica de mezcla. En este caso, el backend de Django (según tu código previo)
      // espera recibir 'actividades' para procesarlas.
      // Aquí enviamos las NUEVAS para que el backend las cree.
      'actividades': _actividadesNuevas 
    };

    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(datos),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Orden Actualizada Correctamente")));
          Navigator.pop(context); // Regresar al Dashboard
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al actualizar: ${response.body}"), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) { 
      print(e);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error de conexión"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editar Orden")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Datos Generales", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              
              // Campos del Formulario
              TextFormField(
                controller: _numeroController, 
                decoration: const InputDecoration(labelText: "N° Orden"), 
                readOnly: true, // No se puede cambiar el número de orden
                style: const TextStyle(color: Colors.grey)
              ),
              const SizedBox(height: 10),
              
              TextFormField(controller: _trabajadorController, decoration: const InputDecoration(labelText: "Cód. Trabajador")),
              const SizedBox(height: 10),
              
              TextFormField(controller: _ubicacionController, decoration: const InputDecoration(labelText: "Ubicación")),
              const SizedBox(height: 10),
              
              // CAMPO PROCESO
              TextFormField(
                controller: _procesoController, 
                decoration: const InputDecoration(labelText: "Proceso"), 
                validator: (v) => v!.isEmpty ? "Requerido" : null
              ),
              const SizedBox(height: 10),
              
              // Selector de Fechas
              Row(children: [
                 Expanded(
                   child: OutlinedButton(
                     onPressed: () => _seleccionarFechaHora(true), 
                     child: Text("Inicio:\n${_inicio.toString().substring(0,16)}")
                   )
                 ),
                 const SizedBox(width: 10),
                 Expanded(
                   child: OutlinedButton(
                     onPressed: () => _seleccionarFechaHora(false), 
                     child: Text("Fin:\n${_fin.toString().substring(0,16)}")
                   )
                 ),
              ]),

              const Divider(height: 30, thickness: 2),
              
              // SECCIÓN: ACTIVIDADES EXISTENTES (Solo Lectura)
              const Text("Actividades Existentes (Bloqueadas)", style: TextStyle(fontWeight: FontWeight.bold)),
              if (_actividadesExistentes.isEmpty) 
                const Text("Sin registros previos", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              
              ..._actividadesExistentes.map((a) => ListTile(
                title: Text(a['descripcion']), 
                subtitle: Text("Estado: ${a['completada'] ? 'Completada' : 'Pendiente'}"),
                leading: const Icon(Icons.lock, size: 16, color: Colors.grey), 
                dense: true
              )),

              const Divider(height: 20),
              
              // SECCIÓN: AGREGAR NUEVAS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                   const Text("Agregar Nuevas Actividades", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                   IconButton(onPressed: _mostrarDialogoActividad, icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 30))
                ]
              ),
              
              // Lista de Actividades Nuevas (Permite Borrar)
              ..._actividadesNuevas.map((a) => Card(
                color: Colors.blue[50], 
                child: ListTile(
                  title: Text(a['descripcion'] + " (NUEVA)"), 
                  leading: const Icon(Icons.star, color: Colors.orange), 
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red), 
                    onPressed: () => setState(() => _actividadesNuevas.remove(a))
                  )
                )
              )),

              const SizedBox(height: 30),
              
              // BOTÓN GUARDAR
              ElevatedButton(
                onPressed: _guardarCambios, 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)), 
                child: const Text("GUARDAR CAMBIOS")
              )
            ]
          ),
        ),
      ),
    );
  }
}
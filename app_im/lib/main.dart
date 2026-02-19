import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ================================
// 1. CONFIGURACIÓN GLOBAL Y LOGIN
// ================================

// Usar esta para el EMULADOR (Desarrollo en PC)
// const String baseUrl = "http://10.0.2.2:8000";

const String baseUrl = "http://10.0.2.2:8000"; 

const Color colorIngenioOrange = Color(0xFFEF7D00);

// VARIABLE GLOBAL PARA EL MODO OSCURO
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // REVISION DE LA MEMORIA ANTES DE ARRANCAR
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  bool esAdmin = prefs.getBool('esAdmin') ?? false;
  String codigo = prefs.getString('codigo') ?? '';
  String nombre = prefs.getString('nombre') ?? '';

  Widget pantallaInicial = const LoginScreen();

  if (isLoggedIn) {
    if (esAdmin) {
      pantallaInicial = AdminDashboard(nombreAdmin: nombre);
    } else {
      pantallaInicial = OrdenesScreen(codigoTrabajador: codigo, nombreTrabajador: nombre);
    }
  }

  runApp(MyApp(pantallaInicial: pantallaInicial));
}

class MyApp extends StatelessWidget {
  final Widget pantallaInicial;
  const MyApp({super.key, required this.pantallaInicial});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Monte Rosa App',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true, brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: colorIngenioOrange, brightness: Brightness.light),
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            appBarTheme: const AppBarTheme(backgroundColor: colorIngenioOrange, foregroundColor: Colors.white),
            inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: colorIngenioOrange, foregroundColor: Colors.white),
          ),
          darkTheme: ThemeData(
            useMaterial3: true, brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: colorIngenioOrange, brightness: Brightness.dark, surface: const Color(0xFF1E1E1E)),
            scaffoldBackgroundColor: const Color(0xFF121212), 
            appBarTheme: AppBarTheme(backgroundColor: Colors.grey[900], foregroundColor: colorIngenioOrange),
            inputDecorationTheme: InputDecorationTheme(border: const OutlineInputBorder(), filled: true, fillColor: Colors.grey[900]),
            elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: colorIngenioOrange, foregroundColor: Colors.white)),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: colorIngenioOrange, foregroundColor: Colors.white),
          ),
          home: pantallaInicial,
        );
      },
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
  final _opPassController = TextEditingController();
  final _adminUserController = TextEditingController();
  final _adminPassController = TextEditingController();

  @override
  void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); }
  @override
  void dispose() { 
    _tabController.dispose(); _opCodigoController.dispose(); 
    _opPassController.dispose(); _adminUserController.dispose(); 
    _adminPassController.dispose(); super.dispose(); 
  }

  // --- FUNCIÓN PARA GUARDAR MEMORIA ---
  Future<void> _guardarSesion(String codigo, String nombre, bool isAdmin) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('esAdmin', isAdmin);
    await prefs.setString('codigo', codigo);
    await prefs.setString('nombre', nombre);
  }

  // --- LOGIN OPERARIO ---
  Future<void> _loginOperario() async {
    FocusScope.of(context).unfocus();
    if (_opCodigoController.text.isEmpty) return;

    setState(() => cargando = true);
    final url = Uri.parse('$baseUrl/api/login-operario/');
    
    try {
      final response = await http.post(
        url, headers: {"Content-Type": "application/json"},
        body: json.encode({
          "codigo": _opCodigoController.text.trim(),
          "password": _opPassController.text.trim() 
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {   
        final data = json.decode(response.body);
        
        // Si no existe usuario pero tiene órdenes, lanza el diálogo de registro
        if (data['requiere_nombre'] == true) {
           if (mounted) _mostrarDialogoPedirNombreYPass(_opCodigoController.text.trim());
           return;
        }

        String codigo = data['usuario']['username'].toString(); 
        String nombre = data['usuario']['first_name'] ?? "";
        String apellido = data['usuario']['last_name'] ?? "";
        String nombreCompleto = "$nombre $apellido".trim();

        await _guardarSesion(codigo, nombreCompleto, false);
        _navegarAOrdenes(codigo, nombreCompleto); 
        
      } else {
        final err = json.decode(response.body);
        _mostrarError("Acceso Denegado", err['error'] ?? "Credenciales incorrectas.");
      }
    } catch (e) {
      _mostrarError("Error de Conexión", e.toString());
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  // --- DIÁLOGO DE REGISTRO PARA NUEVOS OPERARIOS ---
  void _mostrarDialogoPedirNombreYPass(String codigo) {
    final nombreController = TextEditingController();
    final apellidoController = TextEditingController();
    final passConfirmController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("¡Tienes órdenes asignadas!", style: TextStyle(color: colorIngenioOrange)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("Es tu primera vez. Crea tu cuenta para acceder:"),
              const SizedBox(height: 10),
              TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Nombres"), textCapitalization: TextCapitalization.words),
              const SizedBox(height: 10),
              TextField(controller: apellidoController, decoration: const InputDecoration(labelText: "Apellidos"), textCapitalization: TextCapitalization.words),
              const SizedBox(height: 10),
              TextField(controller: passConfirmController, obscureText: true, decoration: const InputDecoration(labelText: "Crea tu Contraseña")),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.trim().length >= 2 && passConfirmController.text.isNotEmpty) {
                Navigator.pop(ctx);
                await _actualizarNombreYPass(codigo, nombreController.text.trim(), apellidoController.text.trim(), passConfirmController.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Completa todos los campos")));
              }
            },
            child: const Text("CREAR CUENTA E INGRESAR")
          )
        ],
      ),
    );
  }

  Future<void> _actualizarNombreYPass(String codigo, String nombre, String apellido, String password) async {
    setState(() => cargando = true);
    final url = Uri.parse('$baseUrl/api/login-operario/');
    try {
      await http.post(
        url, headers: {"Content-Type": "application/json"}, 
        body: json.encode({
          "codigo": codigo, 
          "nombre": nombre, 
          "apellido": apellido,
          "password_nueva": password
        })
      );
      String nombreCompleto = "$nombre $apellido".trim();
      await _guardarSesion(codigo, nombreCompleto, false);
      _navegarAOrdenes(codigo, nombreCompleto);
    } catch (e) { print(e); } finally { setState(() => cargando = false); }
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
        url, headers: {"Content-Type": "application/json"},
        body: json.encode({"username": _adminUserController.text.trim(), "password": _adminPassController.text.trim()}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String nombreAdmin = data['usuario']['first_name'] ?? "Admin";
        String adminUser = data['usuario']['username'] ?? "admin";
        
        await _guardarSesion(adminUser, nombreAdmin, true);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AdminDashboard(nombreAdmin: nombreAdmin)));
      } else { _mostrarError("Error", "Credenciales incorrectas."); }
    } catch (e) {_mostrarError("Error", e.toString());} finally {if(mounted) setState(()=>cargando=false);}
  }
  
  void _mostrarError(String t, String m) { showDialog(context: context, builder: (ctx)=>AlertDialog(title:Text(t), content:Text(m), actions:[TextButton(onPressed: ()=>Navigator.pop(ctx), child:const Text("OK"))])); }

  @override
  Widget build(BuildContext context) {
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      floatingActionButton: FloatingActionButton(mini: true, backgroundColor: esOscuro ? Colors.yellow : colorIngenioOrange, child: Icon(esOscuro ? Icons.light_mode : Icons.dark_mode, color: esOscuro ? Colors.black : Colors.white), onPressed: () { themeNotifier.value = esOscuro ? ThemeMode.light : ThemeMode.dark; }),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: SafeArea(
        child: Center( 
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(height: 120, width: 120, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: esOscuro ? Colors.transparent : Colors.white, borderRadius: BorderRadius.circular(20)), child: Image.asset('assets/logo.png', fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) { return const Icon(Icons.factory, size: 60, color: colorIngenioOrange); })),
                const SizedBox(height: 20),
                const Text("Ingenio Monte Rosa", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorIngenioOrange)),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20), 
                  child: Container(decoration: BoxDecoration(color: esOscuro ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(25)), child: TabBar(controller: _tabController, indicatorSize: TabBarIndicatorSize.tab, indicator: BoxDecoration(color: colorIngenioOrange, borderRadius: BorderRadius.circular(25)), labelColor: Colors.white, unselectedLabelColor: Colors.grey, dividerColor: Colors.transparent, tabs: const [Tab(text: "Operario"), Tab(text: "Admin")]))
                ),
                SizedBox(
                  height: 380,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB OPERARIO
                      Padding(padding: const EdgeInsets.all(24), child: Column(children: [
                        const SizedBox(height: 10), 
                        TextField(controller: _opCodigoController, decoration: const InputDecoration(labelText: "Código de Trabajador", prefixIcon: Icon(Icons.badge, color: colorIngenioOrange)), keyboardType: TextInputType.number), 
                        const SizedBox(height: 15), 
                        TextField(controller: _opPassController, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock, color: colorIngenioOrange))), // NUEVO CAMPO
                        const SizedBox(height: 30), 
                        if (cargando) const CircularProgressIndicator(color: colorIngenioOrange) else ElevatedButton(onPressed: _loginOperario, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text("INGRESAR"))
                      ])),
                      
                      // TAB ADMIN
                      Padding(padding: const EdgeInsets.all(24), child: Column(children: [
                        const SizedBox(height: 10), 
                        TextField(controller: _adminUserController, decoration: const InputDecoration(labelText: "Usuario", prefixIcon: Icon(Icons.admin_panel_settings, color: colorIngenioOrange))), 
                        const SizedBox(height: 15), 
                        TextField(controller: _adminPassController, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock, color: colorIngenioOrange))), 
                        const SizedBox(height: 30), 
                        if (cargando) const CircularProgressIndicator(color: colorIngenioOrange) else ElevatedButton(onPressed: _loginAdmin, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white), child: const Text("ACCESO ADMIN"))
                      ])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ==========================
// 2. PANEL DE ADMINISTRADOR 
// ==========================

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
  void initState() { super.initState(); fetchTodasLasOrdenes(); }

  Future<void> fetchTodasLasOrdenes() async {
    final url = Uri.parse('$baseUrl/api/ordenes/');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        List<dynamic> todas = json.decode(response.body);
        if (mounted) {
          setState(() {
            pendientes = todas.where((o) => o['estado'] == 'PENDIENTE').toList();
            completadas = todas.where((o) => o['estado'] == 'FINALIZADA').toList();
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
    showDialog(context: context, builder: (ctx) {
        bool esOscuro = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(backgroundColor: esOscuro ? Colors.grey[900] : Colors.white, title: Text(titulo, style: const TextStyle(color: Colors.red)), content: Text(mensaje, style: TextStyle(color: esOscuro ? Colors.white : Colors.black)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: esOscuro ? Colors.grey[900] : colorIngenioOrange, foregroundColor: esOscuro ? colorIngenioOrange : Colors.white,
          title: Row(
  children: [
    Container(
      height: 35, 
      width: 35, 
      padding: const EdgeInsets.all(2), 
      decoration: BoxDecoration(
        color: esOscuro ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Image.asset(
        'assets/logo.png', 
        fit: BoxFit.contain, 
        errorBuilder: (c,e,s) => const Icon(Icons.factory, size: 25, color: Color(0xFFEF7D00))
      )
    ), 
    const SizedBox(width: 10), 
    Expanded(
      child: Text(
        widget.nombreAdmin, 
        style: TextStyle(fontSize: 18, color: esOscuro ? const Color(0xFFEF7D00) : Colors.white), 
        overflow: TextOverflow.ellipsis
      )
    )
  ]
),
          bottom: TabBar(labelColor: esOscuro ? colorIngenioOrange : Colors.white, unselectedLabelColor: esOscuro ? Colors.grey : Colors.white70, indicatorColor: esOscuro ? colorIngenioOrange : Colors.white, tabs: const [Tab(text: "PENDIENTES"), Tab(text: "HISTORIAL")]),
          actions: [
  IconButton(
    icon: const Icon(Icons.exit_to_app), 
    tooltip: "Cerrar Sesión",
    onPressed: () async {
      // Borramos la sesión de la memoria del celular
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear(); 
      
      // Lo mandamos al Login sin posibilidad de regresar
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => const LoginScreen()), 
          (route) => false
        );
      }
    }
  )
],
          ),
        body: cargando ? const Center(child: CircularProgressIndicator(color: colorIngenioOrange)) : TabBarView(children: [_listaAdmin(pendientes, esHistorial: false), _listaAdmin(completadas, esHistorial: true)]),
        
        floatingActionButton: FloatingActionButton(
          backgroundColor: colorIngenioOrange, 
          child: const Icon(Icons.cloud_upload, color: Colors.white), 
          tooltip: "Importar SAP (Web)",
          onPressed: () async { 
             final Uri adminUrl = Uri.parse('$baseUrl/admin/');
             if (!await launchUrl(adminUrl, mode: LaunchMode.externalApplication)) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir el navegador.")));
             }
          },
        ),
      ),
    );
  }

  Widget _listaAdmin(List<dynamic> lista, {required bool esHistorial}) {
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    if (lista.isEmpty) { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.folder_open, size: 50, color: esOscuro ? Colors.grey[700] : Colors.grey[300]), Text(esHistorial ? "No hay historial" : "Todo al día", style: const TextStyle(color: Colors.grey))])); }
    return ListView.builder(
      padding: const EdgeInsets.all(10), itemCount: lista.length,
      itemBuilder: (context, index) {
        final orden = lista[index];
        String letraAvatar = "?";
        if (orden['prioridad'] != null && orden['prioridad'].toString().isNotEmpty) { letraAvatar = orden['prioridad']; }
        Color colorAvatar = _colorPrioridad(orden['prioridad']);
        return Card(
          color: esOscuro ? Colors.grey[850] : Colors.white, elevation: 3, margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: colorAvatar, child: Text(letraAvatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            title: Text("Orden #${orden['numero_orden']}", style: TextStyle(fontWeight: FontWeight.bold, color: esOscuro ? Colors.white : Colors.black)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("${orden['descripcion']}", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.black87, fontWeight: FontWeight.bold)),
                Text("Asignado a: ${orden['codigo_trabajador'] ?? 'Sin asignar'}", style: TextStyle(color: esOscuro ? Colors.grey : Colors.black87)),
                Text("Ubicación: ${orden['ubicacion'] ?? 'N/A'}", style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.grey[600])),
            ]),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => DetalleOrdenScreen(orden: orden, nombreTrabajador: "ADMIN"))).then((_) => fetchTodasLasOrdenes()); },
          ),
        );
      },
    );
  }

  Color _colorPrioridad(String? p) {
    if (p == '1') return Colors.red; if (p == '2') return Colors.orange; if (p == '3') return Colors.amber; if (p == '4') return Colors.green; return Colors.grey; 
  }
}
// =========================
// 3. PANTALLA CREAR ORDEN
// =========================
class CrearOrdenScreen extends StatelessWidget {
  const CrearOrdenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Nueva Orden", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.white)),
        backgroundColor: esOscuro ? Colors.grey[900] : colorIngenioOrange,
        iconTheme: IconThemeData(color: esOscuro ? colorIngenioOrange : Colors.white),
        actions: [
      IconButton(
        icon: const Icon(Icons.exit_to_app, color: Colors.white),
        tooltip: "Cerrar Sesión",
        onPressed: () async {
          // Vaciamos la memoria para que la App lo olvide
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          
          // Lo regresamos a la pantalla principal de Login
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context, 
              MaterialPageRoute(builder: (_) => const LoginScreen()), 
              (route) => false 
            );
          }
        }
      )
    ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sync_disabled, size: 80, color: esOscuro ? Colors.grey[700] : Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                "Creación Manual Deshabilitada",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: esOscuro ? colorIngenioOrange : Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                "Para mantener la integridad de los datos, la creación de nuevas órdenes de trabajo ahora se realiza exclusivamente mediante la importación de archivos de SAP en el panel web administrativo.",
                style: TextStyle(fontSize: 16, color: esOscuro ? Colors.grey[400] : Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text("VOLVER"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorIngenioOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 50),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
// ========================
// 4. PANTALLA MIS ÓRDENES 
// ========================
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
    final url = Uri.parse('$baseUrl/api/ordenes/?trabajador=${widget.codigoTrabajador}');
    
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        List<dynamic> todas = json.decode(response.body);
        
        // Filtro de seguridad en el cliente para el operario logueado
        List<dynamic> soloMias = todas.where((o) {
          String assignedWorker = (o['codigo_trabajador'] ?? "").toString().trim();
          String myCode = widget.codigoTrabajador.trim();
          return assignedWorker == myCode;
        }).toList();

        if (mounted) {
          setState(() {
            _pendientes = soloMias.where((o) => o['estado'] == 'PENDIENTE').toList();
            _historial = soloMias.where((o) => o['estado'] == 'FINALIZADA').toList();

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
    showDialog(context: context, builder: (ctx) {
      bool esOscuro = Theme.of(context).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: esOscuro ? Colors.grey[900] : Colors.white,
        title: Text(titulo, style: const TextStyle(color: Colors.red)), 
        content: Text(mensaje, style: TextStyle(color: esOscuro ? Colors.white : Colors.black)), 
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: esOscuro ? Colors.grey[900] : colorIngenioOrange,
          iconTheme: IconThemeData(color: esOscuro ? colorIngenioOrange : Colors.white),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Mis Asignaciones", style: TextStyle(fontSize: 16, color: esOscuro ? colorIngenioOrange : Colors.white)),
              Text(
                "${widget.nombreTrabajador} (${widget.codigoTrabajador})", 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: esOscuro ? Colors.grey : Colors.white70)
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: "Cerrar Sesión",
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))
            )
          ],
          bottom: TabBar(
            labelColor: esOscuro ? colorIngenioOrange : Colors.white, 
            unselectedLabelColor: esOscuro ? Colors.grey : Colors.white70, 
            indicatorColor: esOscuro ? colorIngenioOrange : Colors.white, 
            tabs: const [
              Tab(icon: Icon(Icons.work_history), text: "PENDIENTES"),
              Tab(icon: Icon(Icons.check_circle), text: "HISTORIAL"),
            ],
          ),
        ),
        body: cargando 
          ? const Center(child: CircularProgressIndicator(color: colorIngenioOrange)) 
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
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(esHistorial ? Icons.history : Icons.assignment_turned_in, size: 50, color: esOscuro ? Colors.grey[700] : Colors.grey[300]),
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
      color: colorIngenioOrange,
      onRefresh: fetchOrdenes,
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final orden = lista[index];
          
          String letraAvatar = "?";
          if (orden['prioridad'] != null && orden['prioridad'].toString().isNotEmpty) {
             letraAvatar = orden['prioridad']; // Lee el 1, 2, 3 o 4
          }
          
          Color colorAvatar = Colors.grey;
          if (orden['prioridad'] == '1') colorAvatar = Colors.red;
          if (orden['prioridad'] == '2') colorAvatar = Colors.orange;
          if (orden['prioridad'] == '3') colorAvatar = Colors.amber;
          if (orden['prioridad'] == '4') colorAvatar = Colors.green;
          
          Color colorFinal = esHistorial ? Colors.green : colorAvatar;

          return Card(
            color: esOscuro ? Colors.grey[850] : Colors.white,
            elevation: 2, 
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colorFinal,
                child: esHistorial 
                    ? const Icon(Icons.check, color: Colors.white) 
                    : Text(letraAvatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text("Orden #${orden['numero_orden']}", style: TextStyle(fontWeight: FontWeight.bold, color: esOscuro ? Colors.white : Colors.black)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(orden['descripcion'] ?? "Sin descripción", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.black87, fontWeight: FontWeight.bold)),
                  Text(orden['ubicacion'] ?? "Sin ubicación", style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.black54)),
              ]),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: esOscuro ? colorIngenioOrange : Colors.grey),
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
// ====================
// 5. DETALLE DE ORDEN
// ====================
class DetalleOrdenScreen extends StatefulWidget {
  final Map<String, dynamic> orden;
  final String nombreTrabajador;

  const DetalleOrdenScreen({super.key, required this.orden, required this.nombreTrabajador});

  @override
  State<DetalleOrdenScreen> createState() => _DetalleOrdenScreenState();
}

class _DetalleOrdenScreenState extends State<DetalleOrdenScreen> {
  late Map<String, dynamic> ordenActual;
  bool _enviando = false;

  @override
  void initState() { super.initState(); ordenActual = widget.orden; _recargarOrden(); }

  Future<void> _recargarOrden() async {
    final url = Uri.parse('$baseUrl/api/ordenes/${widget.orden['id']}/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) { if (mounted) setState(() => ordenActual = json.decode(response.body)); }
    } catch (e) { /* */ }
  }

  // --- VISOR DE IMÁGENES A PANTALLA COMPLETA ---
  void _mostrarImagenCompleta(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 0, right: 0,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.white, size: 35),
                onPressed: () => Navigator.pop(ctx),
              ),
            )
          ],
        ),
      )
    );
  }

  Future<void> _finalizarOrdenCompleta() async {
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    bool? confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: esOscuro ? Colors.grey[900] : Colors.white,
        title: Text("¿Finalizar Orden?", style: TextStyle(color: esOscuro ? const Color(0xFFEF7D00) : Colors.black)),
        content: Text("La orden pasará al historial inmediatamente.", style: TextStyle(color: esOscuro ? Colors.white : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))), 
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("SÍ, FINALIZAR", style: TextStyle(color: Colors.red)))
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Orden cerrada con éxito!"), backgroundColor: Colors.green)); 
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
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    showDialog(context: context, builder: (ctx)=>AlertDialog(backgroundColor: esOscuro ? Colors.grey[900] : Colors.white, title:Text(t, style:const TextStyle(color:Colors.red)), content:Text(m, style: TextStyle(color: esOscuro ? Colors.white : Colors.black)), actions:[TextButton(onPressed:()=>Navigator.pop(ctx), child:const Text("OK"))]));
  }

  String _calcularTiempoPausas(List<dynamic> bitacora) {
    if (bitacora.isEmpty) return "00:00:00";
    Duration tiempoPausadoTotal = Duration.zero; DateTime? inicioPausa; List<dynamic> eventos = List.from(bitacora);
    eventos.sort((a, b) => (a['fecha_hora'] ?? "").compareTo(b['fecha_hora'] ?? ""));
    for (var evento in eventos) {
      String tipo = evento['evento'].toString().toUpperCase(); 
      DateTime fecha = DateTime.parse(evento['fecha_hora']);
      if (tipo == 'PAUSA') { inicioPausa = fecha; } 
      else if ((tipo == 'REANUDAR' || tipo == 'FINAL') && inicioPausa != null) { 
        tiempoPausadoTotal += fecha.difference(inicioPausa); 
        inicioPausa = null; 
      }
    }
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(tiempoPausadoTotal.inHours)}:${twoDigits(tiempoPausadoTotal.inMinutes.remainder(60))}:${twoDigits(tiempoPausadoTotal.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    List<dynamic> todas = ordenActual['actividades'] ?? [];
    
    List<dynamic> evidenciasGlobales = [];
    for (var act in todas) {
      if (act['evidencias'] != null) evidenciasGlobales.addAll(act['evidencias']);
    }

    List<dynamic> pendientes = todas.where((a) => a['finished'] != true).toList();
    List<dynamic> terminadas = todas.where((a) => a['finished'] == true).toList();
    
    bool ordenCerrada = ordenActual['estado'] == 'FINALIZADA';
    bool esAdmin = widget.nombreTrabajador == "ADMIN";

    return Scaffold(
      appBar: AppBar(title: Text("Orden #${ordenActual['numero_orden']}", style: TextStyle(color: esOscuro ? const Color(0xFFEF7D00) : Colors.white)), backgroundColor: esOscuro ? Colors.grey[900] : const Color(0xFFEF7D00), iconTheme: IconThemeData(color: esOscuro ? const Color(0xFFEF7D00) : Colors.white)),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: esOscuro ? Colors.grey[850] : Colors.white, width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow("Descripción:", ordenActual['descripcion'], esOscuro), const SizedBox(height: 5),
                _infoRow("Equipo:", "${ordenActual['equipo'] ?? ''} - ${ordenActual['descripcion_equipo'] ?? ''}", esOscuro), const SizedBox(height: 5),
                _infoRow("Ubicación:", ordenActual['ubicacion'], esOscuro), const SizedBox(height: 10),
                if (ordenCerrada) const Chip(label: Text("FINALIZADA", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green)
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                
                if (evidenciasGlobales.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8), 
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [
                        Row(children: const [
                          Icon(Icons.camera_alt, color: Color(0xFFEF7D00), size: 20), 
                          SizedBox(width: 8), 
                          Text("TODAS LAS EVIDENCIAS", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF7D00)))
                        ]), 
                        Text("${evidenciasGlobales.length} fotos", style: const TextStyle(color: Colors.grey, fontSize: 12))
                      ]
                    )
                  ),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: evidenciasGlobales.length,
                      itemBuilder: (context, index) {
                        String urlFoto = evidenciasGlobales[index]['foto'] ?? "";
                        String tipoFoto = evidenciasGlobales[index]['tipo'] ?? "FOTO";
                        if (urlFoto.startsWith('/')) urlFoto = '$baseUrl$urlFoto';
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => _mostrarImagenCompleta(context, urlFoto),
                            child: Column(
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(urlFoto, width: 75, height: 75, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 75, height: 75, color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white)))),
                                const SizedBox(height: 4),
                                Text(tipoFoto, style: TextStyle(fontSize: 10, color: esOscuro ? Colors.grey[400] : Colors.black54, fontWeight: FontWeight.bold))
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 30),
                ],

                if (pendientes.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8), 
                    child: Row(
                      children: const [
                        Icon(Icons.push_pin, color: Color(0xFFEF7D00), size: 20), 
                        SizedBox(width: 8), 
                        Text("OPERACIONES PENDIENTES", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF7D00)))
                      ]
                    )
                  ),
                  ...pendientes.map((act) => _cardActividad(act, false, esOscuro, esAdmin)),
                ],

                if (terminadas.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8), 
                    child: Text("✅ OPERACIONES REALIZADAS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
                  ),
                  ...terminadas.map((act) => _cardActividad(act, true, esOscuro, esAdmin)),
                ],
                if (pendientes.isEmpty && terminadas.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("No hay operaciones registradas", style: TextStyle(color: esOscuro ? Colors.grey : Colors.grey[600])))),
              ],
            ),
          ),
          
          if (!ordenCerrada && pendientes.isEmpty && todas.isNotEmpty && !esAdmin)
            Padding(
              padding: const EdgeInsets.all(16), 
              child: _enviando 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFEF7D00))) 
                : ElevatedButton.icon(
                    onPressed: _finalizarOrdenCompleta, 
                    icon: const Icon(Icons.archive), 
                    label: const Text("FINALIZAR ORDEN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: const Color(0xFFEF7D00), foregroundColor: Colors.white)
                  )
            )
        ],
      ),
    );
  }

  Widget _infoRow(String label, String? value, bool esOscuro) {
    return RichText(text: TextSpan(style: TextStyle(fontSize: 15, color: esOscuro ? Colors.grey[300] : Colors.black87), children: [TextSpan(text: "$label ", style: TextStyle(fontWeight: FontWeight.bold, color: esOscuro ? const Color(0xFFEF7D00) : Colors.black)), TextSpan(text: value ?? "N/D")]));
  }

  Widget _cardActividad(dynamic act, bool completada, bool esOscuro, bool esAdmin) {
    List<dynamic> bitacora = act['bitacora'] ?? []; 
    String tiempoPausas = completada ? _calcularTiempoPausas(bitacora) : "00:00:00";
    Color? colorFondo = completada ? (esOscuro ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50]) : (esOscuro ? Colors.grey[800] : Colors.white);

    String tituloOperacion = act['descripcion'] ?? act['codigo_operacion'] ?? "Operación de SAP";

    return Card(
      elevation: 2, margin: const EdgeInsets.only(bottom: 8), color: colorFondo,
      child: ListTile(
        title: Text(tituloOperacion, style: TextStyle(decoration: completada ? TextDecoration.lineThrough : null, color: esOscuro ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        subtitle: completada ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Ejecutor: ${act['nombre_ejecutor'] ?? 'Desconocido'}", style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.grey[800])), Text("Tiempo Activo: ${act['tiempo_real_acumulado']}", style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.grey[800])), Text("Tiempo Pausas: $tiempoPausas", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))]) : Text("Cód: ${act['codigo_operacion'] ?? 'N/A'}", style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.grey[600])),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
             backgroundColor: esAdmin ? Colors.blueGrey : const Color(0xFFEF7D00), 
             foregroundColor: Colors.white,
          ), 
          child: Text(esAdmin ? "VER" : "ABRIR"), 
          onPressed: () { 
             // Enlaza la pantalla de la Actividad
             Navigator.push(context, MaterialPageRoute(builder: (context) => EjecucionActividadScreen(actividad: act, nombreTrabajador: widget.nombreTrabajador, esAdmin: esAdmin))).then((_) => _recargarOrden()); 
          }
        ),
      ),
    );
  }
}
// =========================
// 6. PANTALLA DE EJECUCIÓN
// =========================

class EjecucionActividadScreen extends StatefulWidget {
  final Map<String, dynamic> actividad;
  final String nombreTrabajador; 
  final bool esAdmin;

  const EjecucionActividadScreen({
    super.key, 
    required this.actividad,
    required this.nombreTrabajador,
    this.esAdmin = false,
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
  bool _enviandoFoto = false;
  bool _procesandoCierre = false; 
  
  String? _horaInicioReal; 
  
  List<dynamic> _historialBitacora = [];
  final _notasController = TextEditingController();
  final _nombreManualController = TextEditingController(); 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    actividadData = widget.actividad;
    _procesarDatosIniciales();
  }

  // --- VISOR DE IMÁGENES A PANTALLA COMPLETA ---
  void _mostrarImagenCompleta(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 0, right: 0,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.white, size: 35),
                onPressed: () => Navigator.pop(ctx),
              ),
            )
          ],
        ),
      )
    );
  }

  Future<void> _recargarActividad() async {
    final url = Uri.parse('$baseUrl/api/actividades/${actividadData['id']}/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) { 
         if (mounted) setState(() { actividadData = json.decode(response.body); _procesarDatosIniciales(); });
      }
    } catch (e) { /* */ }
  }

  void _procesarDatosIniciales() {
    if (actividadData['bitacora'] != null) {
      _historialBitacora = List.from(actividadData['bitacora']);
      _historialBitacora.sort((a, b) => (a['fecha_hora']??"").compareTo(b['fecha_hora']??""));
      
      // Rescatamos la hora de inicio si ya había arrancado antes
      if (_historialBitacora.isNotEmpty && _horaInicioReal == null) {
         _horaInicioReal = _historialBitacora.first['fecha_hora'];
      }
    }
    
    // También rescatamos de los datos de Django si los trae
    if (actividadData['fecha_inicio_real'] != null) {
      _horaInicioReal = actividadData['fecha_inicio_real'];
    }

    _sincronizarEstadoInicial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { _sincronizarEstadoInicial(); }
  }

  void _sincronizarEstadoInicial() {
    _timer?.cancel(); 
    if (actividadData['tiempo_real_acumulado'] != null) {
      try {
        List<String> parts = actividadData['tiempo_real_acumulado'].split(':');
        _tiempoAcumulado = Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]), seconds: double.parse(parts[2]).toInt());
      } catch (e) { /* */ }
    }
    _enProgreso = actividadData['en_progreso'] ?? false;
    _finalizado = actividadData['finished'] ?? false;

    if (_enProgreso && !_finalizado && _historialBitacora.isNotEmpty) {
      try {
        var ultimoEvento = _historialBitacora.last;
        if (ultimoEvento['fecha_hora'] != null) {
          DateTime fechaUltimoEvento = DateTime.parse(ultimoEvento['fecha_hora']);
          DateTime ahora = DateTime.now();
          Duration tiempoTranscurridoOffline = ahora.difference(fechaUltimoEvento);
          if (!tiempoTranscurridoOffline.isNegative) { _tiempoAcumulado += tiempoTranscurridoOffline; }
        }
      } catch (e) { /* */ }
    }
    if (_enProgreso && !_finalizado && !widget.esAdmin) _iniciarTimerVisual();
  }

  void _iniciarTimerVisual() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) { setState(() => _tiempoAcumulado += const Duration(seconds: 1)); }
    });
  }

  // --- NUEVA FUNCIÓN: CALCULADORA DE TIEMPO EN PAUSA ---
  String _calcularTiempoPausas() {
    if (_historialBitacora.isEmpty) return "00:00:00";
    Duration pausas = Duration.zero;
    DateTime? inicioPausa;
    List<dynamic> eventos = List.from(_historialBitacora);
    eventos.sort((a, b) => (a['fecha_hora'] ?? "").compareTo(b['fecha_hora'] ?? ""));

    for (var ev in eventos) {
      String tipo = ev['evento'].toString().toUpperCase();
      if (ev['fecha_hora'] == null) continue;
      DateTime fecha = DateTime.parse(ev['fecha_hora']);

      if (tipo == 'PAUSA') {
        inicioPausa = fecha;
      } else if ((tipo == 'REANUDAR' || tipo == 'FINAL') && inicioPausa != null) {
        pausas += fecha.difference(inicioPausa);
        inicioPausa = null;
      }
    }
    // Si la operación estaba pausada cuando le dio a Finalizar
    if (inicioPausa != null) pausas += DateTime.now().difference(inicioPausa);

    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(pausas.inHours)}:${twoDigits(pausas.inMinutes.remainder(60))}:${twoDigits(pausas.inSeconds.remainder(60))}";
  }

  Future<void> _tomarYSubirFoto(String tipo, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: source, 
      imageQuality: 85,
      maxWidth: 1200, 
    );
    
    if (photo == null) return;

    // Validación de integridad del archivo
    final bytes = await photo.readAsBytes();
    if (bytes.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error: Archivo de imagen vacío. Reintenta.")),
      );
      return;
    }

    setState(() => _enviandoFoto = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/evidencias/'));
      request.fields['actividad'] = actividadData['id'].toString(); 
      if (actividadData['orden'] != null) request.fields['orden'] = actividadData['orden'].toString();
      request.fields['tipo'] = tipo; 
      request.fields['descripcion'] = "Subido por ${widget.nombreTrabajador}";
      request.files.add(await http.MultipartFile.fromPath('foto', photo.path));

      var response = await request.send();
      if (response.statusCode == 201) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Evidencia guardada"), backgroundColor: Colors.green)
        );
        _recargarActividad(); 
      }
    } catch (e) { 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error de conexión: $e"), backgroundColor: Colors.red)
        );
    } finally { 
        if (mounted) setState(() => _enviandoFoto = false); 
    }
  }

  void _mostrarOpcionesImagen(String tipo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFEF7D00)),
                title: const Text('Tomar Foto con Cámara'),
                onTap: () {
                  Navigator.pop(context);
                  _tomarYSubirFoto(tipo, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFEF7D00)),
                title: const Text('Seleccionar de Galería'),
                onTap: () {
                  Navigator.pop(context);
                  _tomarYSubirFoto(tipo, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _registrarEventoBitacora(String tipoEvento) async {
    final url = Uri.parse('$baseUrl/api/bitacora/');
    try {
      final response = await http.post(url, headers: {"Content-Type": "application/json"}, body: json.encode({'actividad': actividadData['id'], 'evento': tipoEvento}));
      if (response.statusCode == 201) { setState(() { _historialBitacora.add(json.decode(response.body)); }); }
    } catch (e) { print(e); }
  }

  Future<void> _actualizarActividadEnDjango(bool arrancando) async {
    String tiempoStr = _tiempoAcumulado.toString().split('.').first.padLeft(8, "0");
    Map<String, dynamic> datos = {'en_progreso': arrancando, 'tiempo_real_acumulado': tiempoStr};

    if (arrancando && _horaInicioReal == null) {
      String nombreFinal = widget.nombreTrabajador;
      if (nombreFinal == "null" || nombreFinal.trim().isEmpty) { nombreFinal = _nombreManualController.text; }
      datos['nombre_ejecutor'] = nombreFinal;
      
      // Guardamos la hora de inicio
      String ahora = DateTime.now().toIso8601String();
      datos['fecha_inicio_real'] = ahora;
      _horaInicioReal = ahora;
    }

    final url = Uri.parse('$baseUrl/api/actividades/${actividadData['id']}/');
    try { 
      await http.patch(url, headers: {"Content-Type": "application/json"}, body: json.encode(datos)); 
      actividadData['en_progreso'] = arrancando;
      actividadData['tiempo_real_acumulado'] = tiempoStr; 
    } catch (e) { print(e); }

    setState(() { _enProgreso = arrancando; if (arrancando) _iniciarTimerVisual(); else _timer?.cancel(); });
  }

  Future<void> _finalizarTareaEnDjango() async {
    _timer?.cancel();
    setState(() => _procesandoCierre = true);

    String tiempoActivoStr = _tiempoAcumulado.toString().split('.').first.padLeft(8, "0");
    String tiempoPausadoStr = _calcularTiempoPausas();
    String fechaFinReal = DateTime.now().toIso8601String();
  
    String fechaInicioReal = _horaInicioReal ?? DateTime.now().toIso8601String();

    Map<String, dynamic> datos = {
      "fecha_inicio_real": fechaInicioReal,
      "fecha_fin_real": fechaFinReal,
      "tiempo_total": tiempoActivoStr,
      "tiempo_pausas": tiempoPausadoStr,
      "nombre_ejecutor": widget.nombreTrabajador,
    };
    
    if (_notasController.text.isNotEmpty) {
      datos['notas_operario'] = _notasController.text;
    }

    final url = Uri.parse('$baseUrl/api/actividades/${actividadData['id']}/finalizar/');
    
    try { 
      final response = await http.post(url, headers: {"Content-Type": "application/json"}, body: json.encode(datos));
      
      if (response.statusCode == 200 || response.statusCode == 204) {
         setState(() { _finalizado = true; _enProgreso = false; _procesandoCierre = false; });
         if (mounted) Navigator.pop(context); 
      } else {
         setState(() => _procesandoCierre = false);
         if (mounted) {
            showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text("Error Backend Django", style: TextStyle(color: Colors.red)),
                content: Text("El servidor no guardó los datos.\n\nCódigo: ${response.statusCode}\nRespuesta:\n${response.body}"),
                actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("ENTENDIDO"))]
              )
            );
         }
      }
    } catch (e) { 
      setState(() => _procesandoCierre = false);
      if (mounted) {
         showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Error de Conexión", style: TextStyle(color: Colors.red)), content: Text(e.toString()), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]));
      }
    }
  }

  Future<void> _botonIniciar() async {
    bool nombreInvalido = widget.nombreTrabajador == "null" || widget.nombreTrabajador.trim().isEmpty;
    bool faltaNombreManual = _nombreManualController.text.isEmpty;

    if (nombreInvalido && faltaNombreManual && actividadData['nombre_ejecutor'] == null) {
      bool esOscuro = Theme.of(context).brightness == Brightness.dark;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: esOscuro ? Colors.grey[900] : Colors.white,
          title: Text("Falta Identificación", style: TextStyle(color: esOscuro ? const Color(0xFFEF7D00) : Colors.black)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
             Text("Ingresa tu nombre para iniciar:", style: TextStyle(color: esOscuro ? Colors.white : Colors.black)),
             const SizedBox(height: 10),
             TextField(controller: _nombreManualController, decoration: const InputDecoration(labelText: "Tu Nombre"), style: TextStyle(color: esOscuro ? Colors.white : Colors.black))
          ]),
          actions: [ElevatedButton(onPressed: () { Navigator.pop(ctx); if (_nombreManualController.text.isNotEmpty) _botonIniciar(); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF7D00), foregroundColor: Colors.white), child: const Text("INICIAR"))]
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
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    String reloj = _tiempoAcumulado.toString().split('.').first.padLeft(8, "0");
    List<dynamic> evidencias = actividadData['evidencias'] ?? [];
    bool haIniciadoAlgunaVez = _historialBitacora.isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
           'assets/logo.png',
           height: 40, 
           errorBuilder: (c, e, s) => const Text("Detalle de Operación", style: TextStyle(color: Colors.white))
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: esOscuro ? Colors.grey[850] : Colors.white, 
            width: double.infinity,
            child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(actividadData['descripcion'] ?? "Operación sin título", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: esOscuro ? Colors.white : Colors.black87)),
                ),
                const SizedBox(height: 10),
                Text(reloj, style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: widget.esAdmin ? Colors.grey : const Color(0xFFEF7D00), fontFamily: 'monospace')),
                const SizedBox(height: 5),
                if (_finalizado) const Text("✅ FINALIZADA", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                else if (_enProgreso) const Text("🔥 EN EJECUCIÓN...", style: TextStyle(color: Color(0xFFEF7D00), fontWeight: FontWeight.bold))
                else if (widget.esAdmin) const Text("OJO: MODO LECTURA ADMIN", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))
            ]),
          ),
          
          Expanded(
            child: Container(
              color: esOscuro ? Colors.black : Colors.grey[100],
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: esOscuro ? Colors.grey[900] : Colors.white,
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Evidencias", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF7D00))),
                        const SizedBox(height: 10),
                        
                        if (evidencias.isNotEmpty)
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: evidencias.length,
                              itemBuilder: (context, index) {
                                String urlFoto = evidencias[index]['foto'] ?? "";
                                String tipoFoto = evidencias[index]['tipo'] ?? "FOTO";
                                if (urlFoto.startsWith('/')) urlFoto = '$baseUrl$urlFoto';
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: GestureDetector(
                                    onTap: () => _mostrarImagenCompleta(context, urlFoto), 
                                    child: Column(
                                      children: [
                                        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(urlFoto, width: 75, height: 75, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 75, height: 75, color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white)))),
                                        const SizedBox(height: 4),
                                        Text(tipoFoto, style: TextStyle(fontSize: 10, color: esOscuro ? Colors.grey[400] : Colors.black54, fontWeight: FontWeight.bold))
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                           Padding(padding: const EdgeInsets.all(8.0), child: Text("Sin fotos en esta operación.", style: TextStyle(color: esOscuro ? Colors.grey : Colors.grey[600], fontStyle: FontStyle.italic))),
                        
                        if (!widget.esAdmin && !_finalizado) ...[
                           const SizedBox(height: 10),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                             children: [_botonFoto("ANTES", Icons.image_search, esOscuro), _botonFoto("DURANTE", Icons.build, esOscuro), _botonFoto("DESPUES", Icons.check_circle_outline, esOscuro)]
                           ),
                        ]
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: ListView.separated(
                      itemCount: _historialBitacora.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: esOscuro ? Colors.grey[800] : Colors.grey[300]),
                      itemBuilder: (context, index) {
                         final ev = _historialBitacora[_historialBitacora.length - 1 - index];
                         String hora = "--:--";
                         if (ev['fecha_hora'] != null) { try { hora = ev['fecha_hora'].toString().split('T')[1].substring(0, 8); } catch(e){/* */} }
                         return ListTile(
                           dense: true,
                           leading: Icon(ev['evento'] == 'PAUSA' ? Icons.pause_circle : Icons.play_circle, color: ev['evento'] == 'PAUSA' ? Colors.orange : Colors.green),
                           title: Text(ev['evento'], style: TextStyle(fontWeight: FontWeight.bold, color: esOscuro ? Colors.white : Colors.black)),
                           trailing: Text(hora, style: TextStyle(color: esOscuro ? Colors.grey : Colors.black54)),
                         );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!_finalizado && !widget.esAdmin) Padding(
            padding: const EdgeInsets.all(16), 
            child: _procesandoCierre 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFEF7D00)))
            : Column(children: [
              
              if (!_enProgreso) 
                ElevatedButton.icon(
                  onPressed: _botonIniciar, 
                  icon: const Icon(Icons.play_arrow), 
                  label: Text(haIniciadoAlgunaVez ? "REANUDAR TAREA" : "INICIAR TAREA"), 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50))
                )
              else 
                ElevatedButton.icon(
                  onPressed: () { _actualizarActividadEnDjango(false); _registrarEventoBitacora("PAUSA"); }, 
                  icon: const Icon(Icons.pause), 
                  label: const Text("PAUSAR TAREA"), 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50))
                ),

              if (haIniciadoAlgunaVez) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context, 
                    builder: (ctx) {
                      bool oscuroDialog = Theme.of(context).brightness == Brightness.dark;
                      return AlertDialog(
                        backgroundColor: oscuroDialog ? Colors.grey[900] : Colors.white, 
                        title: Text("Finalizar Tarea", style: TextStyle(color: oscuroDialog ? const Color(0xFFEF7D00) : Colors.black)),
                        content: TextField(controller: _notasController, decoration: const InputDecoration(labelText: "Notas Finales (Opcional)"), style: TextStyle(color: oscuroDialog ? Colors.white : Colors.black)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))), 
                          ElevatedButton(
                            onPressed: () async { 
                               Navigator.pop(ctx); 
                               await _registrarEventoBitacora("FINAL"); 
                               await _finalizarTareaEnDjango(); 
                            }, 
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), 
                            child: const Text("FINALIZAR")
                          )
                        ]
                      );
                    }
                  ),
                  icon: const Icon(Icons.stop, color: Colors.red), 
                  label: const Text("FINALIZAR TAREA", style: TextStyle(color: Colors.red)), 
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), side: const BorderSide(color: Colors.red))
                )
              ]
            ])
          )
        ],
      ),
    );
  }

  Widget _botonFoto(String tipo, IconData icono, bool esOscuro) {
    return Column(children: [
       IconButton(
         icon: _enviandoFoto 
           ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF7D00))) 
           : Icon(icono, size: 25), 
         color: esOscuro ? Colors.white70 : Colors.black87, 
         onPressed: _enviandoFoto ? null : () => _mostrarOpcionesImagen(tipo), // <--- CAMBIO AQUÍ
         style: IconButton.styleFrom(
           backgroundColor: esOscuro ? Colors.grey[800] : Colors.grey[300], 
           padding: const EdgeInsets.all(10)
         )
       ), 
       const SizedBox(height: 5), 
       Text(tipo, style: TextStyle(fontSize: 10, color: esOscuro ? Colors.grey : Colors.black54))
    ]);
  }
}
// ============================
// 7. PANTALLA DE EDITAR ORDEN
// ============================
class EditarOrdenScreen extends StatelessWidget {
  final Map<String, dynamic> orden;
  const EditarOrdenScreen({super.key, required this.orden});

  @override
  Widget build(BuildContext context) {
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Editar Orden #${orden['numero_orden']}", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.white)),
        backgroundColor: esOscuro ? Colors.grey[900] : colorIngenioOrange,
        iconTheme: IconThemeData(color: esOscuro ? colorIngenioOrange : Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_off, size: 80, color: esOscuro ? Colors.grey[700] : Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                "Edición Móvil Bloqueada",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: esOscuro ? colorIngenioOrange : Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                "Esta orden está vinculada a los registros de SAP. Para mantener la integridad y evitar desajustes en las operaciones, cualquier modificación estructural (ubicaciones, prioridades o agregar nuevas tareas) debe realizarse exclusivamente desde el Panel Web Administrativo.",
                style: TextStyle(fontSize: 16, color: esOscuro ? Colors.grey[400] : Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text("VOLVER AL PANEL"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorIngenioOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 50),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
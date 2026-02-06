import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// =========================================================
// 1. CONFIGURACIÓN GLOBAL Y LOGIN (BLINDADO)
// =========================================================

//Usar esta para el EMULADOR (Desarrollo en PC)
// const String baseUrl = "http://10.0.2.2:8000";

const String baseUrl = "http://10.0.2.2:8000"; 

const Color colorIngenioOrange = Color(0xFFEF7D00);

// VARIABLE GLOBAL PARA EL MODO OSCURO
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Monte Rosa App',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          
          // --- TEMA CLARO ---
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            // Esto se encarga de pintar casi todo de naranja automáticamente
            colorScheme: ColorScheme.fromSeed(seedColor: colorIngenioOrange, brightness: Brightness.light),
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            appBarTheme: const AppBarTheme(backgroundColor: colorIngenioOrange, foregroundColor: Colors.white),
            inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: colorIngenioOrange, foregroundColor: Colors.white),
          ),
          
          // --- TEMA OSCURO (SIN ERRORES) ---
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            
            // Esquema de color oscuro basado en naranja
            colorScheme: ColorScheme.fromSeed(
              seedColor: colorIngenioOrange, 
              brightness: Brightness.dark,
              surface: const Color(0xFF1E1E1E), // Color base para tarjetas
            ),
            
            scaffoldBackgroundColor: const Color(0xFF121212), 
            
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[900], 
              foregroundColor: colorIngenioOrange
            ),
            
            inputDecorationTheme: InputDecorationTheme(
              border: const OutlineInputBorder(), 
              filled: true, 
              fillColor: Colors.grey[900]
            ),
            
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorIngenioOrange, 
                foregroundColor: Colors.white
              ),
            ),
            
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: colorIngenioOrange, 
              foregroundColor: Colors.white
            ),
            
            // HE ELIMINADO 'tabBarTheme' y 'cardTheme' AQUÍ PORQUE CAUSABAN EL ERROR.
            // No te preocupes, el 'LoginScreen' tiene su propio estilo manual que
            // forzará el color naranja correctamente.
          ),

          home: const LoginScreen(),
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
    // Detectar modo oscuro
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Botón flotante para cambiar tema
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: esOscuro ? Colors.yellow : colorIngenioOrange,
        child: Icon(esOscuro ? Icons.light_mode : Icons.dark_mode, color: esOscuro ? Colors.black : Colors.white),
        onPressed: () {
          themeNotifier.value = esOscuro ? ThemeMode.light : ThemeMode.dark;
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,

      body: SafeArea(
        child: Center( // Centramos todo el contenido verticalmente
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 120, // Tamaño grande para el login
                  width: 120,
                  padding: const EdgeInsets.all(15), // Margen interno
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.factory, size: 60, color: colorIngenioOrange);
                    },
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  "Ingenio Monte Rosa", 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorIngenioOrange)
                ),
                const SizedBox(height: 30),
                
                // Selector de Operario / Admin
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20), 
                  child: Container(
                    decoration: BoxDecoration(
                      color: esOscuro ? Colors.grey[800] : Colors.grey[200], 
                      borderRadius: BorderRadius.circular(25)
                    ), 
                    child: TabBar(
                      controller: _tabController, 
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(color: colorIngenioOrange, borderRadius: BorderRadius.circular(25)), 
                      labelColor: Colors.white, 
                      unselectedLabelColor: Colors.grey, 
                      dividerColor: Colors.transparent,
                      tabs: const [Tab(text: "Operario"), Tab(text: "Admin")]
                    )
                  )
                ),
                
                // Formularios (con altura fija para que no salten)
                SizedBox(
                  height: 350, 
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Formulario Operario
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            TextField(
                              controller: _opCodigoController, 
                              decoration: const InputDecoration(labelText: "Código de Trabajador", prefixIcon: Icon(Icons.badge, color: colorIngenioOrange)), 
                              keyboardType: TextInputType.number
                            ),
                            const SizedBox(height: 30),
                            if (cargando) const CircularProgressIndicator(color: colorIngenioOrange) 
                            else ElevatedButton(
                              onPressed: _loginOperario, // Asegúrate de tener esta función
                              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: colorIngenioOrange, foregroundColor: Colors.white), 
                              child: const Text("INGRESAR")
                            ),
                          ]
                        ),
                      ),
                      
                      // Formulario Admin
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            TextField(controller: _adminUserController, decoration: const InputDecoration(labelText: "Usuario", prefixIcon: Icon(Icons.admin_panel_settings, color: colorIngenioOrange))),
                            const SizedBox(height: 15),
                            TextField(controller: _adminPassController, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock, color: colorIngenioOrange))),
                            const SizedBox(height: 30),
                            if (cargando) const CircularProgressIndicator(color: colorIngenioOrange) 
                            else ElevatedButton(
                              onPressed: _loginAdmin, // Asegúrate de tener esta función
                              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white), 
                              child: const Text("ACCESO ADMIN")
                            ),
                          ]
                        ),
                      ),
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
// ==========================================
// 2. PANEL DE ADMINISTRADOR (DASHBOARD - MODO OSCURO + NARANJA)
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
    // Diálogo con estilo oscuro si es necesario
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
    // DETECTAR MODO OSCURO
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          // FONDO: Oscuro en modo noche, Naranja en modo día
          backgroundColor: esOscuro ? Colors.grey[900] : colorIngenioOrange,
          foregroundColor: esOscuro ? colorIngenioOrange : Colors.white,
          
          // TÍTULO CON LOGO
          title: Row(
            children: [
              // Logo pequeño en la barra
              Container(
                height: 35,
                width: 35,
                padding: const EdgeInsets.all(2),
                child: Image.asset('assets/logo.png', fit: BoxFit.contain,
                  errorBuilder: (c,e,s) => const Icon(Icons.factory, size: 20, color: colorIngenioOrange)
                ),
              ),
              const SizedBox(width: 10),
              // Nombre del Admin
              Expanded(
                child: Text(
                  "Admin", 
                  style: TextStyle(fontSize: 18, color: esOscuro ? colorIngenioOrange : Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          // PESTAÑAS (TABS)
          bottom: TabBar(
            labelColor: esOscuro ? colorIngenioOrange : Colors.white,
            unselectedLabelColor: esOscuro ? Colors.grey : Colors.white70,
            indicatorColor: esOscuro ? colorIngenioOrange : Colors.white,
            tabs: const [Tab(text: "PENDIENTES"), Tab(text: "COMPLETADAS")]
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app), 
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))
            )
          ],
        ),
        
        body: cargando 
          ? const Center(child: CircularProgressIndicator(color: colorIngenioOrange)) 
          : TabBarView(children: [_listaAdmin(pendientes, esHistorial: false), _listaAdmin(completadas, esHistorial: true)]),
        
        // BOTÓN AGREGAR (+) - Ahora Naranja
        floatingActionButton: FloatingActionButton(
          backgroundColor: colorIngenioOrange, 
          child: const Icon(Icons.add, color: Colors.white), 
          tooltip: "Crear Nueva Orden",
          onPressed: () { 
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CrearOrdenScreen())).then((_) { 
              setState(() => cargando = true); 
              fetchTodasLasOrdenes(); 
            }); 
          },
        ),
      ),
    );
  }

  Widget _listaAdmin(List<dynamic> lista, {required bool esHistorial}) {
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 50, color: esOscuro ? Colors.grey[700] : Colors.grey[300]),
            Text(esHistorial ? "No hay historial" : "Todo al día", style: const TextStyle(color: Colors.grey))
          ],
        )
      );
    }

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
          // CORRECCIÓN: Fondo de tarjeta oscuro en modo noche
          color: esOscuro ? Colors.grey[850] : Colors.white,
          elevation: 3, 
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorAvatar,
              child: Text(letraAvatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            // Título: Blanco en oscuro, Negro en claro
            title: Text("Orden #${orden['numero_orden']}", style: TextStyle(fontWeight: FontWeight.bold, color: esOscuro ? Colors.white : Colors.black)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Asignado a: ${orden['codigo_trabajador']}", style: TextStyle(color: esOscuro ? Colors.grey : Colors.black87)),
                Text("Ubicación: ${orden['ubicacion']}", style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.grey[600])),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!esHistorial) 
                  IconButton(
                    // CORRECCIÓN: Icono Editar Naranja
                    icon: const Icon(Icons.edit, color: colorIngenioOrange), 
                    onPressed: () { 
                      Navigator.push(context, MaterialPageRoute(builder: (context) => EditarOrdenScreen(orden: orden))).then((_) { 
                        setState(() => cargando = true); 
                        fetchTodasLasOrdenes(); 
                      }); 
                    }
                  ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ]),
            onTap: () { 
                Navigator.push(context, MaterialPageRoute(builder: (context) => DetalleOrdenScreen(orden: orden, nombreTrabajador: "ADMIN"))).then((_) => fetchTodasLasOrdenes()); 
            },
          ),
        );
      },
    );
  }

  Color _colorPrioridad(String? p) {
    if (p == 'ALTA') return Colors.red;
    // Si es media, usamos un naranja amarillento para distinguir del Naranja corporativo, o el mismo naranja.
    if (p == 'MEDIA') return Colors.orange; 
    return Colors.green; 
  }
}

// ==========================================
// 3. FORMULARIO CREAR ORDEN (MODO OSCURO + NARANJA)
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

  // Función para seleccionar fecha y hora
  Future<void> _seleccionarFechaHora(bool esInicio) async {
    DateTime base = esInicio ? _inicio : _fin;
    
    // El DatePicker toma automáticamente los colores del tema (Naranja)
    final DateTime? fecha = await showDatePicker(
      context: context, initialDate: base, firstDate: DateTime(2024), lastDate: DateTime(2030),
      builder: (context, child) {
        // Forzamos tema oscuro o claro en el calendario si es necesario
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: colorIngenioOrange, 
              brightness: Theme.of(context).brightness
            ),
          ),
          child: child!,
        );
      }
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

  // Diálogo para agregar actividad (Estilizado)
  void _mostrarDialogoActividad() {
    final descController = TextEditingController();
    final areaController = TextEditingController();
    final horasController = TextEditingController(text: "01");
    final minutosController = TextEditingController(text: "00");

    showDialog(
      context: context,
      builder: (ctx) {
        bool esOscuro = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: esOscuro ? Colors.grey[900] : Colors.white,
          title: Text("Agregar Actividad", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.black)),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text("Cancelar", style: TextStyle(color: esOscuro ? Colors.grey : Colors.black54))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: colorIngenioOrange, foregroundColor: Colors.white),
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
        );
      },
    );
  }

  Future<void> _guardarOrden() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_actividadesTemporales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debe agregar al menos una actividad"), backgroundColor: Colors.red));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Orden Creada Exitosamente"), backgroundColor: Colors.green));
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
    // DETECCIÓN DE MODO OSCURO
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Nueva Orden", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.white)),
        backgroundColor: esOscuro ? Colors.grey[900] : colorIngenioOrange,
        iconTheme: IconThemeData(color: esOscuro ? colorIngenioOrange : Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Datos Generales", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: esOscuro ? colorIngenioOrange : Colors.black87)
              ),
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
                dropdownColor: esOscuro ? Colors.grey[850] : Colors.white, // Fondo del menú desplegable
                items: ['ALTA', 'MEDIA', 'BAJA'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (val) => setState(() => _prioridad = val!),
              ),
              const SizedBox(height: 20),
              
              // BOTONES DE FECHA (Estilo Outline Naranja)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _seleccionarFechaHora(true), 
                      icon: const Icon(Icons.calendar_today), 
                      label: Text("Inicio:\n${_inicio.toString().substring(0,16)}"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorIngenioOrange,
                        side: const BorderSide(color: colorIngenioOrange)
                      )
                    )
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _seleccionarFechaHora(false), 
                      icon: const Icon(Icons.event_busy), 
                      label: Text("Fin:\n${_fin.toString().substring(0,16)}"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorIngenioOrange,
                        side: const BorderSide(color: colorIngenioOrange)
                      )
                    )
                  ),
                ],
              ),
              
              const Divider(height: 30, thickness: 2),
              
              // SECCIÓN ACTIVIDADES
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Actividades", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: esOscuro ? colorIngenioOrange : Colors.black87)),
                  IconButton(
                    onPressed: _mostrarDialogoActividad, 
                    icon: const Icon(Icons.add_circle, color: colorIngenioOrange, size: 30) // Icono Naranja
                  )
                ],
              ),
              
              if (_actividadesTemporales.isEmpty) 
                Padding(padding: const EdgeInsets.all(20), child: Center(child: Text("Sin actividades", style: TextStyle(color: esOscuro ? Colors.grey : Colors.grey[600]))))
              else 
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _actividadesTemporales.length,
                  itemBuilder: (context, index) {
                    final act = _actividadesTemporales[index];
                    return Card(
                      color: esOscuro ? Colors.grey[800] : Colors.white, // Tarjeta oscura en modo noche
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorIngenioOrange,
                          foregroundColor: Colors.white,
                          child: Text("${index + 1}")
                        ),
                        title: Text(act['descripcion'], style: TextStyle(color: esOscuro ? Colors.white : Colors.black)),
                        subtitle: Text("Plan: ${act['tiempo_planificado']}", style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.grey[700])),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _actividadesTemporales.removeAt(index))),
                      ),
                    );
                  }
                ),
              const SizedBox(height: 30),
              
              // BOTÓN GUARDAR (Naranja)
              ElevatedButton(
                onPressed: _guardarOrden,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorIngenioOrange, 
                  foregroundColor: Colors.white, 
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: const Text("GUARDAR ORDEN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
// ==========================================
// 4. PANTALLA MIS ÓRDENES (MODO OSCURO + NARANJA)
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
        
        // Filtro de seguridad en el cliente
        List<dynamic> soloMias = todas.where((o) {
          String assignedWorker = (o['codigo_trabajador'] ?? "").toString().trim();
          String myCode = widget.codigoTrabajador.trim();
          return assignedWorker == myCode;
        }).toList();

        if (mounted) {
          setState(() {
            // Repartimos en pestañas
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
    
    // Diálogo adaptado a modo oscuro
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
    // DETECCIÓN DE MODO OSCURO
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          // FONDO: Oscuro en noche, Naranja en día
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
          // PESTAÑAS (TABS) - Colores corregidos
          bottom: TabBar(
            labelColor: esOscuro ? colorIngenioOrange : Colors.white, // Texto seleccionado
            unselectedLabelColor: esOscuro ? Colors.grey : Colors.white70, // Texto no seleccionado
            indicatorColor: esOscuro ? colorIngenioOrange : Colors.white, // Línea inferior
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
      color: colorIngenioOrange, // Spinner naranja
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
          
          Color colorAvatar = colorIngenioOrange; // Por defecto Naranja (antes era Orange)
          if (orden['prioridad'] == 'ALTA') colorAvatar = Colors.red;
          if (orden['prioridad'] == 'BAJA') colorAvatar = Colors.green;
          Color colorFinal = esHistorial ? Colors.green : colorAvatar;

          return Card(
            // FONDO TARJETA: Oscuro en noche, Blanco en día
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
              // TEXTO TÍTULO: Blanco en noche
              title: Text("Orden #${orden['numero_orden']}", style: TextStyle(fontWeight: FontWeight.bold, color: esOscuro ? Colors.white : Colors.black)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(orden['ubicacion'] ?? "Sin ubicación", style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.black54)),
                  if (!esHistorial) Text("Asignado a: ${orden['codigo_trabajador']}", style: TextStyle(fontSize: 10, color: esOscuro ? Colors.grey : Colors.grey[600])),
              ]),
              // FLECHA: Naranja en noche para resaltar
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
// ==========================================
// 5. DETALLE DE ORDEN (MODO OSCURO + NARANJA)
// ==========================================
class DetalleOrdenScreen extends StatefulWidget {
  final Map<String, dynamic> orden;
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
    // Detectar modo oscuro para el diálogo
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    
    bool? confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: esOscuro ? Colors.grey[900] : Colors.white,
        title: Text("¿Finalizar Orden?", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.black)),
        content: Text("La orden pasará al historial inmediatamente.", style: TextStyle(color: esOscuro ? Colors.white : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
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
    showDialog(context: context, builder: (ctx)=>AlertDialog(
      backgroundColor: esOscuro ? Colors.grey[900] : Colors.white,
      title:Text(t, style:const TextStyle(color:Colors.red)), 
      content:Text(m, style: TextStyle(color: esOscuro ? Colors.white : Colors.black)), 
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx), child:const Text("OK"))])
    );
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
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    
    // 1. SEPARAMOS LISTAS
    List<dynamic> todas = ordenActual['actividades'] ?? [];
    List<dynamic> pendientes = todas.where((a) => a['completada'] == false).toList();
    List<dynamic> terminadas = todas.where((a) => a['completada'] == true).toList();
    
    bool ordenCerrada = ordenActual['completada'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text("Orden #${ordenActual['numero_orden']}", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.white)),
        backgroundColor: esOscuro ? Colors.grey[900] : colorIngenioOrange,
        iconTheme: IconThemeData(color: esOscuro ? colorIngenioOrange : Colors.white),
      ),
      body: Column(
        children: [
          // CABECERA (Adaptable al modo oscuro)
          Container(
            padding: const EdgeInsets.all(16),
            color: esOscuro ? Colors.grey[850] : Colors.white, // Fondo oscuro o blanco
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow("Ubicación:", ordenActual['ubicacion'], esOscuro),
                const SizedBox(height: 5),
                _infoRow("Proceso:", ordenActual['proceso'], esOscuro),
                const SizedBox(height: 10),
                if (ordenCerrada) 
                  const Chip(label: Text("FINALIZADA", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green)
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8), 
                    // Título Naranja en lugar de Azul
                    child: Row(
                      children: const [
                        Icon(Icons.push_pin, color: colorIngenioOrange, size: 20),
                        SizedBox(width: 8),
                        Text("ACTIVIDADES PENDIENTES", style: TextStyle(fontWeight: FontWeight.bold, color: colorIngenioOrange)),
                      ],
                    )
                  ),
                  ...pendientes.map((act) => _cardActividad(act, false, esOscuro)),
                ],

                // SECCIÓN TERMINADAS
                if (terminadas.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("✅ ACTIVIDADES REALIZADAS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                  ...terminadas.map((act) => _cardActividad(act, true, esOscuro)),
                ],

                if (pendientes.isEmpty && terminadas.isEmpty)
                  Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("No hay actividades", style: TextStyle(color: esOscuro ? Colors.grey : Colors.grey[600])))),
              ],
            ),
          ),
          
          // BOTÓN FINALIZAR ORDEN (Ahora Naranja)
          if (!ordenCerrada && pendientes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16), 
              child: _enviando 
                ? const Center(child: CircularProgressIndicator(color: colorIngenioOrange))
                : ElevatedButton.icon(
                    onPressed: _finalizarOrdenCompleta, 
                    icon: const Icon(Icons.archive), 
                    label: const Text("FINALIZAR ORDEN"), 
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50), 
                      backgroundColor: colorIngenioOrange, // Fondo Naranja
                      foregroundColor: Colors.white
                    )
                  )
            )
        ],
      ),
    );
  }

  // Widget auxiliar para textos con estilo
  Widget _infoRow(String label, String? value, bool esOscuro) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 16, color: esOscuro ? Colors.grey[300] : Colors.black87),
        children: [
          TextSpan(text: "$label ", style: TextStyle(fontWeight: FontWeight.bold, color: esOscuro ? colorIngenioOrange : Colors.black)),
          TextSpan(text: value ?? "N/D"),
        ],
      ),
    );
  }

  Widget _cardActividad(dynamic act, bool completada, bool esOscuro) {
    List<dynamic> bitacora = act['bitacora'] ?? [];
    String tiempoPausas = completada ? _calcularTiempoPausas(bitacora) : "00:00";

    // Lógica de color de tarjeta
    Color? colorFondo;
    if (completada) {
      // Si está completada: Verde suave (día) o Verde muy oscuro (noche)
      colorFondo = esOscuro ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50];
    } else {
      // Si está pendiente: Gris oscuro (noche) o Blanco (día)
      colorFondo = esOscuro ? Colors.grey[800] : Colors.white;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      color: colorFondo,
      child: ListTile(
        title: Text(
          act['descripcion'], 
          style: TextStyle(
            decoration: completada ? TextDecoration.lineThrough : null,
            color: esOscuro ? Colors.white : Colors.black, // Texto legible en noche
            fontWeight: FontWeight.bold
          )
        ),
        subtitle: completada 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Ejecutor: ${act['nombre_ejecutor'] ?? 'Desconocido'}", style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.grey[800])),
                  Text("Tiempo Activo: ${act['tiempo_real_acumulado']}", style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.grey[800])),
                  Text("Tiempo Pausas: $tiempoPausas", style: const TextStyle(color: Colors.orange)),
                ],
              )
            : Text("Plan: ${act['tiempo_planificado']}", style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.grey[600])),
        trailing: completada 
          ? const Icon(Icons.check_circle, color: Colors.green) 
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorIngenioOrange, // Botón ABRIR naranja
                foregroundColor: Colors.white,
              ),
              child: const Text("ABRIR"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EjecucionActividadScreen(
                      actividad: act, 
                      nombreTrabajador: widget.nombreTrabajador
                    )
                  )
                ).then((_) => _recargarOrden());
              },
            ),
      ),
    );
  }
}
// ==========================================
// 6. PANTALLA DE EJECUCIÓN (MODO OSCURO + NARANJA + CÁLCULO OFFLINE)
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
    WidgetsBinding.instance.addObserver(this);
    
    actividadData = widget.actividad;
    if (actividadData['bitacora'] != null) {
      _historialBitacora = List.from(actividadData['bitacora']);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sincronizarEstadoInicial();
    }
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
    _finalizado = actividadData['completada'] ?? false;

    // CÁLCULO OFFLINE (Lógica intacta)
    if (_enProgreso && !_finalizado && _historialBitacora.isNotEmpty) {
      try {
        var ultimoEvento = _historialBitacora.last;
        if (ultimoEvento['fecha_hora'] != null) {
          DateTime fechaUltimoEvento = DateTime.parse(ultimoEvento['fecha_hora']);
          DateTime ahora = DateTime.now();
          Duration tiempoTranscurridoOffline = ahora.difference(fechaUltimoEvento);
          
          if (!tiempoTranscurridoOffline.isNegative) {
             _tiempoAcumulado += tiempoTranscurridoOffline;
          }
        }
      } catch (e) { /* */ }
    }

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
        });
      }
    } catch (e) { print(e); }
  }

  Future<void> _actualizarActividadEnDjango(bool arrancando) async {
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

  // BOTÓN INICIAR INTELIGENTE (Con Diálogo Oscuro)
  Future<void> _botonIniciar() async {
    bool nombreInvalido = widget.nombreTrabajador == "null" || widget.nombreTrabajador.trim().isEmpty;
    bool faltaNombreManual = _nombreManualController.text.isEmpty;

    if (nombreInvalido && faltaNombreManual && actividadData['nombre_ejecutor'] == null) {
      // Detección tema para diálogo
      bool esOscuro = Theme.of(context).brightness == Brightness.dark;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: esOscuro ? Colors.grey[900] : Colors.white,
          title: Text("Falta Identificación", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.black)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
             Text("No se detectó tu nombre. Ingrésalo para continuar:", style: TextStyle(color: esOscuro ? Colors.white : Colors.black)),
             const SizedBox(height: 10),
             TextField(
               controller: _nombreManualController, 
               decoration: const InputDecoration(labelText: "Tu Nombre"),
               style: TextStyle(color: esOscuro ? Colors.white : Colors.black),
             )
          ]),
          actions: [
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); if (_nombreManualController.text.isNotEmpty) _botonIniciar(); }, 
              style: ElevatedButton.styleFrom(backgroundColor: colorIngenioOrange, foregroundColor: Colors.white),
              child: const Text("GUARDAR E INICIAR")
            )
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
    // DETECCIÓN DE MODO OSCURO
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    
    String reloj = _tiempoAcumulado.toString().split('.').first.padLeft(8, "0");
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Cód: ${actividadData['codigo_actividad']}", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.white)),
        backgroundColor: esOscuro ? Colors.grey[900] : colorIngenioOrange,
        iconTheme: IconThemeData(color: esOscuro ? colorIngenioOrange : Colors.white),
      ),
      body: Column(
        children: [
          // CAJA DEL CRONÓMETRO (Adaptada)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            // Fondo oscuro en noche, Blanco en día
            color: esOscuro ? Colors.grey[850] : Colors.white, 
            width: double.infinity,
            child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    actividadData['descripcion'], 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: esOscuro ? Colors.white : Colors.black87)
                  ),
                ),
                const SizedBox(height: 10),
                // NÚMEROS DEL RELOJ (Ahora Naranja)
                Text(
                  reloj, 
                  style: const TextStyle(
                    fontSize: 50, 
                    fontWeight: FontWeight.bold, 
                    color: colorIngenioOrange, // <<-- CAMBIO CLAVE A NARANJA
                    fontFamily: 'monospace'
                  )
                ),
                const SizedBox(height: 5),
                if (_finalizado) const Text("✅ FINALIZADA", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                else if (_enProgreso) const Text("🔥 EN EJECUCIÓN...", style: TextStyle(color: colorIngenioOrange, fontWeight: FontWeight.bold))
            ]),
          ),
          
          // BITÁCORA DE EVENTOS
          Expanded(
            child: Container(
              color: esOscuro ? Colors.black : Colors.grey[100], // Fondo de la lista
              child: ListView.separated(
                itemCount: _historialBitacora.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: esOscuro ? Colors.grey[800] : Colors.grey[300]),
                itemBuilder: (context, index) {
                   final ev = _historialBitacora[_historialBitacora.length - 1 - index];
                   String hora = "--:--";
                   if (ev['fecha_hora'] != null) { try { hora = ev['fecha_hora'].toString().split('T')[1].substring(0, 8); } catch(e){/* */} }
                   
                   return ListTile(
                     dense: true,
                     // Color de fondo del renglón para contraste
                     tileColor: esOscuro ? Colors.grey[900] : Colors.white,
                     leading: Icon(
                       ev['evento'] == 'PAUSA' ? Icons.pause_circle : Icons.play_circle, 
                       color: ev['evento'] == 'PAUSA' ? Colors.orange : Colors.green
                     ),
                     title: Text(ev['evento'], style: TextStyle(fontWeight: FontWeight.bold, color: esOscuro ? Colors.white : Colors.black)),
                     trailing: Text(hora, style: TextStyle(color: esOscuro ? Colors.grey : Colors.black54)),
                   );
                },
              ),
            ),
          ),

          // BOTONES DE CONTROL
          if (!_finalizado) Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              if (!_enProgreso) 
                ElevatedButton.icon(
                  onPressed: _botonIniciar, 
                  icon: const Icon(Icons.play_arrow), 
                  label: const Text("INICIAR / REANUDAR"), 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50))
                )
              else 
                Column(children: [
                  ElevatedButton.icon(
                    onPressed: () { _actualizarActividadEnDjango(false); _registrarEventoBitacora("PAUSA"); }, 
                    icon: const Icon(Icons.pause), 
                    label: const Text("PAUSAR"), 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50))
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => showDialog(
                      context: context, 
                      builder: (ctx) {
                        bool oscuroDialog = Theme.of(context).brightness == Brightness.dark;
                        return AlertDialog(
                          backgroundColor: oscuroDialog ? Colors.grey[900] : Colors.white,
                          title: Text("Finalizar Tarea", style: TextStyle(color: oscuroDialog ? colorIngenioOrange : Colors.black)),
                          content: TextField(
                            controller: _notasController, 
                            decoration: const InputDecoration(labelText: "Notas Finales"),
                            style: TextStyle(color: oscuroDialog ? Colors.white : Colors.black),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))), 
                            ElevatedButton(
                              onPressed: () { Navigator.pop(ctx); _finalizarTareaEnDjango(); _registrarEventoBitacora("FINAL"); }, 
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
                ])
          ]))
        ],
      ),
    );
  }
}
// ==========================================
// 7. PANTALLA DE EDITAR ORDEN (MODO ADMIN/SUPERVISOR + MODO OSCURO)
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
  late TextEditingController _procesoController;
  late TextEditingController _trabajadorController;
  late TextEditingController _supervisorController;
  
  // Variables de Estado
  late String _prioridad;
  late DateTime _inicio;
  late DateTime _fin;
  late String _supervisorCodigoOriginal;

  // Listas separadas
  List<dynamic> _actividadesExistentes = [];
  List<Map<String, dynamic>> _actividadesNuevas = [];

  @override
  void initState() {
    super.initState();
    var o = widget.orden;
    
    _numeroController = TextEditingController(text: o['numero_orden']);
    _ubicacionController = TextEditingController(text: o['ubicacion']);
    _ubicacionTecnicaController = TextEditingController(text: o['ubicacion_tecnica'] ?? o['ubicacion']);
    _procesoController = TextEditingController(text: o['proceso']);
    _trabajadorController = TextEditingController(text: o['codigo_trabajador']);
    _supervisorController = TextEditingController(text: o['supervisor_nombre']);
    
    _supervisorCodigoOriginal = o['supervisor_codigo'] ?? "ADMIN";
    _prioridad = o['prioridad'];
    
    try {
      _inicio = DateTime.parse(o['inicio_programado']);
      _fin = DateTime.parse(o['fin_programado']);
    } catch (e) {
      _inicio = DateTime.now();
      _fin = DateTime.now().add(const Duration(hours: 4));
    }
    
    _actividadesExistentes = List.from(o['actividades'] ?? []);
  }

  // LÓGICA: SELECTORES DE FECHA Y HORA (Con tema Naranja)
  Future<void> _seleccionarFechaHora(bool esInicio) async {
    DateTime base = esInicio ? _inicio : _fin;
    
    final DateTime? fecha = await showDatePicker(
      context: context, 
      initialDate: base, 
      firstDate: DateTime(2024), 
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: colorIngenioOrange, 
              brightness: Theme.of(context).brightness
            ),
          ),
          child: child!,
        );
      }
    );
    if (fecha == null) return;
    
    if (!mounted) return;
    
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

  // LÓGICA: AGREGAR NUEVA ACTIVIDAD (Dialogo Oscuro/Claro)
  void _mostrarDialogoActividad() {
    final descController = TextEditingController();
    final areaController = TextEditingController();
    final horasController = TextEditingController(text: "01");
    final minutosController = TextEditingController(text: "00");

    showDialog(
      context: context,
      builder: (ctx) {
        bool esOscuro = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: esOscuro ? Colors.grey[900] : Colors.white,
          title: Text("Agregar Actividad Extra", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.black)),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: colorIngenioOrange, foregroundColor: Colors.white),
              onPressed: () {
                if (descController.text.isNotEmpty) {
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
        );
      },
    );
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    
    final url = Uri.parse('$baseUrl/api/ordenes/${widget.orden['id']}/');
    
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Orden Actualizada Correctamente"), backgroundColor: Colors.green));
          Navigator.pop(context); 
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al actualizar: ${response.body}"), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) { 
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error de conexión"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detectar modo oscuro
    bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Editar Orden", style: TextStyle(color: esOscuro ? colorIngenioOrange : Colors.white)),
        backgroundColor: esOscuro ? Colors.grey[900] : colorIngenioOrange,
        iconTheme: IconThemeData(color: esOscuro ? colorIngenioOrange : Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Datos Generales", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: esOscuro ? colorIngenioOrange : Colors.black87)),
              const SizedBox(height: 15),
              
              TextFormField(
                controller: _numeroController, 
                decoration: const InputDecoration(labelText: "N° Orden"), 
                readOnly: true, 
                style: const TextStyle(color: Colors.grey)
              ),
              const SizedBox(height: 10),
              
              TextFormField(controller: _trabajadorController, decoration: const InputDecoration(labelText: "Cód. Trabajador")),
              const SizedBox(height: 10),
              
              TextFormField(controller: _ubicacionController, decoration: const InputDecoration(labelText: "Ubicación")),
              const SizedBox(height: 10),
              
              TextFormField(controller: _procesoController, decoration: const InputDecoration(labelText: "Proceso"), validator: (v) => v!.isEmpty ? "Requerido" : null),
              const SizedBox(height: 10),
              
              // Selector de Fechas (Outline Naranja)
              Row(children: [
                 Expanded(
                   child: OutlinedButton(
                     onPressed: () => _seleccionarFechaHora(true), 
                     style: OutlinedButton.styleFrom(
                       foregroundColor: colorIngenioOrange,
                       side: const BorderSide(color: colorIngenioOrange)
                     ),
                     child: Text("Inicio:\n${_inicio.toString().substring(0,16)}")
                   )
                 ),
                 const SizedBox(width: 10),
                 Expanded(
                   child: OutlinedButton(
                     onPressed: () => _seleccionarFechaHora(false), 
                     style: OutlinedButton.styleFrom(
                       foregroundColor: colorIngenioOrange,
                       side: const BorderSide(color: colorIngenioOrange)
                     ),
                     child: Text("Fin:\n${_fin.toString().substring(0,16)}")
                   )
                 ),
              ]),

              const Divider(height: 30, thickness: 2),
              
              // SECCIÓN: ACTIVIDADES EXISTENTES
              Text("Actividades Existentes (Bloqueadas)", style: TextStyle(fontWeight: FontWeight.bold, color: esOscuro ? Colors.white : Colors.black)),
              if (_actividadesExistentes.isEmpty) 
                const Text("Sin registros previos", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              
              ..._actividadesExistentes.map((a) => ListTile(
                title: Text(a['descripcion'], style: TextStyle(color: esOscuro ? Colors.grey[400] : Colors.black87)), 
                subtitle: Text("Estado: ${a['completada'] ? 'Completada' : 'Pendiente'}", style: TextStyle(color: esOscuro ? Colors.grey[600] : Colors.grey)),
                leading: const Icon(Icons.lock, size: 16, color: Colors.grey), 
                dense: true
              )),

              const Divider(height: 20),
              
              // SECCIÓN: AGREGAR NUEVAS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                    Text("Agregar Nuevas Actividades", style: TextStyle(fontWeight: FontWeight.bold, color: colorIngenioOrange)),
                    IconButton(onPressed: _mostrarDialogoActividad, icon: const Icon(Icons.add_circle, color: colorIngenioOrange, size: 30))
                ]
              ),
              
              // Lista de Actividades Nuevas
              ..._actividadesNuevas.map((a) => Card(
                // Fondo de tarjeta suave en ambos modos
                color: esOscuro ? Colors.orange.withOpacity(0.1) : Colors.orange[50], 
                child: ListTile(
                  title: Text(a['descripcion'] + " (NUEVA)", style: TextStyle(color: esOscuro ? Colors.white : Colors.black, fontWeight: FontWeight.bold)), 
                  leading: const Icon(Icons.star, color: colorIngenioOrange), 
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red), 
                    onPressed: () => setState(() => _actividadesNuevas.remove(a))
                  )
                )
              )),

              const SizedBox(height: 30),
              
              // BOTÓN GUARDAR (Naranja)
              ElevatedButton(
                onPressed: _guardarCambios, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorIngenioOrange, 
                  foregroundColor: Colors.white, 
                  minimumSize: const Size(double.infinity, 50)
                ), 
                child: const Text("GUARDAR CAMBIOS")
              )
            ]
          ),
        ),
      ),
    );
  }
}
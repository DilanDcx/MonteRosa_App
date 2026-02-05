from rest_framework import viewsets
from rest_framework.decorators import api_view
from rest_framework.decorators import action  
from rest_framework.response import Response
from django.contrib.auth import authenticate
from rest_framework.response import Response
from .models import OrdenTrabajo, Actividad, BitacoraActividad, Trabajador
from .serializers import OrdenTrabajoSerializer, ActividadSerializer, BitacoraSerializer, TrabajadorSerializer

# --- VISTAS ESTÁNDAR (CRUD) ---

class OrdenTrabajoViewSet(viewsets.ModelViewSet):
    queryset = OrdenTrabajo.objects.all()
    serializer_class = OrdenTrabajoSerializer
    
    @action(detail=True, methods=['post'])
    def finalizar(self, request, pk=None):
        orden = self.get_object()
        # Forzamos el guardado directo en la Base de Datos
        orden.completada = True
        orden.save()
        return Response({'status': 'orden finalizada', 'completada': True})


    

class ActividadViewSet(viewsets.ModelViewSet):
    queryset = Actividad.objects.all()
    serializer_class = ActividadSerializer

class BitacoraViewSet(viewsets.ModelViewSet):
    queryset = BitacoraActividad.objects.all()
    serializer_class = BitacoraSerializer

class TrabajadorViewSet(viewsets.ModelViewSet):
    # Esto permite al Admin ver la lista de todos los trabajadores registrados
    queryset = Trabajador.objects.all()
    serializer_class = TrabajadorSerializer
    
    # Filtro opcional para buscar por código: /api/trabajadores/?codigo=OP-505
    def get_queryset(self):
        queryset = Trabajador.objects.all()
        codigo = self.request.query_params.get('codigo', None)
        if codigo is not None:
            queryset = queryset.filter(codigo=codigo)
        return queryset

# --- VISTA PERSONALIZADA (Auto-Login) ---

@api_view(['POST'])
def login_operario(request):
    """
    Recibe: { "codigo": "OP-505", "nombre": "Juan Perez" }
    Lógica: Si el código existe, devuelve el usuario. Si no, lo CREA.
    """
    data = request.data
    codigo = data.get('codigo')
    nombre = data.get('nombre')

    # Validación básica
    if not codigo:
        return Response({"error": "El código es obligatorio"}, status=400)

    # Buscar o Crear (Magic!)
    trabajador, created = Trabajador.objects.get_or_create(
        codigo=codigo,
        defaults={'nombre': nombre or "Sin Nombre", 'rol': 'OPERARIO'}
    )

    # Si el usuario ya existía pero ahora nos mandan un nombre nuevo, actualizamos
    if not created and nombre and trabajador.nombre != nombre:
        trabajador.nombre = nombre
        trabajador.save()

    return Response({
        "id": trabajador.id,
        "codigo": trabajador.codigo,
        "nombre": trabajador.nombre,
        "rol": trabajador.rol
    })

@api_view(['POST'])
def login_admin(request):
    """
    Recibe: { "username": "admin", "password": "123" }
    Verifica credenciales reales de Django.
    """
    username = request.data.get('username')
    password = request.data.get('password')

    if not username or not password:
        return Response({"error": "Faltan credenciales"}, status=400)

    # Django verifica si el usuario existe y la contraseña es correcta
    user = authenticate(username=username, password=password)

    if user is not None:
        # Credenciales Correctas
        return Response({
            "mensaje": "Login Exitoso",
            "nombre": user.first_name or user.username, # Si no tiene nombre real, usa el usuario
            "rol": "ADMIN"
        })
    else:
        # Credenciales Incorrectas
        return Response({"error": "Usuario o contraseña incorrectos"}, status=401)
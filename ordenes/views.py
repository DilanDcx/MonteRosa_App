from rest_framework import viewsets, status
from rest_framework.decorators import api_view, action
from rest_framework.response import Response
from django.contrib.auth.models import User
from django.contrib.auth import authenticate
from datetime import timedelta
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny

# Importamos los modelos y serializers
from .models import OrdenTrabajo, Actividad, BitacoraActividad, Evidencia
from .serializers import (
    OrdenTrabajoSerializer, 
    ActividadSerializer, 
    BitacoraSerializer, 
    UserSerializer,
    EvidenciaSerializer
)

@api_view(['POST'])
@permission_classes([AllowAny])
def login_app(request):
    username = request.data.get('codigo_trabajador') 
    password = request.data.get('password')
    
    user = authenticate(username=username, password=password)
    
    if user is not None:
        token, _ = Token.objects.get_or_create(user=user)
        return Response({
            'token': token.key,
            'nombre': user.first_name if user.first_name else user.username,
            'codigo': user.username,
            'es_admin': user.is_superuser 
        }, status=200)
    else:
        return Response({'error': 'Código o contraseña incorrectos'}, status=400)

@api_view(['POST'])
@permission_classes([AllowAny])
def registro_app(request):
    codigo = request.data.get('codigo_trabajador')
    nombre = request.data.get('nombre')
    password = request.data.get('password')
    
    if User.objects.filter(username=codigo).exists():
        return Response({'error': 'Este código ya está registrado. Por favor, inicia sesión.'}, status=400)
        
    user = User.objects.create_user(username=codigo, password=password, first_name=nombre)
    token = Token.objects.create(user=user)
    
    return Response({
        'token': token.key,
        'nombre': user.first_name,
        'codigo': user.username,
        'es_admin': False
    }, status=201)

# --- VISTAS ESTÁNDAR (CRUD) ---

class OrdenTrabajoViewSet(viewsets.ModelViewSet):
    queryset = OrdenTrabajo.objects.all().order_by('-id')
    serializer_class = OrdenTrabajoSerializer
    
    @action(detail=True, methods=['post'])
    def finalizar(self, request, pk=None):
        orden = self.get_object()
        orden.estado = 'FINALIZADA'
        orden.save()
        return Response({'status': 'orden finalizada', 'estado': 'FINALIZADA'})

class ActividadViewSet(viewsets.ModelViewSet):
    queryset = Actividad.objects.all()
    serializer_class = ActividadSerializer

    @action(detail=True, methods=['post', 'patch'])
    def finalizar(self, request, pk=None):
        try:
            actividad = self.get_object()
            
            # 1. FECHAS EXACTAS
            fecha_inicio = request.data.get('fecha_inicio_real')
            fecha_fin = request.data.get('fecha_fin_real')
            if fecha_inicio: actividad.fecha_inicio_real = fecha_inicio
            if fecha_fin: actividad.fecha_fin_real = fecha_fin
                
            # 2. FIX DEL TIEMPO (Evita el error de "113000000")
            # Convertimos el string "01:30:00" a formato matemático de reloj para Django
            tiempo_total = request.data.get('tiempo_total') or request.data.get('tiempo_real_acumulado')
            if tiempo_total:
                horas, minutos, segundos = map(int, str(tiempo_total).split(':'))
                actividad.tiempo_real_acumulado = timedelta(hours=horas, minutes=minutos, seconds=segundos)
                
            tiempo_pausas = request.data.get('tiempo_pausas')
            if tiempo_pausas:
                horas_p, minutos_p, segundos_p = map(int, str(tiempo_pausas).split(':'))
                actividad.tiempo_pausas = timedelta(hours=horas_p, minutes=minutos_p, seconds=segundos_p)
                
            # 3. EJECUTOR
            ejecutor = request.data.get('nombre_ejecutor')
            if ejecutor: actividad.nombre_ejecutor = ejecutor

            notas = request.data.get('notas_operario')
            if notas: actividad.notas_operario = notas
                
            actividad.finished = True
            actividad.en_progreso = False
            
            actividad.save() 
            
            return Response({"mensaje": "¡Operación finalizada y tiempos registrados correctamente!"}, status=200)
            
        except Exception as e:
            return Response({"Error Interno de Python": str(e)}, status=400)

# --- CORRECCIÓN DE FOTOS: Agregamos AllowAny para que Flutter no sea bloqueado ---
class EvidenciaViewSet(viewsets.ModelViewSet):
    queryset = Evidencia.objects.all()
    serializer_class = EvidenciaSerializer
    permission_classes = [AllowAny] # LA LLAVE MÁGICA PARA LAS FOTOS
    
class BitacoraViewSet(viewsets.ModelViewSet):
    queryset = BitacoraActividad.objects.all()
    serializer_class = BitacoraSerializer

# --- VISTAS DE AUTENTICACIÓN (LOGIN) ---

@api_view(['POST'])
def login_operario(request):
    try:
        # Blindaje contra espacios en blanco
        codigo_bruto = request.data.get('codigo', '')
        codigo = str(codigo_bruto).strip() 
        
        password = request.data.get('password', '') 
        password_nueva = request.data.get('password_nueva')
        nombre = request.data.get('nombre')
        apellido = request.data.get('apellido')

        if not codigo:
            return Response({"error": "Código es requerido"}, status=400)

        try:
            # 1. SI EL USUARIO YA EXISTE
            user = User.objects.get(username__iexact=codigo)
            
            if not user.check_password(password):
                return Response({"error": "Contraseña incorrecta. Intenta de nuevo."}, status=400)
                
            token, _ = Token.objects.get_or_create(user=user)
            return Response({
                "token": token.key,
                "usuario": {
                    "username": user.username,
                    "first_name": user.first_name,
                    "last_name": user.last_name,
                }
            }, status=200)

        except User.DoesNotExist:
            # 2. SI ES UN USUARIO NUEVO
            if nombre and password_nueva:
                user = User(
                    username=codigo,
                    first_name=nombre,
                    last_name=apellido or ''
                )
                user.set_password(password_nueva) 
                user.save()
                
                token, _ = Token.objects.get_or_create(user=user)
                return Response({
                    "token": token.key,
                    "usuario": {
                        "username": user.username,
                        "first_name": user.first_name,
                        "last_name": user.last_name,
                    }
                }, status=200)
                
            else:
                tiene_ordenes = OrdenTrabajo.objects.filter(codigo_trabajador__iexact=codigo).exists()
                
                if tiene_ordenes:
                    return Response({"requiere_nombre": True, "codigo": codigo}, status=200)
                else:
                    return Response({"error": "El código no existe ni tiene órdenes asignadas en el sistema."}, status=400)
                    
    except Exception as e:
        return Response({"error": f"Error del servidor Django: {str(e)}"}, status=500)
            
@api_view(['POST'])
def login_admin(request):
    username = request.data.get('username')
    password = request.data.get('password')

    if not username or not password:
        return Response({"error": "Faltan credenciales"}, status=400)

    user = authenticate(username=username, password=password)

    if user is not None:
        return Response({
            "mensaje": "Login Exitoso",
            "usuario": UserSerializer(user).data,
            "rol": "ADMIN" if user.is_staff else "OPERARIO"
        })
    else:
        return Response({"error": "Usuario o contraseña incorrectos"}, status=401)
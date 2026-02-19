from rest_framework import serializers
from django.contrib.auth.models import User
from .models import OrdenTrabajo, Actividad, BitacoraActividad, Evidencia # <-- Importamos Evidencia

# 1. Serializer para Usuarios
class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'first_name', 'last_name', 'email']

# 2. Serializer para la Bitácora
class BitacoraSerializer(serializers.ModelSerializer):
    class Meta:
        model = BitacoraActividad
        fields = '__all__'

# 3. Serializer para Evidencias
class EvidenciaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Evidencia
        fields = '__all__'
        read_only_fields = ['fecha_subida']

# 4. Serializer para Actividades
class ActividadSerializer(serializers.ModelSerializer):
    bitacora = BitacoraSerializer(many=True, read_only=True)
    evidencias = EvidenciaSerializer(many=True, read_only=True, source='evidencia_set')

    class Meta:
        model = Actividad
        fields = '__all__'
        extra_kwargs = {
            'orden': {'read_only': True}
        }

# 5. Serializer para Órdenes
class OrdenTrabajoSerializer(serializers.ModelSerializer):
    actividades = ActividadSerializer(many=True, read_only=True)
    evidencias = EvidenciaSerializer(many=True, read_only=True) 

    class Meta:
        model = OrdenTrabajo
        fields = '__all__'
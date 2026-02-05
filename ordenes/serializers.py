from rest_framework import serializers
from .models import OrdenTrabajo, Actividad, BitacoraActividad, Trabajador

class TrabajadorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Trabajador
        fields = '__all__'

class BitacoraSerializer(serializers.ModelSerializer):
    class Meta:
        model = BitacoraActividad
        fields = '__all__'

class ActividadSerializer(serializers.ModelSerializer):
    bitacora = BitacoraSerializer(many=True, read_only=True)
    
    class Meta:
        model = Actividad
        fields = '__all__'
        # SOLUCIÓN CLAVE 1: Decimos que 'orden' es solo de lectura.
        # Así el validador no se queja si no viene en el JSON de Flutter.
        extra_kwargs = {
            'orden': {'read_only': True}
        }

class OrdenTrabajoSerializer(serializers.ModelSerializer):
    actividades = ActividadSerializer(many=True)

    class Meta:
        model = OrdenTrabajo
        fields = '__all__'
        # SOLUCIÓN CLAVE 2: Relajamos la validación del número de orden para ediciones
        extra_kwargs = {
            'numero_orden': {'validators': []}
        }

    # --- CREAR ---
    def create(self, validated_data):
        actividades_data = validated_data.pop('actividades', [])
        
        # Verificamos manualmente si el número existe (ya que quitamos el validador automático arriba)
        if OrdenTrabajo.objects.filter(numero_orden=validated_data['numero_orden']).exists():
            raise serializers.ValidationError({"numero_orden": "Este número de orden ya existe."})

        orden = OrdenTrabajo.objects.create(**validated_data)
        
        for act_data in actividades_data:
            # Aquí asignamos la orden manualmente. Como es read_only arriba, 
            # Django confía en que nosotros lo haremos aquí.
            Actividad.objects.create(orden=orden, **act_data)
            
        return orden

    # --- ACTUALIZAR ---
    def update(self, instance, validated_data):
        actividades_data = validated_data.pop('actividades', [])

        # Actualizamos campos normales
        instance.ubicacion = validated_data.get('ubicacion', instance.ubicacion)
        instance.ubicacion_tecnica = validated_data.get('ubicacion_tecnica', instance.ubicacion_tecnica)
        instance.proceso = validated_data.get('proceso', instance.proceso)
        instance.prioridad = validated_data.get('prioridad', instance.prioridad)
        instance.supervisor_nombre = validated_data.get('supervisor_nombre', instance.supervisor_nombre)
        instance.codigo_trabajador = validated_data.get('codigo_trabajador', instance.codigo_trabajador)
        instance.inicio_programado = validated_data.get('inicio_programado', instance.inicio_programado)
        instance.fin_programado = validated_data.get('fin_programado', instance.fin_programado)
        
        # Validación manual de duplicados al editar (solo si cambió el número)
        nuevo_numero = validated_data.get('numero_orden')
        if nuevo_numero and nuevo_numero != instance.numero_orden:
            if OrdenTrabajo.objects.filter(numero_orden=nuevo_numero).exists():
                raise serializers.ValidationError({"numero_orden": "Este número ya está en uso por otra orden."})
            instance.numero_orden = nuevo_numero
            
        instance.save()

        # Agregamos las NUEVAS actividades
        for act_data in actividades_data:
            # Si no tiene ID, es nueva
            if 'id' not in act_data:
                Actividad.objects.create(orden=instance, **act_data)
        
        return instance
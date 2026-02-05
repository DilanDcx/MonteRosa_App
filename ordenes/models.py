from django.db import models
from datetime import timedelta

class Trabajador(models.Model):
    ROLES = [('ADMIN', 'Administrador'), ('OPERARIO', 'Operario')]
    
    nombre = models.CharField(max_length=100)
    codigo = models.CharField(max_length=20, unique=True) # El ID de login
    rol = models.CharField(max_length=10, choices=ROLES, default='OPERARIO')

    def __str__(self):
        return f"{self.nombre} ({self.rol})"
    
class OrdenTrabajo(models.Model):
    # --- DATOS GENERALES (ADMIN) ---
    numero_orden = models.CharField(max_length=20, unique=True)
    fecha_creacion = models.DateField(auto_now_add=True) # Se pone sola la fecha de hoy
    
    # Datos del Supervisor
    supervisor_nombre = models.CharField(max_length=100)
    supervisor_codigo = models.CharField(max_length=20)
    
    # Asignación (Clave para que el trabajador vea su orden)
    codigo_trabajador = models.CharField(max_length=20, help_text="Código del operario asignado")
    
    # Ubicaciones y Proceso
    ubicacion = models.CharField(max_length=100) # Ej: Molinos
    ubicacion_tecnica = models.CharField(max_length=100) # Ej: M-204
    proceso = models.CharField(max_length=100) # Ej: Molienda
    
    # Planificación
    PRIORIDAD_CHOICES = [('ALTA', 'Alta'), ('MEDIA', 'Media'), ('BAJA', 'Baja')]
    prioridad = models.CharField(max_length=10, choices=PRIORIDAD_CHOICES, default='MEDIA')
    reserva = models.CharField(max_length=50, blank=True, null=True) # Materiales reservados
    
    inicio_programado = models.DateTimeField()
    fin_programado = models.DateTimeField()
    
    # Estado General de la Orden
    completada = models.BooleanField(default=False)

    def __str__(self):
        return f"Orden {self.numero_orden} - {self.codigo_trabajador}"

class Actividad(models.Model):
    orden = models.ForeignKey(OrdenTrabajo, related_name='actividades', on_delete=models.CASCADE)
    
    # --- DATOS DEL ADMIN ---
    codigo_actividad = models.CharField(max_length=10, editable=False) # Se llenará solo (0010, 0020)
    descripcion = models.TextField()
    area = models.CharField(max_length=50) # Ej: Eléctrica, Mecánica
    tiempo_planificado = models.DurationField(help_text="Formato HH:MM:SS") 
    
    # --- DATOS DEL TRABAJADOR (EJECUCIÓN) ---
    nombre_ejecutor = models.CharField(max_length=100, blank=True, null=True) # Quien la hizo realmente
    fecha_hora_inicio_real = models.DateTimeField(null=True, blank=True)
    fecha_hora_fin_real = models.DateTimeField(null=True, blank=True)
    
    # Cronómetro
    tiempo_real_acumulado = models.DurationField(default=timedelta(0)) # Suma de tiempos
    en_progreso = models.BooleanField(default=False) # ¿Está corriendo el reloj?
    ultima_pausa = models.DateTimeField(null=True, blank=True) # Para cálculos de pausas
    
    completada = models.BooleanField(default=False)
    notas_operario = models.TextField(blank=True, null=True) # Descripción opcional final

    def save(self, *args, **kwargs):
        # Lógica Mágica: Si no tiene código (0010), lo calculamos
        if not self.codigo_actividad:
            # Contamos cuántas actividades tiene esta orden y sumamos 1
            count = Actividad.objects.filter(orden=self.orden).count()
            # Formato: (count + 1) * 10 -> 1*10=10, 2*10=20...
            numero = (count + 1) * 10
            # Rellenamos con ceros: "0010", "0020"
            self.codigo_actividad = f"{numero:04d}" 
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.codigo_actividad} - {self.descripcion}"
class BitacoraActividad(models.Model):
    actividad = models.ForeignKey(Actividad, related_name='bitacora', on_delete=models.CASCADE)
    EVENTOS = [
        ('INICIO', 'Iniciado'),
        ('PAUSA', 'Pausado'),
        ('REANUDAR', 'Reanudado'),
        ('FINAL', 'Finalizado'),
    ]
    evento = models.CharField(max_length=20, choices=EVENTOS)
    fecha_hora = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.actividad.codigo_actividad} - {self.evento} - {self.fecha_hora}"
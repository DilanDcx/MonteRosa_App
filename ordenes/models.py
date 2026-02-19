from django.db import models
from datetime import timedelta
from django.contrib.auth.models import User

# 1. ORDEN DE TRABAJO (PADRE)
class OrdenTrabajo(models.Model):
    # Identificadores SAP
    numero_orden = models.CharField(max_length=20, unique=True, verbose_name="Número de Orden")
    descripcion = models.CharField(max_length=255, verbose_name="Texto Breve", null=True, blank=True)
    
    # Equipo y Ubicación
    equipo = models.CharField(max_length=50, verbose_name="Equipo", null=True, blank=True)
    descripcion_equipo = models.CharField(max_length=255, verbose_name="Desc. Equipo", null=True, blank=True)
    ubicacion = models.CharField(max_length=100, verbose_name="Ubicación Técnica", null=True, blank=True)
    ubicacion_tecnica = models.CharField(max_length=150, verbose_name="Desc. Ubicación", null=True, blank=True)
    
    # Fechas
    fecha_creacion = models.DateField(auto_now_add=True)
    inicio_programado = models.DateTimeField(null=True, blank=True, verbose_name="Inicio")
    fin_programado = models.DateTimeField(null=True, blank=True, verbose_name="Fin")

    # Gestión (Prioridad y Asignación)
   # Gestión (Prioridad y Asignación)
    PRIORIDAD_CHOICES = [
        ('1', '1-Muy alto'),
        ('2', '2-Alto'),
        ('3', '3-Medio'),
        ('4', '4-Bajo'),
    ]
    prioridad = models.CharField(
        max_length=2, 
        choices=PRIORIDAD_CHOICES, 
        default='4', # Ahora el default por si viene vacío será "4-Bajo"
        verbose_name="Prioridad"
    )
    
    codigo_trabajador = models.CharField(max_length=20, null=True, blank=True, verbose_name="Código Operario")
    supervisor = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, verbose_name="Asignado por")
    
    # --- NUEVO SISTEMA DE ESTADOS ---
    ESTADOS = [
        ('BORRADOR', 'Borrador (Revisión)'),   # Recién importada
        ('PENDIENTE', 'Pendiente (En App)'),   # Lista para trabajar
        ('FINALIZADA', 'Finalizada'),          # Terminada
    ]
    estado = models.CharField(max_length=20, choices=ESTADOS, default='BORRADOR', verbose_name="Estado Actual")
    
    # KPIs
    tiempo_total = models.DurationField(null=True, blank=True)
    fecha_fin_real = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.numero_orden} ({self.estado})"

# 2. ACTIVIDAD (HIJO)
class Actividad(models.Model):
    orden = models.ForeignKey(OrdenTrabajo, related_name='actividades', on_delete=models.CASCADE)
    codigo_operacion = models.CharField(max_length=10, verbose_name="Op.", null=True, blank=True)
    descripcion = models.TextField(verbose_name="Txt. Breve Op.")
    puesto_trabajo = models.CharField(max_length=20, verbose_name="Pto. Trabajo", null=True, blank=True)

    finished = models.BooleanField(default=False)
    tiempo_real_acumulado = models.DurationField(default=timedelta(0))
    en_progreso = models.BooleanField(default=False)
    ultima_pausa = models.DateTimeField(null=True, blank=True)
    notas_operario = models.TextField(blank=True, null=True)

    # --- CAMPOS DE TIEMPOS Y AUDITORÍA ---
    fecha_inicio_real = models.DateTimeField(null=True, blank=True, verbose_name="Inicio Real")
    fecha_fin_real = models.DateTimeField(null=True, blank=True, verbose_name="Fin Real")
    tiempo_real_acumulado = models.CharField(max_length=20, null=True, blank=True, verbose_name="Tiempo Activo")
    tiempo_pausas = models.CharField(max_length=20, null=True, blank=True, verbose_name="Tiempo en Pausa")
    nombre_ejecutor = models.CharField(max_length=100, null=True, blank=True, verbose_name="Ejecutor")
    finished = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.codigo_operacion} - {self.descripcion}"

# 3. BITACORA
class BitacoraActividad(models.Model):
    actividad = models.ForeignKey(Actividad, related_name='bitacora', on_delete=models.CASCADE)
    EVENTOS = [('INICIO', 'Iniciado'), ('PAUSA', 'Pausado'), ('REANUDAR', 'Reanudado'), ('FINAL', 'Finalizado')]
    evento = models.CharField(max_length=20, choices=EVENTOS)
    fecha_hora = models.DateTimeField(auto_now_add=True)

# 4. MODELOS PROXY (PARA EL MENÚ)
class OrdenBorrador(OrdenTrabajo):
    class Meta:
        proxy = True
        verbose_name = "1. Borradores"
        verbose_name_plural = "1. Borradores"

class OrdenPendiente(OrdenTrabajo):
    class Meta:
        proxy = True
        verbose_name = "2. Órdenes en Curso"
        verbose_name_plural = "2. Órdenes en Curso"

class OrdenHistorial(OrdenTrabajo):
    class Meta:
        proxy = True
        verbose_name = "3. Historial Finalizado"
        verbose_name_plural = "3. Historial Finalizado"

# 5. EVIDENCIAS FOTOGRÁFICAS
class Evidencia(models.Model):
    orden = models.ForeignKey(OrdenTrabajo, related_name='evidencias', on_delete=models.CASCADE)
    actividad = models.ForeignKey(Actividad, on_delete=models.CASCADE, null=True, blank=True)
    # Las fotos se guardarán ordenadas por año y mes en la carpeta /media/
    foto = models.ImageField(upload_to='evidencias/%Y/%m/', verbose_name="Fotografía")
    
    TIPOS = [
        ('ANTES', 'Antes del trabajo'),
        ('DURANTE', 'Durante el trabajo'),
        ('DESPUES', 'Trabajo finalizado')
    ]
    tipo = models.CharField(max_length=10, choices=TIPOS, default='DESPUES')
    descripcion = models.CharField(max_length=255, blank=True, null=True, verbose_name="Nota (Opcional)")
    fecha_subida = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.get_tipo_display()} - Orden {self.orden.numero_orden}"
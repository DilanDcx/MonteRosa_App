from django.contrib import admin
from .models import OrdenTrabajo, Actividad, OrdenPendiente, OrdenHistorial
from django.contrib.auth.admin import UserAdmin
from django.contrib.auth.models import User, Group

class ActividadInline(admin.TabularInline):
    model = Actividad
    extra = 1

admin.site.unregister(Group)
admin.site.unregister(User)

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    # Mostramos SOLO lo que importa: Código (username) y Nombre
    list_display = ('username', 'first_name', 'last_name' 'is_active')
    
    # Quitamos filtros complejos, dejamos solo si está activo
    list_filter = ('is_active',)
    
    # Buscador por código o nombre
    search_fields = ('username', 'first_name')
    
    # Renombramos las columnas para que se vea profesional en el panel
    def get_username(self, obj):
        return obj.username
    get_username.short_description = 'Código de Trabajador'

class ActividadInline(admin.TabularInline):
    model = Actividad
    extra = 1

@admin.register(OrdenPendiente)
class OrdenPendienteAdmin(admin.ModelAdmin):
    list_display = ('numero_orden', 'ubicacion', 'codigo_trabajador', 'prioridad', 'inicio_programado')
    list_filter = ('prioridad', 'ubicacion')
    search_fields = ('numero_orden', 'codigo_trabajador', 'ubicacion')
    
    # IMPORTANTE: Solo mostrar las NO completadas
    def get_queryset(self, request):
        return super().get_queryset(request).filter(completada=False)

    def get_progreso(self, obj):
        # Un pequeño indicador visual
        return "En Curso" if obj.en_progreso else "En Espera"
    get_progreso.short_description = "Estado"

@admin.register(OrdenHistorial)
class OrdenHistorialAdmin(admin.ModelAdmin):
    list_display = (
        'numero_orden', 
        'codigo_trabajador', 
        'prioridad', 
        'tiempo_total_formato',
        'tiempo_pausas',
        'fecha_fin_real' 
    )
    list_filter = ('ubicacion', 'prioridad', 'completada', 'fecha_fin_real')
    search_fields = ('numero_orden', 'codigo_trabajador')
    
    def tiempo_total_formato(self, obj):
        return str(obj.tiempo_total).split('.')[0] if obj.tiempo_total else "-"

    # Solo mostrar las completadas
    def get_queryset(self, request):
        return super().get_queryset(request).filter(completada=True)
    
    # Quitar permiso de agregar/borrar para proteger el historial 
    def has_add_permission(self, request):
        return False
    
# Inline para añadir actividades ahí mismo
class ActividadInline(admin.TabularInline):
    model = Actividad
    extra = 1  # Muestra 1 fila vacía lista para llenar
    min_num = 1 # Obliga a crear al menos una actividad
    fields = ('descripcion', 'area', 'tiempo_planificado') # Solo lo necesario para crear rápido
    classes = ['collapse'] # Opcional: permite colapsar si son muchas

# El Admin Principal (Solo para crear/editar todo)
@admin.register(OrdenTrabajo)
class OrdenAdmin(admin.ModelAdmin):
    # Organizar el formulario en secciones limpias
    fieldsets = (
        ("Información Clave", {
            "fields": (('numero_orden', 'prioridad'), 'ubicacion', 'proceso'),
            "classes": ('extrapretty',), # Estilo Jazzmin
        }),
        ("Asignación", {
            "fields": (('codigo_trabajador', 'supervisor_nombre'),),
        }),
        ("Programación", {
            "fields": (('inicio_programado', 'fin_programado'),),
        }),
        ("Estado (Sistema)", {
            "fields": ('completada',),
            "classes": ('collapse',), # Oculto por defecto para no estorbar
        }),
    )

    inlines = [ActividadInline]
    
    list_display = (
        'numero_orden', 
        'codigo_trabajador', 
        'prioridad', 
        'tiempo_total',
        'tiempo_pausas', 
        'fecha_fin_real'  
    )
    search_fields = ('numero_orden', 'ubicacion')
    list_editable = ('prioridad',) # Permite cambiar prioridad sin entrar a la orden
    
    # Autocompletar fecha de hoy automáticamente al crear
    def get_changeform_initial_data(self, request):
        from django.utils import timezone
        import datetime
        return {
            'inicio_programado': timezone.now(),
            'fin_programado': timezone.now() + datetime.timedelta(hours=4),
            'supervisor_nombre': request.user.get_full_name() or request.user.username
        }
    
try:
    admin.site.unregister(User)
except admin.site.NotRegistered:
    pass

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    # Columnas: Código (username), Nombre, Apellido, Email, ¿Es Staff?
    list_display = ('username', 'first_name', 'last_name', 'email', 'is_staff')
    
    # Quitamos filtros que puedan esconder gente. Solo dejamos filtro por "Staff"
    list_filter = ('is_staff', 'is_active')
    
    # Buscador
    search_fields = ('username', 'first_name', 'last_name')
    
    # Ordenar por el código (username)
    ordering = ('username',)
    
    # Cambiamos el título de la columna username
    def get_username(self, obj):
        return obj.username
    get_username.short_description = 'Código Trabajador'
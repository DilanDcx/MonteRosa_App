from django.contrib import admin
from .models import OrdenTrabajo, Actividad

class ActividadInline(admin.TabularInline):
    model = Actividad
    extra = 1

@admin.register(OrdenTrabajo)
class OrdenTrabajoAdmin(admin.ModelAdmin):
    list_display = ('numero_orden', 'codigo_trabajador', 'prioridad', 'inicio_programado')
    inlines = [ActividadInline] # Esto permite crear actividades DENTRO de la orden
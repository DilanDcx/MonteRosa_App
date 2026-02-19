from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    OrdenTrabajoViewSet, 
    ActividadViewSet, 
    BitacoraViewSet, 
    EvidenciaViewSet,
    login_operario, 
    login_admin,
    login_app,
    registro_app
)

router = DefaultRouter()
router.register(r'ordenes', OrdenTrabajoViewSet)
router.register(r'actividades', ActividadViewSet)
router.register(r'bitacora', BitacoraViewSet)
router.register(r'evidencias', EvidenciaViewSet)

urlpatterns = [
    # Las rutas del router (api/ordenes, api/actividades, etc.)
    path('', include(router.urls)),
    
    # Rutas manuales
    path('login-operario/', login_operario, name='login_operario'), 
    path('login-admin/', login_admin, name='login_admin'),
    path('login-app/', login_app, name='api_login'),
    path('registro-app/', registro_app, name='api_registro'),
]   
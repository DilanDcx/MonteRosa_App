from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import OrdenTrabajoViewSet, ActividadViewSet, BitacoraViewSet,TrabajadorViewSet, login_operario, login_admin

router = DefaultRouter()
router.register(r'ordenes', OrdenTrabajoViewSet)
router.register(r'actividades', ActividadViewSet)
router.register(r'bitacora', BitacoraViewSet)
router.register(r'trabajadores', TrabajadorViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('login-operario/', login_operario), 
    path('login-admin/', login_admin),
]
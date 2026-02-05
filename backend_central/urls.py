from django.contrib import admin
from django.urls import path, include  # <--- OJO: Agrega 'include' aquí

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('ordenes.urls')), # <--- Agrega esta línea
]
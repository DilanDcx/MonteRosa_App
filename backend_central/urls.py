from django.contrib import admin
from django.urls import path, include  
from django.conf import settings
from django.conf.urls.static import static  

urlpatterns = [
    path('admin/', admin.site.urls),
    # Esta es la única puerta de entrada a las rutas de tu app
    path('api/', include('ordenes.urls')), 
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
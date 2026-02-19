from pathlib import Path
import os

# 1. DEFINIMOS BASE_DIR PRIMERO (Cimiento de la casa)
BASE_DIR = Path(__file__).resolve().parent.parent

# 2. SEGURIDAD
SECRET_KEY = 'django-insecure-ro%mzvgkvhxj4#j1zux79$q9=oy0#)wv6+xl$ubk2fgrc79u91'
DEBUG = True
ALLOWED_HOSTS = ['*']

# 3. APPS INSTALADAS
INSTALLED_APPS = [
    'jazzmin', # Panel bonito
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # Apps de terceros
    'rest_framework',
    'rest_framework.authtoken',
    'corsheaders',
    'import_export', # Para subir Excel
    # Mis Apps
    'ordenes',
]

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# 4. MIDDLEWARE
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware', # Recomendado para conectar con Flutter
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'backend_central.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'backend_central.wsgi.application'

# 5. BASE DE DATOS
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# 6. PASSWORD VALIDATORS
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',},
]

# 7. IDIOMA Y ZONA
LANGUAGE_CODE = 'es-ni' # Configurado para español Nicaragua (Opcional)
TIME_ZONE = 'America/Managua' # Ajusta a tu zona horaria
USE_I18N = True
USE_TZ = True

# 8. ARCHIVOS ESTÁTICOS (Ahora sí funciona porque BASE_DIR ya existe)
STATIC_URL = '/static/' 
STATICFILES_DIRS = [
    os.path.join(BASE_DIR, 'static'),
]

# 9. CONFIGURACIÓN VISUAL JAZZMIN
JAZZMIN_SETTINGS = {
    "site_title": "Monte Rosa Admin",
    "site_header": "Ingenio Monte Rosa",
    "site_brand": "Gestión Operativa",
    "welcome_sign": "Bienvenido al Panel de Control",
    "copyright": "Ingenio Monte Rosa S.A.",
    "search_model": ["ordenes.OrdenTrabajo", "auth.User"],

    "site_logo": "img/logo.png",
    "site_logo_classes": "img-circle bg-white p-1",
    
    "show_sidebar": True,
    "navigation_expanded": True,
    
    "icons": {
        "auth": "fas fa-users-cog",
        "auth.user": "fas fa-user",
        "ordenes.OrdenTrabajo": "fas fa-clipboard-list",
        "ordenes.OrdenPendiente": "fas fa-clock",
        "ordenes.OrdenHistorial": "fas fa-check-circle",
    },
}

JAZZMIN_UI_TWEAKS = {
    "theme": "darkly",
    "navbar": "navbar-warning navbar-dark",
    "sidebar": "sidebar-dark-warning",
    "brand_colour": "navbar-warning",
    "accent": "accent-warning",
    "button_classes": {
        "primary": "btn-warning",
        "secondary": "btn-secondary",
        "info": "btn-info",
        "warning": "btn-warning",
        "danger": "btn-danger",
        "success": "btn-success"
    }
}
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

CORS_ALLOW_ALL_ORIGINS = True # Permite que el celular/emulador se conecte
REST_FRAMEWORK = {
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny', # Temporalmente abierto para probar
    ]
}
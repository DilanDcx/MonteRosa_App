from pathlib import Path
import os

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = 'django-insecure-ro%mzvgkvhxj4#j1zux79$q9=oy0#)wv6+xl$ubk2fgrc79u91'

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

ALLOWED_HOSTS = ['*']

# Application definition

INSTALLED_APPS = [
    'jazzmin',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # Apps
    'rest_framework',
    'corsheaders',
    'ordenes',
]


# --- CONFIGURACIÓN VISUAL ---
JAZZMIN_SETTINGS = {
    "site_title": "Monte Rosa Admin",
    "site_header": "Ingenio Monte Rosa",
    "site_brand": "Gestión Operativa",
    "welcome_sign": "Bienvenido al Panel de Control",
    "copyright": "Ingenio Monte Rosa S.A.",
    "search_model": ["ordenes.OrdenTrabajo", "auth.User"],

    "site_logo": "img/logo.png",
    "site_logo_classes": "img-circle bg-white p-1",
    
    # Menú Lateral
    "show_sidebar": True,
    "navigation_expanded": True,
    
    # Iconos (FontAwesome 5)
    "icons": {
        "auth": "fas fa-users-cog",
        "auth.user": "fas fa-user",
        "auth.Group": "fas fa-users",
        "ordenes.OrdenTrabajo": "fas fa-clipboard-list",
        "ordenes.OrdenPendiente": "fas fa-clock",    # Icono reloj para pendientes
        "ordenes.OrdenHistorial": "fas fa-check-circle", # Icono check para historial
    },
}

JAZZMIN_UI_TWEAKS = {
    "theme": "darkly",   # Tema oscuro
    # "theme": "flatly", # Tema claro
    
    "navbar": "navbar-warning navbar-dark", # Barra superior Naranja
    "sidebar": "sidebar-dark-warning",      # Menú oscuro con detalles naranjas
    "brand_colour": "navbar-warning",
    "accent": "accent-warning",             # Detalles interactivos en naranja
    "button_classes": {
        "primary": "btn-warning",           # Botones principales naranjas
        "secondary": "btn-secondary",
        "info": "btn-info",
        "warning": "btn-warning",
        "danger": "btn-danger",
        "success": "btn-success"
    }
}

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
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


# Database
# https://docs.djangoproject.com/en/6.0/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}


# Password validation
# https://docs.djangoproject.com/en/6.0/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization
# https://docs.djangoproject.com/en/6.0/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/6.0/howto/static-files/

STATIC_URL = '/static/' 

STATICFILES_DIRS = [
    os.path.join(BASE_DIR, 'static'),
]

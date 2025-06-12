

from pathlib import Path
import os
import environ
# from decouple import config

env = environ.Env()
environ.Env.read_env()  # This will read the .env file

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = 'django-insecure-j_qx9!ldze)*tnpta9l7mpxnscq08im*i1$w(!jxa5-dg6j^7j'


RECAPTCHA_SECRET_KEY = env("RECAPTCHA_SECRET_KEY")

DEBUG = True

# ALLOWED_HOSTS = [
#     "m2viz.in",
#     "localhost",
#     "127.0.0.1",
#     "app",        # Docker service name
# ]
ALLOWED_HOSTS = ['*']


CSRF_TRUSTED_ORIGINS = ['http://localhost:3000', 'http://localhost:8000','http://localhost:80','http://m2viz.in']

CORS_EXPOSE_HEADERS=['Content-Type', 'X-CSRFToken']
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_SAMESITE = 'Lax'
CSRF_COOKIE_SAMESITE = 'Lax'
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = True


# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
      # external pacakges
    'rest_framework',
    'rest_framework.authtoken',
    'corsheaders',
    'm2viz'
]

MIDDLEWARE = [
    'django.middleware.common.CommonMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',    # <-- must be *above* CommonMiddleware
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'm2viz_dev.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]



CORS_ORIGIN_WHITELIST = [
    'http://localhost:3000',  # Replace with your Next.js frontend URL
    'http://localhost:8000',
]

CORS_ALLOW_CREDENTIALS = True
CORS_ORIGIN_ALLOW_ALL = True

CORS_ALLOW_ALL_ORIGINS = True  # Set to True for debugging (not recommended for production)
CORS_ALLOWED_ORIGINS = [

    'http://localhost:3000',  # Replace with your Next.js frontend URL
    'http://localhost:8000',
]

WSGI_APPLICATION = 'm2viz_dev.wsgi.application'




DATABASES = {
'default': {
    'ENGINE': 'django.db.backends.mysql',
    'NAME': env("DB_NAME"),
    'USER': env("DB_USER"),
    'PASSWORD': env("DB_PASSWORD"),
    'HOST': env("DB_HOST"),
    'PORT':3306,
    },
}

# Password validation
# https://docs.djangoproject.com/en/5.1/ref/settings/#auth-password-validators

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
# https://docs.djangoproject.com/en/5.1/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.1/howto/static-files/

STATIC_URL = 'static/'

# Default primary key field type
# https://docs.djangoproject.com/en/5.1/ref/settings/#default-auto-field

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
REST_FRAMEWORK = {
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ],
    
    "DEFAULT_SCHEMA_CLASS":"drf_spectacular.openapi.AutoSchema",
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.LimitOffsetPagination',
}
AWS_STORAGE_BUCKET_NAME=env("BUCKET_NAME_TEAM")
AWS_ACCESS_KEY_ID=env("S3_ACCESS_ID")
AWS_SECRET_ACCESS_KEY=env("S3_SECRET_KEY")
 
AWS_S3_REGION_NAME = "us-west-1"
AWS_S3_CUSTOM_DOMAIN = f"{AWS_STORAGE_BUCKET_NAME}.s3.amazonaws.com"
DEFAULT_FILE_STORAGE = "storages.backends.s3boto3.S3Boto3Storage"
MEDIA_URL = f"https://{AWS_S3_CUSTOM_DOMAIN}/"

AWS_DEFAULT_ACL = None  # Recommended for open access or permissions managed by IAM
AWS_S3_OBJECT_PARAMETERS = {
    'CacheControl': 'max-age=86400',  # Optional: for caching, set as needed
}


EMAIL_BACKEND = "django_ses.SESBackend"

AWS_SES_REGION_NAME = "us-west-1"

AWS_SES_REGION_ENDPOINT = f"email.{AWS_S3_REGION_NAME}.amazonaws.com"

DEFAULT_FROM_EMAIL = "info@ciods.in"

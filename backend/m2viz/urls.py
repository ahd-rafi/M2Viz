from django.urls import path
from . import views
from .views import *
from django.conf import settings
from django.conf.urls.static import static
from django.contrib.staticfiles.urls import staticfiles_urlpatterns


urlpatterns = [
   
    path('protein_p_output/', views.protein_p_output, name='poutpprotein_p_outputut'),
    path('protein_d_output/', views.protein_d_output, name='protein_d_output'),
    path('dnaoutput/',views.dnaoutput, name='dnaoutput'),
    path('contact_us/', contact_us),


]

urlpatterns += staticfiles_urlpatterns()

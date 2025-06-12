from django.core.mail import send_mail
from django.conf import settings

def send_custom_email(subject, message, recipient_list, from_email=None):
    from_email = from_email or settings.DEFAULT_FROM_EMAIL
    send_mail(subject, message, from_email, recipient_list, fail_silently=False)

RECIPIENT_LIST = {
                  "m2viz":['ahmadrafi.ciods@yenepoya.edu.in']
                }

                   
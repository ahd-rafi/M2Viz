from django.core.files.storage import FileSystemStorage
from django.shortcuts import render
import subprocess
import pandas as pd
from itertools import chain
from . import utils
import os
import mimetypes
from django.http import FileResponse
from urllib.parse import quote as urlquote
import base64
from io import BytesIO
import matplotlib.pyplot as plt
from . import R_utils
from django.template.context_processors import csrf
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
from django.http import HttpResponse
import json
from m2viz.utils import fetch_family_and_domains, convert_refseq_to_uniprot, get_fasta
from django.http import HttpResponse
from django.core.files.storage import FileSystemStorage
import pandas as pd
import base64
from rest_framework.decorators import api_view,permission_classes
from rest_framework.response import Response

from rest_framework.permissions import AllowAny
from django.conf import settings

from django.conf import settings
import ast
import requests
from emails.utils import send_custom_email, RECIPIENT_LIST






@csrf_exempt
def protein_p_output(request):
    if request.method == 'POST':
        if request.FILES.get('csv_file'):
            uploaded_file = request.FILES['csv_file']
            print(f"Uploaded file name: {uploaded_file.name}")

            dataa = pd.read_csv(uploaded_file).apply(lambda col: col.map(lambda x: x.strip() if isinstance(x, str) else x))
            print("CSV file successfully read into DataFrame")

            k = request.POST.get('ACCESSION', '').strip()
            features_raw = request.POST.get('feature_type', '')
        else:
            body = json.loads(request.body.decode('utf-8'))
            dataa = pd.DataFrame(body.get("data", []))
            k = body.get("ACCESSION", "").strip()
            features_raw = body.get("feature_type", "")

        if isinstance(features_raw, dict):
            features_dict = features_raw
        elif isinstance(features_raw, str):
            try:
                features_dict = json.loads(features_raw)
            except json.JSONDecodeError:
                features_dict = ast.literal_eval(features_raw)

        selected_features = [key for key, val in features_dict.items() if val]

        print("Full features dict:", features_dict)
        print("Selected features:", selected_features)

        if not k:
            print("ACCESSION is missing!")
            return JsonResponse({"error": "Missing 'ACCESSION' parameter."}, status=400)

        if k.startswith(("np_", "NP_", "xp_", "XP_")):
            acc = convert_refseq_to_uniprot(k)
            print(f"Converted RefSeq to UniProt: {acc}")
            df = fetch_family_and_domains(acc, selected_features)
        else:
            df = fetch_family_and_domains(k, selected_features)

        if not isinstance(df, pd.DataFrame):
            df = pd.DataFrame(df)

        print("DataFrame columns:", df.columns)

        if 'type' in df.columns:
            available_features = df['type'].unique().tolist()
        else:
            available_features = []

        unavailable_features = [feature for feature in selected_features if feature not in available_features]

        if unavailable_features:
            unavailable_features_str = ", ".join(unavailable_features)
            error_message = f"The selected feature ({unavailable_features_str}) is not available for the entered accession."
            print(error_message)
            return JsonResponse({"error": error_message}, status=400)

        print(df)

        try:
            df_dict = df.to_dict(orient="records")

            if 'PTM_Site' in dataa.columns:
                svg_bytes = R_utils.get_lollipop_ptm(dataa, df_dict)
            else:
                svg_bytes = R_utils.get_lollipop(dataa, df_dict)
            print("Lollipop plot generated successfully!")
        except Exception as e:
            print(f"❌ Error generating lollipop plot: {e}")
            return JsonResponse({"error": "Failed to generate plot."}, status=500)

        svg_base64 = f"data:image/svg+xml;base64,{base64.b64encode(svg_bytes).decode()}"

        response_data = {
            "plot_img_base64": svg_base64,
            "data": dataa.to_dict(orient="records"),
        }

        print("Sending JSON response")
        return JsonResponse(response_data, safe=False)

    print("Invalid request: No file uploaded or incorrect method.")
    return JsonResponse({"error": "No file uploaded or invalid request."}, status=400)









@csrf_exempt
def protein_d_output(request):
    if request.method == 'POST':
        if request.FILES.get('csv_file'):
            uploaded_file = request.FILES['csv_file']

            dataa = pd.read_csv(uploaded_file).apply(lambda col: col.map(lambda x: x.strip() if isinstance(x, str) else x))
      

            k = request.POST.get('ACCESSION', '').strip()
            features_raw = request.POST.get('feature_type', '')

        else:
            body = json.loads(request.body.decode('utf-8'))
            dataa = pd.DataFrame(body.get("data", []))
            k = body.get("ACCESSION", "").strip()
            features_raw = body.get("feature_type", "")

        if isinstance(features_raw, dict):
            features_dict = features_raw
        elif isinstance(features_raw, str):
            try:
                features_dict = json.loads(features_raw)
            except json.JSONDecodeError:
                features_dict = ast.literal_eval(features_raw)

        selected_features = [key for key, val in features_dict.items() if val]

        print("Full features dict:", features_dict)
        print("Selected features :", selected_features)

        if not k:
            return JsonResponse({"error": "Missing 'ACCESSION' parameter."}, status=400)

        if k.startswith(("np_", "NP_", "xp_", "XP_")):
            acc = convert_refseq_to_uniprot(k)
            df = fetch_family_and_domains(acc, selected_features)
        else:
            df = fetch_family_and_domains(k, selected_features)

        if not isinstance(df, pd.DataFrame):
            df = pd.DataFrame(df)

        print("DataFrame columns:", df.columns)

        if 'type' in df.columns:
            available_features = df['type'].unique().tolist()
        else:
            available_features = []

        unavailable_features = [feature for feature in selected_features if feature not in available_features]

        if unavailable_features:
            unavailable_features_str = ", ".join(unavailable_features)
            error_message = f"The selected feature ({unavailable_features_str}) is not available for the entered accession."
            print(error_message)
            return JsonResponse({"error": error_message}, status=400)

        print(df)

        try:
            df_dict = df.to_dict(orient="records")

            if 'PTM_Site' in dataa.columns:
                svg_bytes = R_utils.get_diff_lollipop_ptm(dataa, df_dict)
            else:
                svg_bytes = R_utils.get_diff_lollipop(dataa, df_dict)
        except Exception as e:
            print(f"❌ Error generating lollipop plot: {e}")
            return JsonResponse({"error": "Failed to generate plot."}, status=500)

        svg_base64 = base64.b64encode(svg_bytes.encode('utf-8')).decode('utf-8') if isinstance(svg_bytes, str) else base64.b64encode(svg_bytes).decode('utf-8')
        svg_base64 = f"data:image/svg+xml;base64,{svg_base64}"

        response_data = {
            "plot_img_base64": svg_base64,
            "data": dataa.to_dict(orient="records")
        }

        return JsonResponse(response_data, safe=False)

    return JsonResponse({"error": "No file uploaded or invalid request."}, status=400)

@csrf_exempt
def dnaoutput(request):
    if request.method == 'POST' :
        if request.FILES.get('csv_file'):
           uploaded_file = request.FILES['csv_file']
           print(f" Uploaded file name: {uploaded_file.name}")

           dataa = pd.read_csv(uploaded_file).apply(lambda col: col.map(lambda x: x.strip() if isinstance(x, str) else x))

           print(" CSV file successfully read into DataFrame")
           print(dataa.head())

           k = request.POST.get('ENSG')
           fasta, fasta_len = get_fasta(k)
        else:
            body = json.loads(request.body.decode('utf-8'))
            dataa = pd.DataFrame(body.get("data", []))
            k = body.get("ENSG", "").strip()


            if not k:
                return JsonResponse({"error": "Missing 'ENSG' parameter."}, status=400)


        if "Expression" in dataa.columns:
            plot_data = R_utils.get_diff_dna_plot(dataa, fasta_len) if 'SNV' in dataa.columns else R_utils.get_diff_dna_plot_meth(dataa, fasta_len)
        else:
            plot_data = R_utils.get_prof_dna_plot(dataa, fasta_len) if "SNV" in dataa.columns else R_utils.get_prof_dna_plot_meth(dataa, fasta_len)

        if not plot_data:
            return JsonResponse({'error': 'Plot generation failed'}, status=500)
            

        svg_base64 = base64.b64encode(plot_data.encode('utf-8')).decode('utf-8') if isinstance(plot_data, str) else base64.b64encode(plot_data).decode('utf-8')

        return JsonResponse({'plot_img_base64': f"data:image/svg+xml;base64,{svg_base64}"})

    return JsonResponse({'error': 'Invalid request'}, status=400)


@api_view(['POST'])
@permission_classes([AllowAny])
def contact_us(request):
    data = request.data  
    recaptcha_response = data.get("recaptcha_token") 

    # Verify reCAPTCHA before processing further
    if not verify_recaptcha(recaptcha_response):
        return Response({"error": "Invalid reCAPTCHA response"}, status=400)

    try:
        name = request.data.get("name")
        email = request.data.get("email")
        message =request. data.get("message")


        send_custom_email(
            subject=f"LOLLIPOP tool user query - Name: {name}",
             message = f"""
           

                You have received a new inquiry through the LOLLIPOP Tool Contact Form. Please find the details below:

                User Message:
                {message}

                User Information:
                Name : {name}
                Email: {email}

                [Please respond to the user directly at the email address provided above.]

                """,
        recipient_list=RECIPIENT_LIST["m2viz"]
             
        )

        return Response({"message": "Email sent successfully"}, status=200)

    except Exception as e:
        return Response({"error": str(e)}, status=500)

def verify_recaptcha(recaptcha_response):
    secret_key = settings.RECAPTCHA_SECRET_KEY
    url = "https://www.google.com/recaptcha/api/siteverify"
    data = {
        "secret": secret_key,
        "response": recaptcha_response,
    }

    response = requests.post(url, data=data)
    result = response.json()

    if response.status_code == 200:
        return result.get("success", False)
    return False
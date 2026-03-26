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

            dataa = pd.read_csv(uploaded_file).apply(
                lambda col: col.map(lambda x: x.strip() if isinstance(x, str) else x)
            )
            print("CSV file successfully read into DataFrame")

            k                       = request.POST.get('ACCESSION', '').strip()
            fasta_sequence          = request.POST.get('fasta_sequence', '').strip()
            plot_mode               = request.POST.get('plot_mode', 'uniprot').strip()
            features_raw            = request.POST.get('feature_type', '')
            selected_feat_types_raw = request.POST.get('selected_feature_types', '')

        else:
            body                    = json.loads(request.body.decode('utf-8'))
            dataa                   = pd.DataFrame(body.get("data", []))
            k                       = body.get("ACCESSION", "").strip()
            fasta_sequence          = body.get("fasta_sequence", "").strip()
            plot_mode               = body.get("plot_mode", "uniprot").strip()
            features_raw            = body.get("feature_type", "")
            selected_feat_types_raw = body.get("selected_feature_types", "")

        print("dataa columns:", dataa.columns.tolist())

        # ── Detect data type (PTM or SAAV) ───────────────────────────────────────────
        is_saav = 'SAAV_Site' in dataa.columns
        is_ptm  = 'PTM_Site'  in dataa.columns
        print(f"Data type detected — is_saav: {is_saav}, is_ptm: {is_ptm}")

        # ── CUSTOM MODE ──────────────────────────────────────────────────────────────
        if plot_mode == "custom":
            print("Custom mode activated for profile plot")

            if is_saav:
                required_cols = ["SAAV_Site", "Frequency"]
            else:
                required_cols = ["PTM_Site", "Frequency", "PTM"]

            missing = [c for c in required_cols if c not in dataa.columns]
            if missing:
                return JsonResponse(
                    {"error": f"Missing required columns: {', '.join(missing)}"},
                    status=400,
                )

            # ── Resolve seq_length_val ALWAYS ────────────────────────────────────────
            seq_length_val = None
            for col in ["Sequence Length", "Sequence.Length", "sequence_length"]:
                if col in dataa.columns:
                    seq_length_val = int(dataa[col].dropna().max())
                    print(f"Found sequence length in column '{col}': {seq_length_val}")
                    break

            if not seq_length_val:
                try:
                    site_col = "SAAV_Site" if is_saav else "PTM_Site"
                    max_pos = dataa[site_col].apply(
                        lambda x: int(''.join(filter(str.isdigit, str(x))))
                    ).max()
                    seq_length_val = int(max_pos) + 100
                    print(f"Inferred sequence length from site positions: {seq_length_val}")
                except Exception:
                    seq_length_val = 1000
                    print("Using fallback sequence length: 1000")

            feature_cols_present = all(
                c in dataa.columns for c in ["type", "description", "start", "end"]
            )
            print(f"Feature columns present in CSV: {feature_cols_present}")

            feature_rows = []

            if feature_cols_present:
                dataa["start"] = dataa["start"].astype(int)
                dataa["end"]   = dataa["end"].astype(int)

                selected_feat_types = []
                if selected_feat_types_raw and selected_feat_types_raw.strip():
                    try:
                        selected_feat_types = json.loads(selected_feat_types_raw)
                    except (json.JSONDecodeError, ValueError):
                        selected_feat_types = []

                print(f"User-selected feature types: {selected_feat_types}")

                if selected_feat_types:
                    dataa_filtered = dataa[dataa["type"].isin(selected_feat_types)].copy()
                else:
                    dataa_filtered = dataa.copy()

                if not dataa_filtered.empty:
                    accession_val = dataa["Accession"].iloc[0] if "Accession" in dataa.columns else "Custom"
                    print(f"Accession value: {accession_val}")

                    feature_rows = (
                        dataa_filtered[["type", "description", "start", "end"]]
                        .drop_duplicates()
                        .to_dict(orient="records")
                    )
                    for row in feature_rows:
                        row["Accession"]       = accession_val
                        row["Sequence Length"] = seq_length_val

                    print(f"Custom features extracted ({len(feature_rows)} rows):", feature_rows)
                else:
                    print("No rows after filtering — proceeding without features")
            else:
                print("No feature columns in CSV — generating plot without feature track")

            try:
                print("Sending seq_len to R:", seq_length_val)

                if is_saav:
                    svg_bytes = R_utils.get_lollipop(dataa, feature_rows, seq_len=seq_length_val)
                else:
                    svg_bytes = R_utils.get_lollipop_ptm(dataa, feature_rows, seq_len=seq_length_val)

                print("Custom profile lollipop plot generated successfully!")

            except Exception as e:
                print(f"Error generating custom profile lollipop plot: {e}")
                return JsonResponse({"error": "Failed to generate plot."}, status=500)

            svg_base64 = f"data:image/svg+xml;base64,{base64.b64encode(svg_bytes).decode()}"

            return JsonResponse(
                {"plot_img_base64": svg_base64, "data": dataa.to_dict(orient="records")},
                safe=False,
            )

        # ── UNIPROT MODE ─────────────────────────────────────────────────────────────
        features_dict = {}

        if plot_mode == "uniprot" and features_raw:
            if isinstance(features_raw, dict):
                features_dict = features_raw
            elif isinstance(features_raw, str) and features_raw.strip():
                try:
                    features_dict = json.loads(features_raw)
                except (json.JSONDecodeError, ValueError):
                    try:
                        features_dict = ast.literal_eval(features_raw)
                    except Exception:
                        features_dict = {}

        selected_features = [key for key, val in features_dict.items() if val]

        print("Full features dict:", features_dict)
        print("Selected features:", selected_features)

        if not k:
            print("ACCESSION is missing!")
            return JsonResponse({"error": "Missing 'ACCESSION' parameter."}, status=400)

        uniprot_seq_len = None  # always initialize

        if fasta_sequence:
            sequence, uniprot_seq_len = parse_fasta(fasta_sequence)
            print("Using custom FASTA sequence")
            df = pd.DataFrame(columns=["type", "start", "end", "description"])
        else:
            # resolve accession (RefSeq or UniProt)
            acc = k
            if k.startswith(("np_", "NP_", "xp_", "XP_")):
                acc = convert_refseq_to_uniprot(k)
                print(f"Converted RefSeq to UniProt: {acc}")

            df, uniprot_seq_len = fetch_family_and_domains(acc, selected_features)

            # if seq_len is None (happens when no features selected), re-fetch with Domain
            if uniprot_seq_len is None:
                print("uniprot_seq_len is None — re-fetching with Domain to get seq_len")
                _, uniprot_seq_len = fetch_family_and_domains(acc, ["Domain"])
                print(f"Re-fetched uniprot_seq_len: {uniprot_seq_len}")

        print(f"uniprot_seq_len: {uniprot_seq_len}")

        if not isinstance(df, pd.DataFrame):
            df = pd.DataFrame(df)

        print("DataFrame columns:", df.columns)

        if 'type' in df.columns:
            available_features = df['type'].unique().tolist()
        else:
            available_features = []

        unavailable_features = [f for f in selected_features if f not in available_features]
        if unavailable_features:
            error_message = f"The selected feature ({', '.join(unavailable_features)}) is not available for the entered accession."
            print(error_message)
            return JsonResponse({"error": error_message}, status=400)

        print(df)

        try:
            df_dict = df.to_dict(orient="records") if selected_features else []

            print("Sending seq_len to R:", uniprot_seq_len)

            if is_saav:
                svg_bytes = R_utils.get_lollipop(dataa, df_dict, seq_len=uniprot_seq_len)
            else:
                svg_bytes = R_utils.get_lollipop_ptm(dataa, df_dict, seq_len=uniprot_seq_len)

            print("Lollipop plot generated successfully!!!")

        except Exception as e:
            print(f"Error generating lollipop plot: {e}")
            return JsonResponse({"error": "Failed to generate plot."}, status=500)

        svg_base64 = f"data:image/svg+xml;base64,{base64.b64encode(svg_bytes).decode()}"

        return JsonResponse(
            {"plot_img_base64": svg_base64, "data": dataa.to_dict(orient="records")},
            safe=False,
        )

    print("Invalid request: No file uploaded or incorrect method.")
    return JsonResponse({"error": "No file uploaded or invalid request."}, status=400)

# ─────────────────────────────────────────────────────────────────────────────


@csrf_exempt
def protein_d_output(request):
    if request.method == 'POST':
        if request.FILES.get('csv_file'):
            uploaded_file = request.FILES['csv_file']
            print(f"Uploaded file name: {uploaded_file.name}")

            dataa = pd.read_csv(uploaded_file).apply(
                lambda col: col.map(lambda x: x.strip() if isinstance(x, str) else x)
            )
            print("CSV file successfully read into DataFrame")

            k                       = request.POST.get('ACCESSION', '').strip()
            plot_mode               = request.POST.get('plot_mode', 'uniprot').strip()
            features_raw            = request.POST.get('feature_type', '')
            selected_feat_types_raw = request.POST.get('selected_feature_types', '')

        else:
            body                    = json.loads(request.body.decode('utf-8'))
            dataa                   = pd.DataFrame(body.get("data", []))
            k                       = body.get("ACCESSION", "").strip()
            plot_mode               = body.get("plot_mode", "uniprot").strip()
            features_raw            = body.get("feature_type", "")
            selected_feat_types_raw = body.get("selected_feature_types", "")

        print("dataa columns:", dataa.columns.tolist())

        # ── Detect data type (PTM or SAAV) ───────────────────────────────────────────
        is_saav = 'SAAV_Site' in dataa.columns
        is_ptm  = 'PTM_Site'  in dataa.columns
        print(f"Data type detected — is_saav: {is_saav}, is_ptm: {is_ptm}")

        # ── CUSTOM MODE ──────────────────────────────────────────────────────────────
        if plot_mode == "custom":
            print("Custom mode activated for differential plot")

            if is_saav:
                required_cols = ["SAAV_Site", "Frequency", "Regulation"]
            else:
                required_cols = ["PTM_Site", "Frequency", "PTM", "Regulation"]

            missing = [c for c in required_cols if c not in dataa.columns]
            if missing:
                print(f"Missing columns: {missing}")
                return JsonResponse(
                    {"error": f"Missing required columns: {', '.join(missing)}"},
                    status=400,
                )

            # ── Resolve seq_length_val ALWAYS ────────────────────────────────────────
            seq_length_val = None
            for col in ["Sequence Length", "Sequence.Length", "sequence_length"]:
                if col in dataa.columns:
                    seq_length_val = int(dataa[col].dropna().max())
                    print(f"Found sequence length in column '{col}': {seq_length_val}")
                    break

            if not seq_length_val:
                try:
                    site_col = "SAAV_Site" if is_saav else "PTM_Site"
                    max_pos = dataa[site_col].apply(
                        lambda x: int(''.join(filter(str.isdigit, str(x))))
                    ).max()
                    seq_length_val = int(max_pos) + 100
                    print(f"Inferred sequence length from site positions: {seq_length_val}")
                except Exception:
                    seq_length_val = 1000
                    print("Using fallback sequence length: 1000")

            feature_cols_present = all(
                c in dataa.columns for c in ["type", "description", "start", "end"]
            )
            print(f"Feature columns present in CSV: {feature_cols_present}")

            feature_rows = []

            if feature_cols_present:
                dataa["start"] = dataa["start"].astype(int)
                dataa["end"]   = dataa["end"].astype(int)

                selected_feat_types = []
                if selected_feat_types_raw and selected_feat_types_raw.strip():
                    try:
                        selected_feat_types = json.loads(selected_feat_types_raw)
                    except (json.JSONDecodeError, ValueError):
                        selected_feat_types = []

                print(f"User-selected feature types: {selected_feat_types}")

                if selected_feat_types:
                    dataa_filtered = dataa[dataa["type"].isin(selected_feat_types)].copy()
                else:
                    dataa_filtered = dataa.copy()

                if not dataa_filtered.empty:
                    accession_val = dataa["Accession"].iloc[0] if "Accession" in dataa.columns else "Custom"
                    print(f"Accession value: {accession_val}")

                    feature_rows = (
                        dataa_filtered[["type", "description", "start", "end"]]
                        .drop_duplicates()
                        .to_dict(orient="records")
                    )
                    for row in feature_rows:
                        row["Accession"]       = accession_val
                        row["Sequence Length"] = seq_length_val

                    print(f"Custom features extracted ({len(feature_rows)} rows):", feature_rows)
                else:
                    print("No rows after filtering — proceeding without features")
            else:
                print("No feature columns in CSV — generating plot without feature track")

            try:
                print("Sending seq_len to R:", seq_length_val)

                if is_saav:
                    svg_bytes = R_utils.get_diff_lollipop(dataa, feature_rows, seq_len=seq_length_val)
                else:
                    svg_bytes = R_utils.get_diff_lollipop_ptm(dataa, feature_rows, seq_len=seq_length_val)

                print("Custom differential lollipop plot generated successfully!")

            except Exception as e:
                print(f"Error generating custom differential lollipop plot: {e}")
                return JsonResponse({"error": "Failed to generate plot."}, status=500)

            svg_base64 = (
                base64.b64encode(svg_bytes.encode('utf-8')).decode('utf-8')
                if isinstance(svg_bytes, str)
                else base64.b64encode(svg_bytes).decode('utf-8')
            )
            svg_base64 = f"data:image/svg+xml;base64,{svg_base64}"

            return JsonResponse(
                {"plot_img_base64": svg_base64, "data": dataa.to_dict(orient="records")},
                safe=False,
            )

        # ── UNIPROT MODE ─────────────────────────────────────────────────────────────
        features_dict = {}

        if plot_mode == "uniprot" and features_raw:
            if isinstance(features_raw, dict):
                features_dict = features_raw
            elif isinstance(features_raw, str) and features_raw.strip():
                try:
                    features_dict = json.loads(features_raw)
                except (json.JSONDecodeError, ValueError):
                    try:
                        features_dict = ast.literal_eval(features_raw)
                    except Exception:
                        features_dict = {}

        selected_features = [key for key, val in features_dict.items() if val]

        print("Full features dict:", features_dict)
        print("Selected features:", selected_features)

        if not k:
            return JsonResponse({"error": "Missing 'ACCESSION' parameter."}, status=400)

        uniprot_seq_len = None  # always initialize

        # resolve accession (RefSeq or UniProt)
        acc = k
        if k.startswith(("np_", "NP_", "xp_", "XP_")):
            acc = convert_refseq_to_uniprot(k)
            print(f"Converted RefSeq to UniProt: {acc}")

        df, uniprot_seq_len = fetch_family_and_domains(acc, selected_features)  # ← fixed: unpack tuple

        # if seq_len is None (no features selected), re-fetch with Domain
        if uniprot_seq_len is None:
            print("uniprot_seq_len is None — re-fetching with Domain to get seq_len")
            _, uniprot_seq_len = fetch_family_and_domains(acc, ["Domain"])
            print(f"Re-fetched uniprot_seq_len: {uniprot_seq_len}")

        print(f"uniprot_seq_len: {uniprot_seq_len}")

        if not isinstance(df, pd.DataFrame):
            df = pd.DataFrame(df)

        print("DataFrame columns:", df.columns)

        if 'type' in df.columns:
            available_features = df['type'].unique().tolist()
        else:
            available_features = []

        unavailable_features = [f for f in selected_features if f not in available_features]
        if unavailable_features:
            error_message = f"The selected feature ({', '.join(unavailable_features)}) is not available for the entered accession."
            print(error_message)
            return JsonResponse({"error": error_message}, status=400)

        print(df)

        try:
            df_dict = df.to_dict(orient="records") if selected_features else []

            print("Sending seq_len to R:", uniprot_seq_len)

            if is_saav:
                svg_bytes = R_utils.get_diff_lollipop(dataa, df_dict, seq_len=uniprot_seq_len)
            else:
                svg_bytes = R_utils.get_diff_lollipop_ptm(dataa, df_dict, seq_len=uniprot_seq_len)

            print("Differential lollipop plot generated successfully!!!")

        except Exception as e:
            print(f"Error generating lollipop plot: {e}")
            return JsonResponse({"error": "Failed to generate plot."}, status=500)

        svg_base64 = (
            base64.b64encode(svg_bytes.encode('utf-8')).decode('utf-8')
            if isinstance(svg_bytes, str)
            else base64.b64encode(svg_bytes).decode('utf-8')
        )
        svg_base64 = f"data:image/svg+xml;base64,{svg_base64}"

        return JsonResponse(
            {"plot_img_base64": svg_base64, "data": dataa.to_dict(orient="records")},
            safe=False,
        )

    print("Invalid request: No file uploaded or incorrect method.")
    return JsonResponse({"error": "No file uploaded or invalid request."}, status=400)



















@csrf_exempt
def dnaoutput(request):
    if request.method == 'POST':
        if request.FILES.get('csv_file'):
            uploaded_file = request.FILES['csv_file']
            print(f"Uploaded file name: {uploaded_file.name}")

            dataa = pd.read_csv(uploaded_file).apply(
                lambda col: col.map(lambda x: x.strip() if isinstance(x, str) else x)
            )
            print("CSV file successfully read into DataFrame")
            print(dataa.head())

            k         = request.POST.get('ENSG', '').strip()
            plot_mode = request.POST.get('plot_mode', 'ensg').strip()

        else:
            body      = json.loads(request.body.decode('utf-8'))
            dataa     = pd.DataFrame(body.get("data", []))
            k         = body.get("ENSG", "").strip()
            plot_mode = body.get("plot_mode", "ensg").strip()

        print(f"plot_mode: {plot_mode}")
        print("dataa columns:", dataa.columns.tolist())

        # ── Detect data type and plot type from columns ───────────────────────────
        is_snv   = 'SNV'              in dataa.columns
        is_methy = 'Methylation_Site' in dataa.columns
        is_diff  = 'Expression'       in dataa.columns
        print(f"is_snv: {is_snv}, is_methy: {is_methy}, is_diff: {is_diff}")

        # ── CUSTOM MODE ──────────────────────────────────────────────────────────
        if plot_mode == "custom":
            print("Custom mode activated for DNA plot")

            # Validate required columns based on data type
            if is_snv:
                required_cols = ["SNV", "Frequency"]
                if is_diff:
                    required_cols.append("Expression")
            elif is_methy:
                required_cols = ["Methylation_Site", "Frequency"]
                if is_diff:
                    required_cols.append("Expression")
            else:
                return JsonResponse(
                    {"error": "Could not detect data type. CSV must have 'SNV' or 'Methylation_Site' column."},
                    status=400,
                )

            # Sequence Length required in custom mode
            required_cols.append("Sequence Length")

            missing = [c for c in required_cols if c not in dataa.columns]
            if missing:
                print(f"Missing columns: {missing}")
                return JsonResponse(
                    {"error": f"Missing required columns for custom mode: {', '.join(missing)}"},
                    status=400,
                )

            # Get sequence length from CSV
            seq_length_val = None
            for col in ["Sequence Length", "Sequence.Length", "sequence_length"]:
                if col in dataa.columns:
                    seq_length_val = int(dataa[col].dropna().max())
                    print(f"Found sequence length in column '{col}': {seq_length_val}")
                    break

            if not seq_length_val:
                return JsonResponse(
                    {"error": "Could not determine sequence length from CSV."},
                    status=400,
                )

            fasta_len = seq_length_val

        # ── ENSG MODE ────────────────────────────────────────────────────────────
        else:
            if not k:
                return JsonResponse({"error": "Missing 'ENSG' parameter."}, status=400)

            fasta, fasta_len = get_fasta(k)
            print(f"ENSG: {k}, fasta_len: {fasta_len}")

        # ── Route to correct R function ──────────────────────────────────────────
        try:
            if is_diff:
                if is_snv:
                    plot_data = R_utils.get_diff_dna_plot(dataa, fasta_len)
                else:
                    plot_data = R_utils.get_diff_dna_plot_meth(dataa, fasta_len)
            else:
                if is_snv:
                    plot_data = R_utils.get_prof_dna_plot(dataa, fasta_len)
                else:
                    plot_data = R_utils.get_prof_dna_plot_meth(dataa, fasta_len)

            print("DNA plot generated successfully!")

        except Exception as e:
            print(f"Error generating DNA plot: {e}")
            return JsonResponse({"error": "Failed to generate plot."}, status=500)

        if not plot_data:
            return JsonResponse({'error': 'Plot generation failed'}, status=500)

        svg_base64 = (
            base64.b64encode(plot_data.encode('utf-8')).decode('utf-8')
            if isinstance(plot_data, str)
            else base64.b64encode(plot_data).decode('utf-8')
        )

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
def parse_fasta(fasta_text):

    lines = fasta_text.strip().split("\n")

    if lines[0].startswith(">"):
        sequence = "".join(lines[1:])
    else:
        sequence = "".join(lines)

    sequence = sequence.replace(" ", "").replace("\r", "")
    return sequence, len(sequence)




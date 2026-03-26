
import json
import requests
import pandas as pd
import io
import base64
import environ

env = environ.Env()
environ.Env.read_env()

# ─────────────────────────────────────────────────────────────────────────────
# Helper: encode a DataFrame to a base64 CSV string (replaces S3 upload)
# ─────────────────────────────────────────────────────────────────────────────
def df_to_b64(df: pd.DataFrame) -> str:
    buf = io.StringIO()
    df.to_csv(buf, index=False)
    return base64.b64encode(buf.getvalue().encode("utf-8")).decode("utf-8")


# ─────────────────────────────────────────────────────────────────────────────
# All plot helpers — now just encode the df and POST directly to R
# ─────────────────────────────────────────────────────────────────────────────

def get_lollipop(df, conf=None, seq_len=None):
    params = {
    "csv_b64": df_to_b64(df),
    "conf": conf if conf else []
}

# fallback: get seq length from feature data
    if seq_len is None and conf:
        try:
            seq_len = conf[0].get("Sequence Length")
        except:
            seq_len = None

    if seq_len is not None:
        params["seq_len"] = seq_len

    print("Final params keys:", list(params.keys()))
    print("Sending seq_len to R:", seq_len)
    try:
        resp = requests.post(
            f"{env('LOLLIPOP_EXTERNAL_URL')}/get_prot_saav_prof", json=params
        )
        resp.raise_for_status()
        return resp.content
    except requests.exceptions.RequestException as e:
        return str(e).encode("utf-8")

def get_lollipop_ptm(df, conf=None, seq_len=None):

    params = {
        "csv_b64": df_to_b64(df),
        "conf": conf if conf else []
    }

    # Only fall back to conf if seq_len was NOT explicitly provided
    if seq_len is None and conf:
        try:
            seq_len = conf[0].get("Sequence Length")
        except Exception:
            seq_len = None

    if seq_len is not None:
        params["seq_len"] = int(seq_len)

    print("Final params keys:", list(params.keys()))
    print("Sending seq_len to R:", seq_len)

    try:
        resp = requests.post(
            f"{env('LOLLIPOP_EXTERNAL_URL')}/get_prot_ptm_prof",
            json=params
        )
        resp.raise_for_status()
        return resp.content

    except requests.exceptions.RequestException as e:
        return str(e).encode("utf-8")


def get_diff_lollipop(df, conf=None, seq_len=None):
    params = {
        "csv_b64": df_to_b64(df),
        "conf": conf if conf else [],
    }
    if seq_len is not None:
        params["seq_len"] = seq_len
    print("params keys:", list(params.keys()))
    try:
        resp = requests.post(
            f"{env('LOLLIPOP_EXTERNAL_URL')}/get_prot_saav_diff", json=params
        )
        resp.raise_for_status()
        return resp.content
    except requests.exceptions.RequestException as e:
        return str(e).encode("utf-8")

def get_diff_lollipop_ptm(df, conf=None, seq_len=None):
    params = {
        "csv_b64": df_to_b64(df),
        "conf": conf if conf else [],
    }
    if seq_len is not None:
        params["seq_len"] = seq_len
    print("params keys:", list(params.keys()))
    try:
        resp = requests.post(
            f"{env('LOLLIPOP_EXTERNAL_URL')}/get_prot_ptm_diff", json=params
        )
        resp.raise_for_status()
        return resp.content
    except requests.exceptions.RequestException as e:
        return str(e).encode("utf-8")

def get_prof_dna_plot(df, fasta_len):
    params = {
        "csv_b64": df_to_b64(df),
        "ax": fasta_len,
    }
    print("params keys:", list(params.keys()))
    try:
        resp = requests.post(
            f"{env('LOLLIPOP_EXTERNAL_URL')}/get_dna_snv_prof", json=params
        )
        resp.raise_for_status()
        return resp.content
    except requests.exceptions.RequestException as e:
        return str(e).encode("utf-8")


def get_prof_dna_plot_meth(df, fasta_len):
    params = {
        "csv_b64": df_to_b64(df),
        "ax": fasta_len,
    }
    print("params keys:", list(params.keys()))
    try:
        resp = requests.post(
            f"{env('LOLLIPOP_EXTERNAL_URL')}/get_dna_methy_prof", json=params
        )
        resp.raise_for_status()
        return resp.content
    except requests.exceptions.RequestException as e:
        return str(e).encode("utf-8")


def get_diff_dna_plot(df, fasta_len):
    params = {
        "csv_b64": df_to_b64(df),
        "ax": fasta_len,
    }
    print("params keys:", list(params.keys()))
    try:
        resp = requests.post(
            f"{env('LOLLIPOP_EXTERNAL_URL')}/get_dna_snv_diff", json=params
        )
        resp.raise_for_status()
        return resp.content
    except requests.exceptions.RequestException as e:
        return str(e).encode("utf-8")


def get_diff_dna_plot_meth(df, fasta_len):
    params = {
        "csv_b64": df_to_b64(df),
        "ax": fasta_len,
    }
    print("params keys:", list(params.keys()))
    try:
        resp = requests.post(
            f"{env('LOLLIPOP_EXTERNAL_URL')}/get_dna_methy_diff", json=params
        )
        resp.raise_for_status()
        return resp.content
    except requests.exceptions.RequestException as e:
        return str(e).encode("utf-8")
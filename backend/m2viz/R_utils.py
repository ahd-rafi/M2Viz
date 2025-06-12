import json
import requests
import boto3
import pandas as pd
import io
import random
import string 
import base64
from django.shortcuts import render
import environ
import re

env = environ.Env()
environ.Env.read_env()

mybucket = env("S3_BUCKET")
s3 = boto3.resource('s3',
         aws_access_key_id=env("S3_ACCESS_ID"),
         aws_secret_access_key= env("S3_SECRET_KEY"))

def create_s3_object(df, object_id):
    csv_buffer = io.StringIO()
    df.to_csv(csv_buffer, index=False)
    try:
        s3.Object(mybucket, object_id).put(Body=csv_buffer.getvalue())
    except Exception as e:
        return str(e)

def delete_s3_object(object_id):
    try:
        s3.Object(mybucket, object_id).delete()
    except Exception as e:
        return str(e)



def get_lollipop(df, conf):
    id = ''.join(random.choices(string.ascii_lowercase + string.digits, k=15))
    object_id = id + "for_lollipop.csv"
    create_s3_object(df, object_id)
    
    params = {
        'object_id': object_id,
        'conf': conf


    }
    
    try:
        my_lollipop = requests.post(f"{env('LOLLIPOP_EXTERNAL_URL')}/get_prot_saav_prof", json=params)
        
        my_lollipop.raise_for_status()
        return my_lollipop.content
    except requests.exceptions.RequestException as e:
        return str(e).encode('utf-8')  # Ensure error is returned as bytes
    finally:
        delete_s3_object(object_id)



def get_lollipop_ptm(df, conf):
    id = ''.join(random.choices(string.ascii_lowercase + string.digits, k=15))
    object_id = id + "for_lollipop.csv"
    create_s3_object(df, object_id)
    
    params = {
        'object_id': object_id,
        'conf': conf
    }
    print('Final params: ', params)
    try:
        my_lollipop = requests.post(f"{env('LOLLIPOP_EXTERNAL_URL')}/get_prot_ptm_prof", json=params)
        my_lollipop.raise_for_status()
        print("plot generated")
        return my_lollipop.content

    except requests.exceptions.RequestException as e:
        print("❌ Error during POST to R service:", e)
        return str(e).encode('utf-8')
    finally:
        delete_s3_object(object_id)


def get_diff_lollipop(df, conf):
    id = ''.join(random.choices(string.ascii_lowercase + string.digits, k=15))
    
    object_id = id + "for_lollipop.csv"
    create_s3_object(df, object_id)
    
    params = {
        'object_id': object_id,
        'conf': conf,
    }

    print('NEW PARAMS HERE')
    print('params:', params)
    
    try:
        my_lollipop = requests.post(f"{env('LOLLIPOP_EXTERNAL_URL')}/get_prot_saav_diff", json=params)
        my_lollipop.raise_for_status()  # Raise an exception for HTTP errors
    except requests.exceptions.RequestException as e:
        return str(e)


    return my_lollipop.content

def get_diff_lollipop_ptm(df, conf):
    id = ''.join(random.choices(string.ascii_lowercase + string.digits, k=15))
    
    object_id = id + "for_lollipop.csv"
    create_s3_object(df, object_id)
    
    params = {
        'object_id': object_id,
        'conf': conf
    }

    # params['width_'] = [abs(val) for val in params['width_']]
    # params['height_'] = [abs(val) for val in params['height_']]
    # params['range_'] = [abs(val) for val in params['range_']]

    print('NEW PARAMS HERE')
    print('params:', params)
    
    try:
        my_lollipop = requests.post(f"{env('LOLLIPOP_EXTERNAL_URL')}/get_prot_ptm_diff", json=params)
        my_lollipop.raise_for_status()  # Raise an exception for HTTP errors
    except requests.exceptions.RequestException as e:
        return str(e)
    


    return my_lollipop.content

def get_prof_dna_plot(df, fasta_len):
    id = ''.join(random.choices(string.ascii_lowercase + string.digits, k=15))
    
    object_id = id + "for_lollipop.csv"
    create_s3_object(df, object_id)

    params = {
        'object_id': object_id,
        'ax': fasta_len,
    }

    print('NEW PARAMS HERE: ', params)
    try:
        my_lollipop = requests.post(f"{env('LOLLIPOP_EXTERNAL_URL')}/get_dna_snv_prof", json=params)
        my_lollipop.raise_for_status()  # Raise an exception for HTTP errors
    except requests.exceptions.RequestException as e:
        return str(e)

    return my_lollipop.content



def get_prof_dna_plot_meth(df, fasta_len):
    id = ''.join(random.choices(string.ascii_lowercase + string.digits, k=15))
    
    object_id = id + "for_lollipop.csv"
    create_s3_object(df, object_id)

    params = {
        'object_id': object_id,
        'ax': fasta_len,
    }

    print('NEW PARAMS HERE: ', params)
    try:
        my_lollipop = requests.post(f"{env('LOLLIPOP_EXTERNAL_URL')}/get_dna_methy_prof", json=params)

        
        my_lollipop.raise_for_status()
    except requests.exceptions.RequestException as e:
        return str(e)

    return my_lollipop.content

def get_diff_dna_plot(df, fasta_len):
    id = ''.join(random.choices(string.ascii_lowercase + string.digits, k=15))
    
    object_id = id + "for_lollipop.csv"
    create_s3_object(df, object_id)

    params = {
        'object_id': object_id,
        'ax': fasta_len,
    }

    print('NEW PARAMS HERE: ', params)
    try:
        my_lollipop = requests.post(f"{env('LOLLIPOP_EXTERNAL_URL')}/get_dna_snv_diff", json=params)
        my_lollipop.raise_for_status()
    except requests.exceptions.RequestException as e:
        return str(e)

    return my_lollipop.content

def get_diff_dna_plot_meth(df, fasta_len):
    id = ''.join(random.choices(string.ascii_lowercase + string.digits, k=15))
    
    object_id = id + "for_lollipop.csv"
    create_s3_object(df, object_id)

    params = {
        'object_id': object_id,
        'ax': fasta_len,
    }

    print('NEW PARAMS HERE: ', params)
    try:
        my_lollipop = requests.post(f"{env('LOLLIPOP_EXTERNAL_URL')}/get_dna_methy_diff", json=params)
        my_lollipop.raise_for_status()  # Raise an exception for HTTP errors
    except requests.exceptions.RequestException as e:
        return str(e)

    return my_lollipop.content

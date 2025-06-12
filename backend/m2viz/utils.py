
import json
import pandas as pd
from itertools import chain, cycle
import requests
from xml.etree import ElementTree





def fetch_family_and_domains(accession, types):
    """
    Fetch protein features from UniProt and return as a list of dictionaries
    for DataFrame creation.
    """
    base_url = f"https://rest.uniprot.org/uniprotkb/{accession}.json"
    
    try:
        response = requests.get(base_url)
        response.raise_for_status()
        
        data = response.json()
        
        # allowed_types = {"Region", "Domain", "Repeat", "Compositional bias", "Coiled coil", "Motif"}
        allowed_types = types
        print("utils allowed types: ", allowed_types)

        
        seqlength = data.get('sequence', {}).get('length')
        
        # List to store individual feature records
        feature_records = []
        
        # Process each feature
        for feature in data.get("features", []):
            feature_type = feature.get("type", "Unknown")
            
            if feature_type in allowed_types:
                description = feature.get("description", "No description")
                location = feature.get("location", {})
                start = location.get("start", {}).get("value")
                end = location.get("end", {}).get("value")
                
                # Only add if we have valid start and end positions
                if start and end and description:
                    feature_records.append({
                        'Accession': accession,
                        'type': feature_type,
                        'description': description,
                        'start': start,
                        'end': end,
                        'Sequence Length': seqlength
                    })
        
        return feature_records
    
    except requests.exceptions.RequestException as e:
        print(f"Network error fetching data for {accession}: {e}")
        return []
    except Exception as e:
        print(f"Unexpected error for {accession}: {e}")
        return []




def process_accessions(accession_list):
    """
    Process multiple accessions and return a combined DataFrame.
    """
    all_records = []
    
    for accession in accession_list:
        print(f"Processing {accession}...")
        records = fetch_family_and_domains(accession)
        all_records.extend(records)
    
    # Create DataFrame
    df = pd.DataFrame(all_records)
    
    # Ensure proper column order
    if not df.empty:
        column_order = ['Accession', 'type', 'description', 'start', 'end', 'Sequence Length']
        df = df[column_order]
    
    return df


def convert_refseq_to_uniprot(refseq_id):
    """Convert RefSeq Protein ID to UniProtKB/Swiss-Prot accession."""
    uniprot_acc = None

    url = f'https://rest.uniprot.org/uniprotkb/search?query=xref:{refseq_id}'
    
    try:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
        
        if data.get('results'):
            first_result = data['results'][0]
            uniprot_acc = first_result.get('primaryAccession')
            if uniprot_acc:
                print(f"Found UniProt mapping: {refseq_id} -> {uniprot_acc}")
            else:
                print(f"No UniProt accession for {refseq_id}")
        else:
            print(f"No results for {refseq_id}")
    
    except requests.RequestException as e:
        print(f"Error for {refseq_id}: {e}")
    
    return uniprot_acc


def get_fasta(ensg_id):
    url = f"https://rest.ensembl.org/sequence/id/{ensg_id}?content-type=text/x-fasta"
    response = requests.get(url)

    if response.status_code == 200:
        fasta_text = response.text
        
        lines = fasta_text.strip().split("\n")
        fasta_sequence = "".join(lines[1:])
        
        return fasta_sequence, len(fasta_sequence)

    return None, 0




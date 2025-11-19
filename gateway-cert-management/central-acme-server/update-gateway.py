#!/usr/bin/env python3
"""
Convert PKCS1 to PKCS8, PEM certs to JSON array, and create JSON payload
"""

import json
import subprocess
import sys
from pathlib import Path


def pkcs1_to_pkcs8(pkcs1_key_path):
    """Convert PKCS1 private key to PKCS8 format"""
    try:
        result = subprocess.run(
            ['openssl', 'pkcs8', '-topk8', '-inform', 'PEM', '-outform', 'PEM',
             '-nocrypt', '-in', pkcs1_key_path],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error converting key: {e.stderr}", file=sys.stderr)
        sys.exit(1)


def pem_to_json_array(cert_path):
    """Convert PEM certificate file to JSON array of single-line strings"""
    with open(cert_path, 'r') as f:
        content = f.read()

    certs = []
    current_cert = []
    in_cert = False

    for line in content.strip().split('\n'):
        line = line.rstrip('\r')

        if '-----BEGIN CERTIFICATE-----' in line:
            in_cert = True
            current_cert = [line]
        elif '-----END CERTIFICATE-----' in line:
            current_cert.append(line)
            # Join with literal \n (will become \\n in JSON)
            certs.append('\n'.join(current_cert))
            current_cert = []
            in_cert = False
        elif in_cert:
            current_cert.append(line)

    return certs


def create_json_payload(key_path, cert_path, keystoreid='00000000000000000000000000000002',
                       alias='myKey', key_type='EC'):
    """Create JSON payload with converted key and cert chain"""

    # Convert key to PKCS8
    pkcs8_key = pkcs1_to_pkcs8(key_path)

    # Convert key to single line with \n
    key_lines = [line for line in pkcs8_key.strip().split('\n')]
    private_key = '\n'.join(key_lines)

    # Convert certs to JSON array
    cert_chain = pem_to_json_array(cert_path)

    # Create payload
    payload = {
        "keys": [
            {
                "keystoreId": keystoreid,
                "alias": alias,
                "keyType": key_type,
                "usageTypes": ["SSL"],
                "pem": private_key,
                "certChain": cert_chain
            }
        ]
    }

    return payload


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 convert.py <key-file> <cert-file> [alias] [output-file]")
        print("Example: python3 convert.py private.key cert.crt myAlias output.json")
        sys.exit(1)

    key_path = sys.argv[1]
    cert_path = sys.argv[2]
    alias = sys.argv[3] if len(sys.argv) > 3 and not sys.argv[3].endswith('.json') else 'myKey'
    output_path = sys.argv[4] if len(sys.argv) > 4 else (sys.argv[3] if len(sys.argv) > 3 and sys.argv[3].endswith('.json') else 'key-bundle.json')

    # Validate input files exist
    if not Path(key_path).exists():
        print(f"Error: Key file not found: {key_path}", file=sys.stderr)
        sys.exit(1)

    if not Path(cert_path).exists():
        print(f"Error: Certificate file not found: {cert_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Converting key from PKCS1 to PKCS8...")
    print(f"Reading certificates from {cert_path}...")
    print(f"Using alias: {alias}")

    # Create payload
    payload = create_json_payload(key_path, cert_path, alias=alias)

    # Write to file
    with open(output_path, 'w') as f:
        json.dump(payload, f, indent=2)

    print(f"✓ Successfully created: {output_path}")
    print(f"  Alias: {alias}")
    print(f"  Key: PKCS8 format")
    print(f"  Certificates: {len(payload['keys'][0]['certChain'])} cert(s)")


if __name__ == '__main__':
    main()
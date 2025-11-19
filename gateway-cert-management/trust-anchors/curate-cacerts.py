#!/usr/bin/env python3
import subprocess
import re
import os
import sys
import shutil
from datetime import datetime

def check_revocation_methods(cert_alias, cacerts_path, password):
    """Check what revocation methods are available for a certificate"""
    temp_cert = f'/tmp/cert_check_{os.getpid()}.pem'
    try:
        export_cmd = ['keytool', '-exportcert', '-alias', cert_alias, 
                     '-keystore', cacerts_path, '-storepass', password, 
                     '-file', temp_cert, '-rfc']
        result = subprocess.run(export_cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            return 'ExportErr'
        
        if not os.path.exists(temp_cert):
            return 'NoFile'
        
        methods = []
        
        ocsp_cmd = ['openssl', 'x509', '-in', temp_cert, '-noout', '-ocsp_uri']
        result = subprocess.run(ocsp_cmd, capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip():
            methods.append('OCSP')
        
        crl_cmd = ['openssl', 'x509', '-in', temp_cert, '-noout', '-text']
        result = subprocess.run(crl_cmd, capture_output=True, text=True)
        if result.returncode == 0:
            if 'CRL Distribution Points' in result.stdout or 'crlDistributionPoints' in result.stdout:
                methods.append('CRL')
        
        return ','.join(methods) if methods else 'None'
            
    except Exception as e:
        return f'Err:{str(e)[:5]}'
    finally:
        if os.path.exists(temp_cert):
            os.remove(temp_cert)

def get_all_certs(cacerts_path, password="changeit"):
    """Parse all certificates from keystore"""
    cmd = ['keytool', '-list', '-v', '-keystore', cacerts_path, '-storepass', password]
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"Error: {result.stderr}", file=sys.stderr)
        return []
    
    certs = []
    alias = None
    owner_cn = None
    issuer_cn = None
    country = None
    expiry = None
    thumbprint = None
    
    for line in result.stdout.split('\n'):
        if 'Alias name:' in line:
            if alias and issuer_cn:
                cert_type = 'Root' if owner_cn == issuer_cn else 'Intermediate'
                certs.append({
                    'alias': alias,
                    'type': cert_type,
                    'country': country or 'N/A',
                    'issuer': issuer_cn,
                    'expiry': expiry or 'N/A',
                    'thumbprint': thumbprint or 'N/A'
                })
            
            alias = line.split(':')[1].strip()
            owner_cn = None
            issuer_cn = None
            country = None
            expiry = None
            thumbprint = None
            
        elif 'Owner:' in line and alias:
            country_match = re.search(r'C=([^,]+)', line)
            country = country_match.group(1) if country_match else 'N/A'
            owner_cn_match = re.search(r'CN=([^,]+)', line)
            owner_cn = owner_cn_match.group(1) if owner_cn_match else ''
            
        elif 'Issuer:' in line and alias:
            issuer_cn_match = re.search(r'CN=([^,]+)', line)
            issuer_cn = issuer_cn_match.group(1) if issuer_cn_match else 'N/A'
            
        elif 'SHA1:' in line and alias:
            sha1_match = re.search(r'SHA1:\s*([A-F0-9:]+)', line)
            if sha1_match:
                thumbprint = sha1_match.group(1)
            
        elif 'Valid from:' in line and alias:
            match = re.search(r'until:\s+\w{3}\s+(\w{3})\s+(\d+)\s+[\d:]+\s+\w+\s+(\d{4})', line)
            if match:
                month = match.group(1)
                day = match.group(2).zfill(2)
                year = match.group(3)[2:]
                expiry = f"{day}-{month}-{year}"
    
    if alias and issuer_cn:
        cert_type = 'Root' if owner_cn == issuer_cn else 'Intermediate'
        certs.append({
            'alias': alias,
            'type': cert_type,
            'country': country or 'N/A',
            'issuer': issuer_cn,
            'expiry': expiry or 'N/A',
            'thumbprint': thumbprint or 'N/A'
        })
    
    return certs

def list_cacerts(cacerts_path=None, password="changeit", check_revocation=False):
    """List all certificates in keystore"""
    if not cacerts_path:
        cacerts_path = "./cacerts.der"
    
    certs = get_all_certs(cacerts_path, password)
    
    if check_revocation:
        print("\n" + "┌" + "─"*72 + "┬" + "─"*8 + "┬" + "─"*6 + "┬" + "─"*52 + "┬" + "─"*13 + "┬" + "─"*42 + "┬" + "─"*12 + "┐")
        print(f"│ {'Alias':<70} │ {'Type':<6} │ {'Ctry':<4} │ {'Issuer':<50} │ {'Expires':<11} │ {'Thumbprint (SHA-1)':<40} │ {'RevCheck':<10} │")
        print("├" + "─"*72 + "┼" + "─"*8 + "┼" + "─"*6 + "┼" + "─"*52 + "┼" + "─"*13 + "┼" + "─"*42 + "┼" + "─"*12 + "┤")
    else:
        print("\n" + "┌" + "─"*72 + "┬" + "─"*8 + "┬" + "─"*6 + "┬" + "─"*62 + "┬" + "─"*13 + "┬" + "─"*42 + "┐")
        print(f"│ {'Alias':<70} │ {'Type':<6} │ {'Ctry':<4} │ {'Issuer':<60} │ {'Expires':<11} │ {'Thumbprint (SHA-1)':<40} │")
        print("├" + "─"*72 + "┼" + "─"*8 + "┼" + "─"*6 + "┼" + "─"*62 + "┼" + "─"*13 + "┼" + "─"*42 + "┤")
    
    cert_count = 0
    for cert in certs:
        cert_count += 1
        alias_display = cert['alias'][:67] + '...' if len(cert['alias']) > 70 else cert['alias']
        type_display = 'Root' if cert['type'] == 'Root' else 'Inter'
        country_display = cert['country'][:4]
        thumbprint_display = cert['thumbprint'][:40] if len(cert['thumbprint']) > 40 else cert['thumbprint']
        
        if check_revocation:
            print(f"\rChecking {cert_count}/{len(certs)}...{' '*50}", end='', flush=True)
            rev_methods = check_revocation_methods(cert['alias'], cacerts_path, password)
            issuer_display = cert['issuer'][:47] + '...' if len(cert['issuer']) > 50 else cert['issuer']
            print(f"\r│ {alias_display:<70} │ {type_display:<6} │ {country_display:<4} │ {issuer_display:<50} │ {cert['expiry']:<11} │ {thumbprint_display:<40} │ {rev_methods:<10} │")
        else:
            issuer_display = cert['issuer'][:57] + '...' if len(cert['issuer']) > 60 else cert['issuer']
            print(f"│ {alias_display:<70} │ {type_display:<6} │ {country_display:<4} │ {issuer_display:<60} │ {cert['expiry']:<11} │ {thumbprint_display:<40} │")
    
    if check_revocation:
        print("└" + "─"*72 + "┴" + "─"*8 + "┴" + "─"*6 + "┴" + "─"*52 + "┴" + "─"*13 + "┴" + "─"*42 + "┴" + "─"*12 + "┘")
    else:
        print("└" + "─"*72 + "┴" + "─"*8 + "┴" + "─"*6 + "┴" + "─"*62 + "┴" + "─"*13 + "┴" + "─"*42 + "┘")
    
    print(f"\nTotal certificates: {len(certs)}\n")

def remove_by_country(cacerts_path, password, country_code, output_path=None):
    """Remove all certificates from a specific country - creates new file"""
    if not cacerts_path:
        cacerts_path = "./cacerts.der"
    
    if not output_path:
        # Generate output filename with timestamp
        base, ext = os.path.splitext(cacerts_path)
        output_path = f"{base}.no-{country_code.lower()}{ext}"
    
    certs = get_all_certs(cacerts_path, password)
    to_remove = [c for c in certs if c['country'].upper() == country_code.upper()]
    
    if not to_remove:
        print(f"No certificates found with country code: {country_code}")
        return
    
    print(f"\nFound {len(to_remove)} certificate(s) from {country_code}:")
    for cert in to_remove:
        print(f"  - {cert['alias']} ({cert['issuer'][:50]})")
    
    confirm = input(f"\nCreate new keystore without {len(to_remove)} certificate(s)? (yes/no): ")
    if confirm.lower() not in ['yes', 'y']:
        print("Cancelled.")
        return
    
    # Copy original to new output file
    shutil.copy2(cacerts_path, output_path)
    print(f"Created new keystore: {output_path}")
    
    removed = 0
    for cert in to_remove:
        cmd = ['keytool', '-delete', '-alias', cert['alias'], 
               '-keystore', output_path, '-storepass', password]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"  ✓ Removed: {cert['alias']}")
            removed += 1
        else:
            print(f"  ✗ Failed to remove: {cert['alias']} - {result.stderr}")
    
    print(f"\nRemoved {removed}/{len(to_remove)} certificates.")
    print(f"Original file unchanged: {cacerts_path}")
    print(f"New file created: {output_path}\n")

def combine_keystores(src_path, target_path, out_path, src_pass="changeit", target_pass="changeit", out_pass="changeit"):
    """Combine two keystores into one"""
    print(f"\nCombining keystores:")
    print(f"  Source: {src_path}")
    print(f"  Target: {target_path}")
    print(f"  Output: {out_path}")
    
    shutil.copy2(target_path, out_path)
    print(f"  ✓ Created output from target")
    
    src_certs = get_all_certs(src_path, src_pass)
    print(f"  Found {len(src_certs)} certificates in source")
    
    out_certs = get_all_certs(out_path, out_pass)
    existing_aliases = {c['alias'] for c in out_certs}
    
    imported = 0
    skipped = 0
    temp_cert = '/tmp/combine_cert.pem'
    
    for cert in src_certs:
        alias = cert['alias']
        
        if alias in existing_aliases:
            new_alias = f"{alias}_imported"
            counter = 1
            while f"{alias}_imported_{counter}" in existing_aliases:
                counter += 1
            if counter > 1:
                new_alias = f"{alias}_imported_{counter}"
            print(f"  ⚠ Alias '{alias}' exists, using '{new_alias}'")
            alias = new_alias
        
        export_cmd = ['keytool', '-exportcert', '-alias', cert['alias'],
                     '-keystore', src_path, '-storepass', src_pass,
                     '-file', temp_cert, '-rfc']
        result = subprocess.run(export_cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"  ✗ Failed to export: {cert['alias']}")
            skipped += 1
            continue
        
        import_cmd = ['keytool', '-importcert', '-alias', alias,
                     '-keystore', out_path, '-storepass', out_pass,
                     '-file', temp_cert, '-noprompt']
        result = subprocess.run(import_cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print(f"  ✓ Imported: {cert['alias']}")
            imported += 1
            existing_aliases.add(alias)
        else:
            print(f"  ✗ Failed to import: {cert['alias']} - {result.stderr}")
            skipped += 1
    
    if os.path.exists(temp_cert):
        os.remove(temp_cert)
    
    print(f"\nCombine complete:")
    print(f"  Imported: {imported}")
    print(f"  Skipped: {skipped}")
    print(f"  Total in output: {len(existing_aliases)}\n")

def compare_keystores(path1, path2, pass1="changeit", pass2="changeit"):
    """Compare two keystores and show differences"""
    print(f"\nComparing keystores:")
    print(f"  File 1: {path1}")
    print(f"  File 2: {path2}\n")
    
    certs1 = get_all_certs(path1, pass1)
    certs2 = get_all_certs(path2, pass2)
    
    aliases1 = {c['alias'] for c in certs1}
    aliases2 = {c['alias'] for c in certs2}
    
    only_in_1 = aliases1 - aliases2
    only_in_2 = aliases2 - aliases1
    common = aliases1 & aliases2
    
    print("="*80)
    print(f"{'Summary':<40} {'Count':<10}")
    print("-"*80)
    print(f"{'Total in File 1':<40} {len(certs1):<10}")
    print(f"{'Total in File 2':<40} {len(certs2):<10}")
    print(f"{'Common (in both)':<40} {len(common):<10}")
    print(f"{'Only in File 1 (removed from 2)':<40} {len(only_in_1):<10}")
    print(f"{'Only in File 2 (new in 2)':<40} {len(only_in_2):<10}")
    print("="*80)
    
    if only_in_1:
        print(f"\n{len(only_in_1)} certificate(s) REMOVED (in File 1 but not in File 2):")
        for alias in sorted(only_in_1):
            cert = next(c for c in certs1 if c['alias'] == alias)
            print(f"  - {alias:<50} [{cert['country']}] {cert['issuer'][:40]}")
    
    if only_in_2:
        print(f"\n{len(only_in_2)} certificate(s) NEW (in File 2 but not in File 1):")
        for alias in sorted(only_in_2):
            cert = next(c for c in certs2 if c['alias'] == alias)
            print(f"  + {alias:<50} [{cert['country']}] {cert['issuer'][:40]}")
    
    if not only_in_1 and not only_in_2:
        print("\n✓ Keystores are identical (same certificates)")
    
    print()

def print_usage():
    print("""
Usage: python3 curate-cacerts.py [command] [options]

Commands:
  list                                List all certificates (default)
    -r, --check-revocation           Check revocation methods (OCSP/CRL)
    --keystore <path>                Keystore path (default: ./cacerts.der)
    --password <pass>                Keystore password (default: changeit)

  --remove <country_code>            Remove all certificates from a country
    --keystore <path>                Keystore path (default: ./cacerts.der)
    --password <pass>                Keystore password (default: changeit)
    --output <path>                  Output path (default: <keystore>.no-<country>)

  --combine <src> <target> <out>     Combine two keystores
    --src-pass <pass>                Source password (default: changeit)
    --target-pass <pass>             Target password (default: changeit)
    --out-pass <pass>                Output password (default: changeit)

  --compare <file1> <file2>          Compare two keystores
    --pass1 <pass>                   File 1 password (default: changeit)
    --pass2 <pass>                   File 2 password (default: changeit)

Examples:
  python3 curate-cacerts.py list
  python3 curate-cacerts.py list --check-revocation
  python3 curate-cacerts.py --remove GB --keystore cacerts.der
  python3 curate-cacerts.py --remove GB --keystore cacerts.der --output cacerts.no-gb.der
  python3 curate-cacerts.py --combine cacerts.der other.der combined.der
  python3 curate-cacerts.py --compare cacerts.der cacerts.no-gb.der
""")

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ['-h', '--help']:
        print_usage()
        return
    
    command = sys.argv[1]
    
    keystore = "./cacerts.der"
    password = "changeit"
    check_rev = False
    
    for i, arg in enumerate(sys.argv):
        if arg == '--keystore' and i+1 < len(sys.argv):
            keystore = sys.argv[i+1]
        elif arg == '--password' and i+1 < len(sys.argv):
            password = sys.argv[i+1]
        elif arg in ['-r', '--check-revocation']:
            check_rev = True
    
    if command == 'list':
        list_cacerts(keystore, password, check_rev)
    
    elif command == '--remove':
        if len(sys.argv) < 3:
            print("Error: Country code required")
            print("Usage: python3 curate-cacerts.py --remove <country_code>")
            return
        country_code = sys.argv[2]
        
        output_path = None
        for i, arg in enumerate(sys.argv):
            if arg == '--output' and i+1 < len(sys.argv):
                output_path = sys.argv[i+1]
        
        remove_by_country(keystore, password, country_code, output_path)
    
    elif command == '--combine':
        if len(sys.argv) < 5:
            print("Error: Source, target, and output paths required")
            print("Usage: python3 curate-cacerts.py --combine <src> <target> <out>")
            return
        
        src_path = sys.argv[2]
        target_path = sys.argv[3]
        out_path = sys.argv[4]
        
        src_pass = "changeit"
        target_pass = "changeit"
        out_pass = "changeit"
        
        for i, arg in enumerate(sys.argv):
            if arg == '--src-pass' and i+1 < len(sys.argv):
                src_pass = sys.argv[i+1]
            elif arg == '--target-pass' and i+1 < len(sys.argv):
                target_pass = sys.argv[i+1]
            elif arg == '--out-pass' and i+1 < len(sys.argv):
                out_pass = sys.argv[i+1]
        
        combine_keystores(src_path, target_path, out_path, src_pass, target_pass, out_pass)
    
    elif command == '--compare':
        if len(sys.argv) < 4:
            print("Error: Two keystore paths required")
            print("Usage: python3 curate-cacerts.py --compare <file1> <file2>")
            return
        
        path1 = sys.argv[2]
        path2 = sys.argv[3]
        
        pass1 = "changeit"
        pass2 = "changeit"
        
        for i, arg in enumerate(sys.argv):
            if arg == '--pass1' and i+1 < len(sys.argv):
                pass1 = sys.argv[i+1]
            elif arg == '--pass2' and i+1 < len(sys.argv):
                pass2 = sys.argv[i+1]
        
        compare_keystores(path1, path2, pass1, pass2)
    
    else:
        print(f"Unknown command: {command}")
        print_usage()

if __name__ == '__main__':
    main()
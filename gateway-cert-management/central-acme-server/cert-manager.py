#!/usr/bin/env python3
"""
Central ACME Server Certificate Manager
Manages certificates for multiple Layer7 API Gateway deployments
"""

import json
import logging
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional

import requests
import yaml

# Configure logging
logging.basicConfig(
    level=os.getenv('LOG_LEVEL', 'INFO'),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/cert-manager.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class GatewayClient:
    """Client for interacting with Layer7 API Gateway GraphQL API"""
    
    def __init__(self, gateway_config: Dict):
        self.name = gateway_config['name']
        self.url = gateway_config['url']
        self.username = gateway_config['username']
        self.password = gateway_config['password']
        self.verify_ssl = gateway_config.get('verify_ssl', False)
    
    def _get_basic_auth(self) -> str:
        """Generate base64 encoded Basic auth string"""
        import base64
        credentials = f"{self.username}:{self.password}"
        return base64.b64encode(credentials.encode()).decode()
        
    def graphql_request(self, query: str, variables: Dict = None) -> Dict:
        """Execute a GraphQL request against the gateway"""
        payload = {
            "query": query,
            "variables": variables or {}
        }
        
        headers = {
            "l7-passphrase": "layer7",
            "Authorization": f"Basic {self._get_basic_auth()}"
        }
        
        try:
            response = requests.post(
                self.url,
                json=payload,
                headers=headers,
                verify=self.verify_ssl,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"GraphQL request failed for {self.name}: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"Response status: {e.response.status_code}")
                logger.error(f"Response body: {e.response.text}")
            raise
    
    def generate_csr(self, alias: str, params: Dict) -> str:
        """Generate CSR from the gateway"""
        query = """
        mutation generateCSR($alias: String!, $params: CSRGenerateParamsInput!) {
            generateCSR(alias: $alias, params: $params) {
                csr {
                    pem
                    issuedTo
                }
            }
        }
        """
        
        variables = {
            "alias": alias,
            "params": params
        }
        
        logger.info(f"Generating CSR for alias '{alias}' on gateway '{self.name}'")
        result = self.graphql_request(query, variables)
        
        if 'errors' in result:
            raise Exception(f"CSR generation failed: {result['errors']}")
        
        csr_pem = result['data']['generateCSR']['csr']['pem']
        logger.info(f"CSR generated successfully for '{alias}' on '{self.name}'")
        return csr_pem
    
    def replace_cert_chain(self, alias: str, params: Dict) -> List[str]:
        """Replace certificate chain on the gateway"""
        query = """
        mutation replaceCertChain($alias: String!, $params: KeyCertChainParamsInput!) {
            replaceCertChain(alias: $alias, params: $params) {
                affectedKeyAliases
            }
        }
        """
        
        variables = {
            "alias": alias,
            "params": params
        }
        
        logger.info(f"Replacing certificate chain for alias '{alias}' on gateway '{self.name}'")
        result = self.graphql_request(query, variables)
        
        if 'errors' in result:
            raise Exception(f"Certificate replacement failed: {result['errors']}")
        
        affected = result['data']['replaceCertChain']['affectedKeyAliases']
        logger.info(f"Certificate replaced successfully. Affected aliases: {affected}")
        return affected


class CertificateManager:
    """Manages certificate lifecycle for multiple gateways"""
    
    def __init__(self, config_path: str = '/app/config.yaml'):
        self.config = self.load_config(config_path)
        self.lego_dir = Path('/app/.lego')
        self.cert_dir = self.lego_dir / 'certificates'
        self.cert_dir.mkdir(parents=True, exist_ok=True)
        
    def load_config(self, config_path: str) -> Dict:
        """Load configuration from YAML file and expand environment variables"""
        logger.info(f"Loading configuration from {config_path}")
        with open(config_path, 'r') as f:
            content = f.read()
        
        # Expand environment variables in the format ${VAR_NAME}
        import re
        def replace_env_var(match):
            var_name = match.group(1)
            value = os.getenv(var_name)
            if value is None:
                logger.warning(f"Environment variable {var_name} not found, using empty string")
                return ""
            return value
        
        content = re.sub(r'\$\{([^}]+)\}', replace_env_var, content)
        config = yaml.safe_load(content)
        
        logger.info(f"Loaded configuration for {len(config['gateways'])} gateway(s)")
        return config
    
    def check_cert_expiry(self, cert_path: Path, threshold_days: int) -> bool:
        """Check if certificate is expiring within threshold days"""
        if not cert_path.exists():
            logger.warning(f"Certificate not found: {cert_path}")
            return True
        
        try:
            result = subprocess.run(
                ['openssl', 'x509', '-enddate', '-noout', '-in', str(cert_path)],
                capture_output=True,
                text=True,
                check=True
            )
            
            # Parse expiry date: notAfter=Nov 17 12:34:56 2025 GMT
            expiry_str = result.stdout.strip().replace('notAfter=', '')
            expiry_date = datetime.strptime(expiry_str, '%b %d %H:%M:%S %Y %Z')
            days_until_expiry = (expiry_date - datetime.utcnow()).days
            
            logger.info(f"Certificate expires in {days_until_expiry} days: {cert_path}")
            return days_until_expiry <= threshold_days
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to check certificate expiry: {e}")
            return True
    
    def request_certificate_with_csr(self, domain: str, csr_pem: str, gateway_name: str) -> tuple:
        """Request certificate from ACME server using CSR"""
        email = os.getenv('ACME_EMAIL')
        dns_provider = os.getenv('ACME_DNS_PROVIDER', 'gcloud')
        ca_server = os.getenv('ACME_CA_SERVER', 'https://acme-v02.api.letsencrypt.org/directory')
        
        # Save CSR to file
        csr_path = self.cert_dir / f"{gateway_name}_{domain}.csr"
        with open(csr_path, 'w') as f:
            f.write(csr_pem)
        
        logger.info(f"Requesting certificate for {domain} using CSR from {gateway_name}")
        
        # Build lego command
        cmd = [
            'lego',
            '--accept-tos',
            '--email', email,
            '--dns', dns_provider,
            '--server', ca_server,
            '--csr', str(csr_path),
            '--path', str(self.lego_dir),
            'run'
        ]
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True,
                timeout=300
            )
            logger.info(f"Certificate obtained successfully for {domain}")
            logger.debug(f"Lego output: {result.stdout}")
            
            # Lego saves the cert with CSR naming
            cert_file = self.cert_dir / f"{domain}.crt"
            key_file = self.cert_dir / f"{domain}.key"
            
            return cert_file, key_file
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to obtain certificate: {e.stderr}")
            raise
        except subprocess.TimeoutExpired:
            logger.error("Certificate request timed out")
            raise
    
    def renew_certificate(self, domain: str) -> tuple:
        """Renew an existing certificate"""
        email = os.getenv('ACME_EMAIL')
        dns_provider = os.getenv('ACME_DNS_PROVIDER', 'gcloud')
        ca_server = os.getenv('ACME_CA_SERVER', 'https://acme-v02.api.letsencrypt.org/directory')
        
        logger.info(f"Renewing certificate for {domain}")
        
        cmd = [
            'lego',
            '--accept-tos',
            '--email', email,
            '--dns', dns_provider,
            '--server', ca_server,
            '--path', str(self.lego_dir),
            '-d', domain,
            'renew'
        ]
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True,
                timeout=300
            )
            logger.info(f"Certificate renewed successfully for {domain}")
            
            # Handle wildcard domain naming
            domain_file = domain.replace('*', '_')
            cert_file = self.cert_dir / f"{domain_file}.crt"
            key_file = self.cert_dir / f"{domain_file}.key"
            
            return cert_file, key_file
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to renew certificate: {e.stderr}")
            raise
    
    def pem_to_json_array(self, cert_path: Path) -> List[str]:
        """Convert PEM certificate file to JSON array"""
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
                certs.append('\n'.join(current_cert))
                current_cert = []
                in_cert = False
            elif in_cert:
                current_cert.append(line)
        
        return certs
    
    def process_gateway(self, gateway_config: Dict):
        """Process certificate renewal for a single gateway"""
        gateway_name = gateway_config['name']
        logger.info(f"Processing gateway: {gateway_name}")
        
        client = GatewayClient(gateway_config)
        
        for cert_config in gateway_config['certificates']:
            try:
                alias = cert_config['alias']
                domain = cert_config['domain']
                threshold_days = self.config.get('renewal_threshold_days', 30)
                
                logger.info(f"Checking certificate for domain '{domain}' with alias '{alias}'")
                
                # Check if certificate needs renewal
                domain_file = domain.replace('*', '_')
                cert_path = self.cert_dir / f"{domain_file}.crt"
                
                if not self.check_cert_expiry(cert_path, threshold_days):
                    logger.info(f"Certificate for {domain} is still valid, skipping renewal")
                    continue
                
                # Generate CSR from gateway
                csr_params = cert_config.get('csr_params', {
                    "subjectDn": f"cn={domain}",
                    "hashAlgorithm": "SHA256",
                    "subjectAlternativeNames": [
                        {"name": "DNS Name", "value": domain}
                    ]
                })
                
                csr_pem = client.generate_csr(alias, csr_params)
                
                # Request certificate using CSR
                cert_file, key_file = self.request_certificate_with_csr(
                    domain, csr_pem, gateway_name
                )
                
                # Convert certificate chain to array
                cert_chain = self.pem_to_json_array(cert_file)
                
                # Replace certificate on gateway
                replace_params = {
                    "certChain": cert_chain
                }
                
                affected = client.replace_cert_chain(alias, replace_params)
                logger.info(f"Successfully updated certificate for {domain} on {gateway_name}")
                logger.info(f"Affected key aliases: {affected}")
                
            except Exception as e:
                logger.error(f"Failed to process certificate {alias} for gateway {gateway_name}: {e}")
                continue
    
    def run(self):
        """Main execution loop"""
        check_interval = int(os.getenv('CHECK_INTERVAL', 86400))  # Default: 24 hours
        
        logger.info("Central ACME Server started")
        logger.info(f"Check interval: {check_interval} seconds")
        
        while True:
            try:
                logger.info("Starting certificate check cycle")
                
                for gateway_config in self.config['gateways']:
                    try:
                        self.process_gateway(gateway_config)
                    except Exception as e:
                        logger.error(f"Failed to process gateway {gateway_config.get('name', 'unknown')}: {e}")
                        continue
                
                logger.info(f"Certificate check cycle completed. Next check in {check_interval} seconds")
                time.sleep(check_interval)
                
            except KeyboardInterrupt:
                logger.info("Shutting down Central ACME Server")
                break
            except Exception as e:
                logger.error(f"Unexpected error in main loop: {e}")
                time.sleep(60)  # Wait before retrying


def main():
    """Entry point"""
    try:
        manager = CertificateManager()
        manager.run()
    except Exception as e:
        logger.error(f"Failed to start Certificate Manager: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()


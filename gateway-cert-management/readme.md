## Layer7 API Gateway ACME/Trusted Certs examples
This repository contains examples of how to use a central ACME client to update certificate chains on Layer7 API Gateways and how to set and configure your own trust anchors. This is an example only that is conceptual and does not represent a current or future product or feature from Broadcom. AI assistance has been used to generate some or all contents of this file. That includes, but is not limited to, new code, modifying existing code, stylistic edits.

### NOTE: the ACME Server example is tied to Google Cloud DNS as the provider, we do not plan to add additional providers.
### If you would like to test this with your own DNS provider you will need to update the central-acme-server with a DNS provider that is supported by [Lego](https://go-acme.github.io/lego/dns/index.html) (there are roughly 150)

```
┌─────────────────────────────┐
│  Central ACME Server        │
│  (Docker Container)         │
└──────────┬──────────────────┘
           │
           ├──► Let's Encrypt (ACME)
           ├──► Google Cloud DNS
           │
           ├──► Gateway Prod
           ├──► Gateway Staging
           └──► Gateway Dev
```

## Prerequisites
- Docker & Docker Compose (for ACME server)
- Kubernetes & Helm (for gateway deployment examples)
- Google Cloud account with DNS configured
- Layer7 API Gateway v11 license

### Trust Anchors
The Gateways in this example use the default cacerts list from Gateway v11.1.3 (JDK17). Check out [trust-anchors](./trust-anchors/readme.md) which has a python utility that reads, updates and combines certificate stores.

### 1. Central ACME Server (demo only)
A Docker-based solution for centrally managing TLS certificates across multiple Layer7 API Gateway deployments using ACME protocol (Let's Encrypt). Automatically generates CSRs from gateways, obtains signed certificates, and updates gateway keystores.

**Key Features:**
- Automatic certificate renewal before expiration
- Multi-gateway support from a single service
- Private keys never leave the gateway
- Example uses Google Cloud DNS for DNS-01 challenges
  - lego supports [roughly 150 providers](https://go-acme.github.io/lego/dns/index.html)
- Uses graphman to generate the CSR and replace the certificate chain

👉 See [central-acme-server](./central-acme-server/) for setup and usage.

### 2. Gateway Deployment
Kubernetes deployment examples for Layer7 API Gateway v11 using Helm and Kustomize. Includes configurations for deploying multiple gateway instances with custom certificates and licenses.

**What's Included:**
- Gateway values file
- Kustomization for creating license/bundles
- Deployment script for 3 Gateway Helm Chart releases
- Custom CA certificates bundle

⚠️ **Note**: This is for testing/demonstration purposes only.

👉 See [gateways](./gateways/) for deployment instructions.

### 3. Trusted Certificate Rotation
Examples for updating the default jdk cacerts list.

- Based on Container Gateway v11.1.3
- list,combine,remove certificates from a trust store
- Read and compare certificate stores

👉 See [trusted-cert-rotation](./trusted-cert-rotation/) for more details.

## Getting Started

### Quick Start - Certificate Management

1. **Deploy Gateways** (optional - skip if you have existing gateways):

The following steps will deploy 3 Gateway deployments using the Gateway Helm Chart.

- Add your license as license.xml to [./gateways/license](./gateways/license/) and configure hostnames
- Configure your gateways in [./gateways/deploy-gateways.sh](./gateways/deploy-gateways.sh)
```bash
cd gateways
./deploy-gateways.sh
```
- Check that your gateways are ready
```bash
kubectl get pods

NAME                               READY   STATUS    RESTARTS   AGE
gateway-dev-577b7cc65f-m94dn       1/1     Running   0          2m
gateway-prod-545d7fb66f-n99sw      1/1     Running   0          2m
gateway-staging-78d5d995dc-jmqdt   1/1     Running   0          2m
```

2. **Setup Central ACME Server**
- Configure environment file
- `cp ./central-acme-server/env.example ./central-acme-server/.env`
```
# ACME Configuration
ACME_EMAIL=test@example.com
ACME_DNS_PROVIDER=gcloud
ACME_CA_SERVER=https://acme-v02.api.letsencrypt.org/directory
# For testing, use staging: https://acme-staging-v02.api.letsencrypt.org/directory

# Google Cloud Credentials (for Google Cloud DNS challenge)
# https://go-acme.github.io/lego/dns/gcloud/
GCE_PROJECT=<gcp-project>
GCE_SERVICE_ACCOUNT_FILE=/app/gcp-service-account.json

# Certificate Management
CHECK_INTERVAL=86400  # Check every 24 hours (in seconds)
RENEWAL_THRESHOLD_DAYS=15  # Renew when less than 30 days until expiry

# Gateway Passwords (used in config.yaml)
GATEWAY_PROD_PASSWORD=7layer
GATEWAY_STAGING_PASSWORD=7layer
GATEWAY_DEV_PASSWORD=7layer

# Logging
LOG_LEVEL=INFO  # DEBUG, INFO, WARNING, ERROR, CRITICAL
```
- Update [config.yaml](./central-acme-server/config.yaml)
- `cd central-acme-server`
- `docker compose build`
- `docker compose up -d`

3. **Monitor Certificate Management**:
   ```bash
   docker compose logs -f
   ```
   ```log
   central-acme-server  | 2025-11-19 07:10:22,776 - __main__ - INFO - Loading configuration from /app/config.yaml
   central-acme-server  | 2025-11-19 07:10:22,779 - __main__ - INFO - Loaded configuration for 3 gateway(s)
   central-acme-server  | 2025-11-19 07:10:22,779 - __main__ - INFO - Central ACME Server started
   central-acme-server  | 2025-11-19 07:10:22,779 - __main__ - INFO - Check interval: 86400 seconds
   central-acme-server  | 2025-11-19 07:10:22,779 - __main__ - INFO - Starting certificate check cycle
   central-acme-server  | 2025-11-19 07:10:22,779 - __main__ - INFO - Processing gateway: gateway-prod
   central-acme-server  | 2025-11-19 07:10:22,779 - __main__ - INFO - Checking certificate for domain 'gateway-prod.brcmlabs.com' with alias 'ssl'
   central-acme-server  | 2025-11-19 07:10:22,779 - __main__ - WARNING - Certificate not found: /app/.lego/certificates/gateway-prod.brcmlabs.com.crt
   central-acme-server  | 2025-11-19 07:10:22,779 - __main__ - INFO - Generating CSR for alias 'ssl' on gateway 'gateway-prod'
   central-acme-server  | /usr/local/lib/python3.11/site-packages/urllib3/connectionpool.py:1097: InsecureRequestWarning: Unverified HTTPS request is being    made to host 'gateway-prod.brcmlabs.com'. Adding certificate verification is strongly advised. See: https://urllib3.readthedocs.io/en/latest/advanced-usage.   html#tls-warnings
   central-acme-server  |   warnings.warn(
   central-acme-server  | 2025-11-19 07:10:22,823 - __main__ - INFO - CSR generated successfully for 'ssl' on 'gateway-prod'
   central-acme-server  | 2025-11-19 07:10:22,823 - __main__ - INFO - Requesting certificate for gateway-prod.brcmlabs.com using CSR from gateway-prod
   central-acme-server  | 2025-11-19 07:10:44,100 - __main__ - INFO - Certificate obtained successfully for gateway-prod.brcmlabs.com
   central-acme-server  | 2025-11-19 07:10:44,101 - __main__ - INFO - Replacing certificate chain for alias 'ssl' on gateway 'gateway-prod'
   central-acme-server  | /usr/local/lib/python3.11/site-packages/urllib3/connectionpool.py:1097: InsecureRequestWarning: Unverified HTTPS request is being    made to host 'gateway-prod.brcmlabs.com'. Adding certificate verification is strongly advised. See: https://urllib3.readthedocs.io/en/latest/advanced-usage.   html#tls-warnings
   central-acme-server  |   warnings.warn(
   central-acme-server  | 2025-11-19 07:10:44,164 - __main__ - INFO - Certificate replaced successfully. Affected aliases: ['ssl']
   central-acme-server  | 2025-11-19 07:10:44,165 - __main__ - INFO - Successfully updated certificate for gateway-prod.brcmlabs.com on gateway-prod
   central-acme-server  | 2025-11-19 07:10:44,165 - __main__ - INFO - Affected key aliases: ['ssl']
   central-acme-server  | 2025-11-19 07:10:44,165 - __main__ - INFO - Processing gateway: gateway-staging
   central-acme-server  | 2025-11-19 07:10:44,165 - __main__ - INFO - Checking certificate for domain 'gateway-staging.brcmlabs.com' with alias 'ssl'
   central-acme-server  | 2025-11-19 07:10:44,165 - __main__ - WARNING - Certificate not found: /app/.lego/certificates/gateway-staging.brcmlabs.com.crt
   central-acme-server  | 2025-11-19 07:10:44,165 - __main__ - INFO - Generating CSR for alias 'ssl' on gateway 'gateway-staging'
   central-acme-server  | /usr/local/lib/python3.11/site-packages/urllib3/connectionpool.py:1097: InsecureRequestWarning: Unverified HTTPS request is being    made to host 'gateway-staging.brcmlabs.com'. Adding certificate verification is strongly advised. See: https://urllib3.readthedocs.io/en/latest/   advanced-usage.html#tls-warnings
   central-acme-server  |   warnings.warn(
   central-acme-server  | 2025-11-19 07:10:44,205 - __main__ - INFO - CSR generated successfully for 'ssl' on 'gateway-staging'
   central-acme-server  | 2025-11-19 07:10:44,206 - __main__ - INFO - Requesting certificate for gateway-staging.brcmlabs.com using CSR from gateway-staging
   central-acme-server  | 2025-11-19 07:11:07,248 - __main__ - INFO - Certificate obtained successfully for gateway-staging.brcmlabs.com
   central-acme-server  | 2025-11-19 07:11:07,248 - __main__ - INFO - Replacing certificate chain for alias 'ssl' on gateway 'gateway-staging'
   central-acme-server  | /usr/local/lib/python3.11/site-packages/urllib3/connectionpool.py:1097: InsecureRequestWarning: Unverified HTTPS request is being    made to host 'gateway-staging.brcmlabs.com'. Adding certificate verification is strongly advised. See: https://urllib3.readthedocs.io/en/latest/   advanced-usage.html#tls-warnings
   central-acme-server  |   warnings.warn(
   central-acme-server  | 2025-11-19 07:11:07,315 - __main__ - INFO - Certificate replaced successfully. Affected aliases: ['ssl']
   central-acme-server  | 2025-11-19 07:11:07,316 - __main__ - INFO - Successfully updated certificate for gateway-staging.brcmlabs.com on gateway-staging
   central-acme-server  | 2025-11-19 07:11:07,316 - __main__ - INFO - Affected key aliases: ['ssl']
   central-acme-server  | 2025-11-19 07:11:07,316 - __main__ - INFO - Processing gateway: gateway-dev
   central-acme-server  | 2025-11-19 07:11:07,316 - __main__ - INFO - Checking certificate for domain 'gateway-dev.brcmlabs.com' with alias 'ssl'
   central-acme-server  | 2025-11-19 07:11:07,316 - __main__ - WARNING - Certificate not found: /app/.lego/certificates/gateway-dev.brcmlabs.com.crt
   central-acme-server  | 2025-11-19 07:11:07,316 - __main__ - INFO - Generating CSR for alias 'ssl' on gateway 'gateway-dev'
   central-acme-server  | /usr/local/lib/python3.11/site-packages/urllib3/connectionpool.py:1097: InsecureRequestWarning: Unverified HTTPS request is being    made to host 'gateway-dev.brcmlabs.com'. Adding certificate verification is strongly advised. See: https://urllib3.readthedocs.io/en/latest/advanced-usage.   html#tls-warnings
   central-acme-server  |   warnings.warn(
   central-acme-server  | 2025-11-19 07:11:07,357 - __main__ - INFO - CSR generated successfully for 'ssl' on 'gateway-dev'
   central-acme-server  | 2025-11-19 07:11:07,357 - __main__ - INFO - Requesting certificate for gateway-dev.brcmlabs.com using CSR from gateway-dev
   central-acme-server  | 2025-11-19 07:11:23,521 - __main__ - INFO - Certificate obtained successfully for gateway-dev.brcmlabs.com
   central-acme-server  | 2025-11-19 07:11:23,521 - __main__ - INFO - Replacing certificate chain for alias 'ssl' on gateway 'gateway-dev'
   central-acme-server  | /usr/local/lib/python3.11/site-packages/urllib3/connectionpool.py:1097: InsecureRequestWarning: Unverified HTTPS request is being    made to host 'gateway-dev.brcmlabs.com'. Adding certificate verification is strongly advised. See: https://urllib3.readthedocs.io/en/latest/advanced-usage.   html#tls-warnings
   central-acme-server  |   warnings.warn(
   central-acme-server  | 2025-11-19 07:11:23,584 - __main__ - INFO - Certificate replaced successfully. Affected aliases: ['ssl']
   central-acme-server  | 2025-11-19 07:11:23,584 - __main__ - INFO - Successfully updated certificate for gateway-dev.brcmlabs.com on gateway-dev
   central-acme-server  | 2025-11-19 07:11:23,584 - __main__ - INFO - Affected key aliases: ['ssl']
   central-acme-server  | 2025-11-19 07:11:23,584 - __main__ - INFO - Certificate check cycle completed. Next check in 86400 seconds
   ```

4. **Call Gateways**:
```bash
curl https://gateway-prod.brcmlabs.com/helloworld -v
```
```
...
* Server certificate:
*  subject: CN=gateway-prod.brcmlabs.com
*  start date: Nov 19 06:12:13 2025 GMT
*  expire date: Feb 17 06:12:12 2026 GMT
*  subjectAltName: host "gateway-prod.brcmlabs.com" matched cert's "gateway-prod.brcmlabs.com"
*  issuer: C=US; O=Let's Encrypt; CN=R13
*  SSL certificate verify ok.
* using HTTP/1.x
> GET /helloworld HTTP/1.1
> Host: gateway-prod.brcmlabs.com
> User-Agent: curl/8.7.1
> Accept: */*
> 
* Request completely sent off
< HTTP/1.1 200 
< Content-Type: text/plain;charset=UTF-8
< Content-Length: 6
< Date: Wed, 19 Nov 2025 07:14:59 GMT
< Server: Layer7-API-Gateway
< 
* Connection #0 to host gateway-prod.brcmlabs.com left intact
Hello!%                                                  
```


## Use Cases
- **Automated Certificate Renewal**: Never manually update gateway certificates again
- **Multi-Environment Management**: Manage dev, staging, and production from one place
- **Let's Encrypt Integration**: Free, automated certificates with broad browser support






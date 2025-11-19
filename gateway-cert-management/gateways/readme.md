# Gateway Deployment Example
This folder contains example configurations for deploying Layer7 API Gateway instances on Kubernetes using Helm and Kustomize. AI assistance has been used to generate some or all contents of this file. That includes, but is not limited to, new code, modifying existing code, stylistic edits.

## Overview
This is a **demonstration setup only** for testing the central ACME server certificate management. Do not use this in production without fully understanding your DNS configuration, Gateway settings, and security requirements.

## Contents

- **`kustomization.yaml`**: Creates Kubernetes secrets for:
  - Gateway v11 license (`ssg-license`)
  - Hello World bundle (`hello-world-bundle`)
  - Custom trusted certificates (`cacerts`)

- **`deploy-gateways.sh`**: Deployment script that:
  1. Applies the kustomization to create secrets
  2. Deploys 3 gateway instances using Helm with different hostnames

- **`undeploy-gateways.sh`**: Removes 3 gateway instances and resources

- **`gateway-values.yaml`**: Helm values template for Gateway configuration
  1. Gateways are ephemeral (no mysql database) so there is no persistence on restart
  2. This is for demo use only.

- **`license/`**: Place your Gateway v11 license file here as `license.xml`

- **`trusted-certs/`**: Contains custom CA certificates bundle based on Gateway 11

- **`helloworld-bundle.json`**: Sample GraphMan bundle for testing

## Prerequisites
- Kubernetes cluster
- `kubectl` configured
- `helm` installed
- Layer7 Gateway Helm chart repository added:
  ```bash
  helm repo add layer7 https://caapim.github.io/apim-charts/
  helm repo update
  ```
- Gateway v11 license file

## Quick Start

### 1. Add Your License

Place your Gateway v11 license file in the [license](./license/) folder:

```bash
cp /path/to/your/license.xml license/license.xml
```

### 2. Configure Hostnames

Edit `deploy-gateways.sh` and update the `CLUSTER_HOSTNAME` values to match your environment:

```bash
export CLUSTER_HOSTNAME="gateway-prod.brcmlabs.com"
export CLUSTER_HOSTNAME="gateway-staging.brcmlabs.com"
export CLUSTER_HOSTNAME="gateway-dev.brcmlabs.com"
```

These hostnames should:
- Match your DNS configuration
- Be used in the central ACME server `config.yaml`
- Have DNS zones configured in Google Cloud DNS (or your DNS provider)

### 3. Deploy
Make the script executable and run it:

```bash
chmod +x deploy-gateways.sh
./deploy-gateways.sh
```

This will:
1. Create Kubernetes secrets via kustomization
2. Deploy three gateway instances:
   - `gateway-prod`
   - `gateway-staging`
   - `gateway-dev`

### 4. Verify Deployment
Check the gateway pods:

```bash
kubectl get pods -l app.kubernetes.io/name=gateway
```

Check the services:

```bash
kubectl get svc gateway-prod-ssg gateway-staging-ssg gateway-dev-ssg
```

## Integration with Central ACME Server
Once the gateways are deployed, configure them in the central ACME server's `config.yaml`:

```yaml
gateways:
  - name: gateway-prod
    url: https://gateway-prod.brcmlabs.com/graphman
    username: admin
    password: ${GATEWAY_PROD_PASSWORD}
    certificates:
      - alias: ssl
        domain: "gateway-prod.brcmlabs.com"
```

See the [central-acme-server](../central-acme-server/) folder for complete configuration.

## Undeploying

To remove the gateways:

```bash
helm uninstall gateway-prod gateway-staging gateway-dev
kubectl delete -k .
```

## Gateway Configuration

The `gateway-values.yaml` template includes:

- **Management**: GraphMan enabled for certificate management
- **Listen Ports**: HTTPS on 8443 and 9443
- **Custom Certificates**: Uses custom CA certificates bundle
- **Database**: Embedded MySQL database
- **Service**: LoadBalancer type for external access

## Important Notes

⚠️ **This is an example setup for testing/demonstration purposes only**

- The default passwords (`7layer`) should be changed for any real deployment
- SSL verification is disabled in the example - enable for production
- The LoadBalancer service type may incur costs in cloud environments
- DNS must be properly configured for your hostnames
- Gateway v11 license is required

## Skip This If...

You can skip this entire folder if:
- You already have existing Gateway deployments
  - <b>DO NOT</b> use this in production!!
- You're using a different deployment method
- You want to test against non-Kubernetes gateways

The central ACME server works with any Gateway deployment that has GraphMan enabled and is network-accessible.

## Related Documentation
- [Central ACME Server](../central-acme-server/) - Automated certificate management
- [Trusted Certificate Rotation](../trusted-cert-rotation/) - CA certificate management

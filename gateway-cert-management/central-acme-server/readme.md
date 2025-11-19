# Central ACME Server Example
An example Docker-based setup demonstrating how to centrally manage TLS certificates for multiple Layer7 API Gateway deployments using the ACME protocol (Let's Encrypt).

⚠️ **This is an example only** - Not production-ready. Use this as a starting point to understand the concepts and adapt to your specific environment and requirements.

## What This Example Demonstrates
- Generating Certificate Signing Requests (CSRs) from gateways via GraphQL
- Obtaining signed certificates from Let's Encrypt using DNS-01 challenges
- Updating gateway keystores with new certificates
- Managing multiple gateways from a single containerized service

The example keeps private keys on the gateway - CSRs are generated on the gateway using graphman.

## What's Included
- Example configuration for multiple gateways (prod, staging, dev)
- Scheduled certificate expiration checks
- Graphman CSR generation and certificate updates
- Google Cloud DNS integration for DNS-01 challenges
- Docker Compose setup for easy testing

## DNS Provider Configuration

This example is configured to use **Google Cloud DNS** as the DNS provider for ACME DNS-01 challenges. While this repository only includes the Google Cloud DNS configuration, the underlying [Lego ACME client](https://go-acme.github.io/lego/) supports approximately 150 DNS providers.

### Using Other DNS Providers
To use a different DNS provider (such as Cloudflare, AWS Route53, Azure DNS, etc.):

1. Review the [Lego DNS provider documentation](https://go-acme.github.io/lego/dns/) for your specific provider
2. Update the `ACME_DNS_PROVIDER` environment variable in `.env`
3. Add the provider-specific environment variables (API keys, tokens, etc.)
4. Update `docker-compose.yaml` to include the new environment variables

For example, to use Cloudflare instead of Google Cloud DNS, you would change:
- `ACME_DNS_PROVIDER=cloudflare`
- Add `CLOUDFLARE_EMAIL` and `CLOUDFLARE_API_KEY` environment variables

**Note**: We do not plan to add additional provider configurations to this repository. This is provided as a Google Cloud DNS example only.

## Getting Started
For complete setup instructions, prerequisites, and configuration details, see the [main README](../readme.md) in the root of this repository.

### Quick Reference
1. **Configure environment**: Copy `env.example` to `.env` and update with your credentials
2. **Configure gateways**: Edit `config.yaml` with your gateway URLs and certificate details
3. **Build and run**: `docker compose up -d`
4. **Monitor**: `docker compose logs -f`

## Requirements
- Docker & Docker Compose
- Google Cloud account with DNS zones configured (or another DNS provider)
- Layer7 API Gateway v11 with GraphMan enabled
- Gateway admin credentials

## Configuration Files
- **`env.example`**: Template for environment variables (DNS credentials, email, etc.)
- **`config.yaml`**: Gateway configurations and certificate settings
- **`docker-compose.yaml`**: Service orchestration
- **`Dockerfile`**: Container build configuration

## How It Works
1. Service checks certificate expiration dates on a scheduled interval
2. For certificates nearing expiration, a CSR is generated on the target gateway
3. The CSR is submitted to Let's Encrypt with a DNS-01 challenge
4. DNS records are automatically created/updated via the DNS provider API
5. Once validated, the signed certificate is obtained
6. The new certificate chain is applied to the gateway via GraphQL
7. Gateway automatically reloads with the new certificate

## Important Notes
- **Example Only**: This is not production-ready code
- **No Official Support**: Community example, not supported by Broadcom
- **Security Review Required**: Review and understand all code before use
- **Adapt to Your Needs**: This demonstrates concepts - you'll need to adapt it for your specific environment, security policies, and requirements
- **Test Thoroughly**: Always test in non-production environments first

## Related Documentation
- [Gateway Deployment Examples](../gateways/) - Deploy test gateways
- [Trusted Certificate Management](../trust-anchors/) - Manage CA certificates
- [Lego DNS Providers](https://go-acme.github.io/lego/dns/) - List of supported DNS providers

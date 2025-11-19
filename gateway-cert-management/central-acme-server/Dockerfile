# Multi-stage build for Central ACME Server
FROM python:3.11-slim as base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install lego ACME client
ARG LEGO_VERSION=v4.26.0
ARG TARGETARCH=amd64
RUN curl -L "https://github.com/go-acme/lego/releases/download/${LEGO_VERSION}/lego_${LEGO_VERSION}_linux_${TARGETARCH}.tar.gz" \
    | tar xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/lego

# Install Python dependencies
RUN pip install --no-cache-dir requests PyYAML

# Create working directory
WORKDIR /app

# Copy application files
COPY update-gateway.py /app/
COPY cert-manager.py /app/
COPY config.yaml /app/

# Create directories for certificates and configuration
RUN mkdir -p /app/.lego/certificates /app/logs

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Run as non-root user
RUN useradd -m -u 1000 acme && \
    chown -R acme:acme /app
USER acme

# Default command
CMD ["python3", "/app/cert-manager.py"]


# ESO-LocalStack Helm Chart

A multi-step Helm chart for installing External Secrets Operator (ESO) with LocalStack.

## Prerequisites

- Kubernetes cluster
- Helm 3.x
- kubectl configured

## Installation Steps

This chart requires installation in multiple steps to ensure proper ordering of dependencies.

### Step 1: Install LocalStack

First, install LocalStack which provides the local AWS services:

```powershell
# Update dependencies
helm dependency update

# Install with only LocalStack enabled
helm install my-eso-localstack . `
  --set localstack.enabled=true `
  --namespace default `
  --create-namespace
```

Wait for LocalStack to be ready:
```powershell
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=localstack -n default --timeout=120s
```

### Step 2: Install External Secrets Operator

Next, install the External Secrets Operator and configure it to use LocalStack:

```powershell
# Upgrade to enable ESO
helm upgrade my-eso-localstack . `
  --set localstack.enabled=true `
  --set externalSecrets.enabled=true `
  --namespace default `
  --reuse-values
```

Wait for ESO to be ready:
```powershell
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=my-eso-localstack,app.kubernetes.io/name=external-secrets -n default --timeout=120s
```

### Step 3: Create LocalStack Credentials

Create the credentials secret that ESO will use to connect to LocalStack:

```powershell
helm upgrade my-eso-localstack . `
  --set localstack.enabled=true `
  --set externalSecrets.enabled=true `
  --set credentials.enabled=true `
  --namespace default `
  --reuse-values
```

### Step 4: Install SecretStore

Create the SecretStore resource that connects ESO to LocalStack:

```powershell
helm upgrade my-eso-localstack . `
  --set localstack.enabled=true `
  --set externalSecrets.enabled=true `
  --set credentials.enabled=true `
  --set secretStore.enabled=true `
  --namespace default `
  --reuse-values
```

Verify SecretStore is ready:
```powershell
kubectl get secretstore localstack-secretstore -n default
```

### Step 5 (Optional): Create ExternalSecret

Create a test ExternalSecret to verify the setup:

First, create a secret in LocalStack:
```powershell
# Port-forward to LocalStack (run in separate terminal)
kubectl port-forward svc/my-eso-localstack 4566:4566 -n default

# Create a test secret using AWS CLI (with LocalStack endpoint)
aws --endpoint-url=http://localhost:4566 `
  secretsmanager create-secret `
  --name my-app-secret `
  --secret-string '{"username":"admin","password":"secret123"}' `
  --region eu-central-1
```

Then enable the ExternalSecret:
```powershell
helm upgrade my-eso-localstack . `
  --set localstack.enabled=true `
  --set externalSecrets.enabled=true `
  --set credentials.enabled=true `
  --set secretStore.enabled=true `
  --set externalSecret.enabled=true `
  --namespace default `
  --reuse-values
```

Verify the secret was synced:
```powershell
kubectl get externalsecret app-secret -n default
kubectl get secret my-app-credentials -n default
```

## Configuration

Key configuration values:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `localstack.enabled` | Enable LocalStack installation | `false` |
| `externalSecrets.enabled` | Enable External Secrets Operator | `false` |
| `credentials.enabled` | Create LocalStack credentials secret | `false` |
| `secretStore.enabled` | Create SecretStore resource | `false` |
| `externalSecret.enabled` | Create test ExternalSecret | `false` |

## Uninstallation

```powershell
helm uninstall my-eso-localstack -n default
```

Note: This will also uninstall the external-secrets-system namespace created by the ESO subchart.

## Customization

You can customize values by creating a custom values file:

```yaml
# custom-values.yaml
localstack:
  enabled: true
  startServices: "secretsmanager,s3,dynamodb"

credentials:
  enabled: true
  accessKeyId: mykey
  secretAccessKey: mysecret

secretStore:
  enabled: true
  region: us-east-1
```

Then install with:
```powershell
helm install my-eso-localstack . -f custom-values.yaml -n default
```

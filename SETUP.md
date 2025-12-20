# Local Kubernetes Setup with LocalStack and External Secrets Operator

This guide walks through setting up a local Kubernetes environment with LocalStack (local AWS) and External Secrets Operator to sync secrets from LocalStack Secrets Manager to Kubernetes.

## Prerequisites

- Kubernetes cluster (local, e.g., Docker Desktop, Minikube, or kind)
- Helm 3.x installed
- kubectl configured
- AWS CLI installed


## 2. Install LocalStack (Local AWS)

LocalStack provides a local AWS cloud stack for development and testing.

### Create LocalStack values file
Create `localstack-values.yaml`:
```yaml
service:
  type: NodePort

startServices: "secretsmanager,s3"
```

### Install LocalStack
```bash
# Add LocalStack Helm repository
helm repo add localstack https://localstack.github.io/helm-charts
helm repo update

# Install LocalStack
helm install localstack localstack/localstack -f localstack-values.yaml --create-namespace -n localstack

# Verify installation
kubectl get pods -n localstack
kubectl get svc -n localstack
```

### Port-forward LocalStack
```bash
kubectl port-forward -n localstack svc/localstack 4566:4566
```

Keep this running in a terminal for accessing LocalStack.

## 3. Create Secrets in LocalStack

### Configure AWS CLI for LocalStack
```powershell
# Set environment variables (PowerShell)
$env:AWS_ACCESS_KEY_ID="test"
$env:AWS_SECRET_ACCESS_KEY="test"
$env:AWS_DEFAULT_REGION="eu-central-1"


$env:AWS_PROFILE = "localstack"
```

### Create a test secret
```bash
# Create secret (use single quotes in PowerShell to avoid escaping issues)
aws --endpoint-url=http://localhost:4566 secretsmanager create-secret `
  --name my-app-secret `
  --secret-string '{"username":"admin","password":"supersecret123"}' `
  --region eu-central-1

# Verify secret
aws --endpoint-url=http://localhost:4566 secretsmanager list-secrets --region eu-central-1

# Get secret value
aws --endpoint-url=http://localhost:4566 secretsmanager get-secret-value `
  --secret-id my-app-secret `
  --region eu-central-1
```

## 4. Install External Secrets Operator

External Secrets Operator syncs secrets from external secret stores (like AWS Secrets Manager) to Kubernetes.

```bash
# Add External Secrets Helm repository
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install External Secrets Operator
helm install external-secrets `
  external-secrets/external-secrets `
  -n external-secrets-system `
  --create-namespace

# Verify installation
kubectl get pods -n external-secrets-system
```

## 5. Configure External Secrets for LocalStack

### Patch External Secrets to use LocalStack endpoint
Create `external-secrets-patch.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-secrets
  namespace: external-secrets-system
spec:
  template:
    spec:
      containers:
      - name: external-secrets
        env:
        - name: AWS_ENDPOINT_URL
          value: "http://localstack.localstack.svc.cluster.local:4566"
```

Apply the patch:
```bash
kubectl patch deployment external-secrets -n external-secrets-system --patch-file external-secrets-patch.yaml

# Wait for rollout
kubectl rollout status deployment/external-secrets -n external-secrets-system
```

### Create LocalStack credentials
Create `localstack-credentials.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: localstack-credentials
  namespace: default
type: Opaque
stringData:
  access-key-id: test
  secret-access-key: test
```

```bash
kubectl apply -f localstack-credentials.yaml
```

### Create SecretStore
Create `secretstore.yaml`:
```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: localstack-secretstore
  namespace: default
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: localstack-credentials
            key: access-key-id
          secretAccessKeySecretRef:
            name: localstack-credentials
            key: secret-access-key
  conditions:
  - namespaces:
    - default
  retrySettings:
    maxRetries: 5
    retryInterval: 10s
```

```bash
kubectl apply -f secretstore.yaml

# Verify SecretStore is valid
kubectl get secretstore localstack-secretstore
```

### Create ExternalSecret
Create `externalsecret.yaml`:
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: localstack-secretstore
    kind: SecretStore
  target:
    name: my-app-credentials
    creationPolicy: Owner
  dataFrom:
  - extract:
      key: my-app-secret
```

```bash
kubectl apply -f externalsecret.yaml

# Verify sync status
kubectl get externalsecret app-secret
# Should show: STATUS: SecretSynced, READY: True

# Check the synced Kubernetes secret
kubectl get secret my-app-credentials -o yaml
```

## 6. Verify the Setup

```bash
# Check ExternalSecret status
kubectl get externalsecret app-secret

# Decode and view the secret
kubectl get secret my-app-credentials -o jsonpath='{.data.username}' | base64 -d
kubectl get secret my-app-credentials -o jsonpath='{.data.password}' | base64 -d
```

## Troubleshooting

### Check External Secrets Operator logs
```bash
kubectl logs -n external-secrets-system deployment/external-secrets --tail=50
```

### Verify LocalStack connectivity
```bash
kubectl port-forward -n localstack svc/localstack 4566:4566

# In another terminal
aws --endpoint-url=http://localhost:4566 secretsmanager list-secrets --region eu-central-1
```



## Cleanup

```bash
# Uninstall External Secrets Operator
helm uninstall external-secrets -n external-secrets-system
kubectl delete namespace external-secrets-system

# Uninstall LocalStack
helm uninstall localstack -n localstack
kubectl delete namespace localstack

# Delete secrets and configurations
kubectl delete externalsecret app-secret
kubectl delete secretstore localstack-secretstore
kubectl delete secret localstack-credentials
kubectl delete secret my-app-credentials
```

## Notes

- LocalStack Community edition is free but has limited services
- For production, use real AWS Secrets Manager with proper IAM roles
- The `AWS_ENDPOINT_URL` environment variable tells External Secrets Operator to use LocalStack instead of real AWS
- Secrets are automatically synced based on the `refreshInterval` setting (default: 1h)
- Use IRSA (IAM Roles for Service Accounts) in production instead of static credentials

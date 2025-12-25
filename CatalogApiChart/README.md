# CatalogApi Helm Chart

Dieser Helm Chart deployt die CatalogApi .NET Anwendung in Kubernetes mit Secret-Mounting.

## Installation

### Voraussetzungen

1. Docker Image bauen und in Kubernetes verfügbar machen:

```bash
# Im CatalogApi Verzeichnis
docker build -t catalog-api:latest -f CatalogApi/Dockerfile .

# Für lokales Kubernetes (z.B. minikube oder kind)
# Wenn Sie minikube verwenden:
minikube image load catalog-api:latest

# Wenn Sie kind verwenden:
kind load docker-image catalog-api:latest
```

2. Secret erstellen (falls noch nicht vorhanden):

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-app-credentials
  namespace: default
type: Opaque
data:
  username: bXl1c2VybmFtZQ==  # myusername (base64)
  password: bXlwYXNzd29yZA==  # mypassword (base64)
EOF
```

### Chart installieren

```bash
# Chart installieren
helm install catalog-api ./CatalogApiChart

# Chart mit benutzerdefinierten Werten installieren
helm install catalog-api ./CatalogApiChart -f custom-values.yaml

# Chart upgraden
helm upgrade catalog-api ./CatalogApiChart

# Chart deinstallieren
helm uninstall catalog-api
```

## Konfiguration

Die folgenden Werte können in der `values.yaml` konfiguriert werden:

| Parameter | Beschreibung | Default |
|-----------|--------------|---------|
| `replicaCount` | Anzahl der Replicas | `1` |
| `image.repository` | Docker Image Repository | `catalog-api` |
| `image.tag` | Image Tag | `latest` |
| `image.pullPolicy` | Image Pull Policy | `IfNotPresent` |
| `service.type` | Kubernetes Service Type | `ClusterIP` |
| `service.port` | Service Port | `80` |
| `service.targetPort` | Container Port | `8080` |
| `secret.enabled` | Secret Mounting aktivieren | `true` |
| `secret.name` | Name des zu mountenden Secrets | `my-app-credentials` |
| `secret.mountPath` | Mount-Pfad im Container | `/app/secrets` |
| `secret.createSecret` | Secret via Helm erstellen | `false` |
| `resources.limits.cpu` | CPU Limit | `500m` |
| `resources.limits.memory` | Memory Limit | `512Mi` |

## Secret Zugriff in der Anwendung

Die Secrets werden unter `/app/secrets` gemountet. Jeder Key im Secret wird als separate Datei verfügbar:

- `/app/secrets/username`
- `/app/secrets/password`

Die .NET Anwendung kann diese Dateien mit `File.ReadAllText()` lesen.

## Beispiele

### Secret-Werte in der Anwendung lesen

```csharp
var secretPath = Environment.GetEnvironmentVariable("SECRET_MOUNT_PATH") ?? "/app/secrets";
var username = File.ReadAllText(Path.Combine(secretPath, "username"));
var password = File.ReadAllText(Path.Combine(secretPath, "password"));
```

### Port-Forward für lokalen Zugriff

```bash
kubectl port-forward svc/catalog-api 8080:80
```

Die API ist dann unter `http://localhost:8080` erreichbar.

## Troubleshooting

### Pods anzeigen
```bash
kubectl get pods
```

### Logs anzeigen
```bash
kubectl logs -l app.kubernetes.io/name=catalog-api
```

### Secret im Pod überprüfen
```bash
kubectl exec -it <pod-name> -- ls -la /app/secrets
kubectl exec -it <pod-name> -- cat /app/secrets/username
```


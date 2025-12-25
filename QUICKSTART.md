# Quick Start Guide - CatalogApi mit Kubernetes Secrets

Diese Anleitung zeigt Ihnen, wie Sie die CatalogApi schnell in Kubernetes mit Secret-Mounting deployen können.

## Voraussetzungen

- Docker Desktop mit aktiviertem Kubernetes **ODER** Minikube/Kind
- Helm 3.x installiert
- kubectl installiert und konfiguriert
- .NET 10.0 SDK (für lokale Entwicklung)

## 🚀 Schnellstart (3 Minuten)

### Option 1: Automatisches Deployment mit PowerShell

```powershell
# Ins Projektverzeichnis wechseln
cd C:\projects\helm-external-secrets-operator-localstack

# Deployment ausführen (baut Image, erstellt Secret, deployed Helm Chart)
.\deploy.ps1
```

Das war's! Das Skript führt alle notwendigen Schritte automatisch aus.

### Option 2: Manuelle Schritte

#### 1. Docker Image bauen

```powershell
cd C:\projects\helm-external-secrets-operator-localstack\CatalogApi
docker build -t catalog-api:latest -f CatalogApi/Dockerfile .
```

#### 2. Secret erstellen

```powershell
kubectl apply -f - @"
apiVersion: v1
kind: Secret
metadata:
  name: my-app-credentials
  namespace: default
type: Opaque
stringData:
  username: myusername
  password: mypassword
  api-key: my-secret-api-key-12345
"@
```

#### 3. Helm Chart installieren

```powershell
cd C:\projects\helm-external-secrets-operator-localstack
helm install catalog-api ./CatalogApiChart
```

## 📝 Anwendung testen

### 1. Port-Forward einrichten

```powershell
kubectl port-forward svc/catalog-api 8080:80
```

### 2. Endpoints testen

```powershell
# Produkte abrufen
curl http://localhost:8080/products

# Secret-Konfiguration prüfen
curl http://localhost:8080/products/config

# Secret-Dateien überprüfen
curl http://localhost:8080/secrets/check
```

### Erwartete Ausgaben:

**GET /products/config:**
```json
{
  "secretMountAvailable": true,
  "availableSecrets": ["username", "password", "api-key"],
  "secretCount": 3
}
```

**GET /secrets/check:**
```json
{
  "message": "Secrets erfolgreich gelesen",
  "path": "/app/secrets",
  "secretFiles": ["username", "password", "api-key"],
  "secretsPreview": {
    "username": "myu***",
    "password": "myp***",
    "api-key": "my-***"
  }
}
```

## 🔍 Secrets im Pod überprüfen

```powershell
# Pod-Name ermitteln
$POD_NAME = kubectl get pods -l app.kubernetes.io/name=catalog-api -o jsonpath="{.items[0].metadata.name}"

# Secret-Dateien anzeigen
kubectl exec $POD_NAME -- ls -la /app/secrets

# Secret-Inhalt lesen
kubectl exec $POD_NAME -- cat /app/secrets/username
kubectl exec $POD_NAME -- cat /app/secrets/password
```

## 🔄 Updates durchführen

### Code-Änderungen deployen

```powershell
# Neues Image bauen und upgraden
.\deploy.ps1

# ODER: Mit SkipBuild wenn Image bereits existiert
.\deploy.ps1 -SkipBuild
```

### Nur Helm Chart aktualisieren

```powershell
helm upgrade catalog-api ./CatalogApiChart
```

### Pod neu starten

```powershell
kubectl rollout restart deployment/catalog-api
```

## 📊 Monitoring & Debugging

### Deployment Status

```powershell
kubectl get deployments
kubectl get pods
kubectl get services
```

### Logs anzeigen

```powershell
# Live-Logs
kubectl logs -l app.kubernetes.io/name=catalog-api -f

# Logs eines bestimmten Pods
kubectl logs <pod-name>
```

### Pod beschreiben

```powershell
kubectl describe pod -l app.kubernetes.io/name=catalog-api
```

### In Pod einsteigen

```powershell
$POD_NAME = kubectl get pods -l app.kubernetes.io/name=catalog-api -o jsonpath="{.items[0].metadata.name}"
kubectl exec -it $POD_NAME -- /bin/bash
```

## 🧹 Aufräumen

### Mit PowerShell-Skript

```powershell
.\deploy.ps1 -Uninstall
```

### Manuell

```powershell
helm uninstall catalog-api
kubectl delete secret my-app-credentials
```

## 🎛️ Konfiguration anpassen

### Andere Kubernetes-Provider verwenden

```powershell
# Für Minikube
.\deploy.ps1 -K8sProvider minikube

# Für Kind
.\deploy.ps1 -K8sProvider kind
```

### Anderen Release-Namen verwenden

```powershell
.\deploy.ps1 -ReleaseName my-api -Namespace my-namespace
```

### Values.yaml anpassen

Bearbeiten Sie `CatalogApiChart/values.yaml`:

```yaml
# Replicas erhöhen
replicaCount: 3

# Anderen Secret-Namen verwenden
secret:
  name: my-other-secret
  mountPath: /app/config/secrets

# Ressourcen anpassen
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
```

Dann deployen:

```powershell
helm upgrade catalog-api ./CatalogApiChart -f ./CatalogApiChart/values.yaml
```

## 📚 Nächste Schritte

### Integration mit External Secrets Operator

Wenn Sie Secrets aus externen Quellen (AWS Secrets Manager, HashiCorp Vault, etc.) verwenden möchten:

1. Installieren Sie den External Secrets Operator:
   ```powershell
   cd EsoSetup
   helm dependency update
   helm install eso ./
   ```

2. Das ExternalSecret wird automatisch das `my-app-credentials` Secret erstellen.

3. Deployen Sie die CatalogApi wie gewohnt.

### Secret-Werte in der Anwendung verwenden

Beispiel in C#:

```csharp
public class MyService
{
    private readonly SecretService _secretService;
    
    public MyService(SecretService secretService)
    {
        _secretService = secretService;
    }
    
    public void ConnectToDatabase()
    {
        var username = _secretService.GetSecret("username");
        var password = _secretService.GetSecret("password");
        
        // Verbindung herstellen...
    }
}
```

## ❓ Häufige Probleme

### Image Pull Error

**Problem:** Pod startet nicht, Fehler "ImagePullBackOff"

**Lösung:**
```powershell
# Image erneut laden
minikube image load catalog-api:latest
# ODER
kind load docker-image catalog-api:latest

# Pod neu starten
kubectl delete pod -l app.kubernetes.io/name=catalog-api
```

### Secret nicht gefunden

**Problem:** Secret-Dateien sind nicht unter /app/secrets

**Lösung:**
```powershell
# Prüfen ob Secret existiert
kubectl get secret my-app-credentials -o yaml

# Secret neu erstellen
kubectl delete secret my-app-credentials
.\deploy.ps1 -SkipBuild
```

### Port bereits belegt

**Problem:** Port 8080 wird bereits verwendet

**Lösung:**
```powershell
# Anderen Port verwenden
kubectl port-forward svc/catalog-api 9090:80
curl http://localhost:9090/products
```

## 📖 Weitere Dokumentationen

- [Detaillierte Deployment-Anleitung](./DEPLOYMENT.md)
- [Helm Chart README](./CatalogApiChart/README.md)
- [Kubernetes Secrets Dokumentation](https://kubernetes.io/docs/concepts/configuration/secret/)


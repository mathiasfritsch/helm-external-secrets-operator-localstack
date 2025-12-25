# Deployment-Anleitung für CatalogApi in Kubernetes

## Schritt-für-Schritt Anleitung

### 1. Docker Image bauen

```powershell
# Im Hauptverzeichnis (wo die .sln Datei liegt)
cd C:\projects\helm-external-secrets-operator-localstack\CatalogApi
docker build -t catalog-api:latest -f CatalogApi/Dockerfile .
```

### 2. Image in Kubernetes laden

**Für Minikube:**
```powershell
minikube image load catalog-api:latest
```

**Für Kind:**
```powershell
kind load docker-image catalog-api:latest
```

**Für Docker Desktop Kubernetes:**
```powershell
# Kein extra Schritt nötig, Image ist bereits verfügbar
```

### 3. Secret erstellen

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
  api-key: my-secret-api-key
"@
```

### 4. Helm Chart installieren

```powershell
cd C:\projects\helm-external-secrets-operator-localstack
helm install catalog-api ./CatalogApiChart
```

### 5. Deployment überprüfen

```powershell
# Pods anzeigen
kubectl get pods

# Logs anzeigen
kubectl logs -l app.kubernetes.io/name=catalog-api -f

# Service anzeigen
kubectl get svc
```

### 6. Anwendung testen

```powershell
# Port-Forward einrichten
kubectl port-forward svc/catalog-api 8080:80
```

Dann in einem Browser oder mit curl:

```powershell
# Health Check
curl http://localhost:8080/products

# Secret-Konfiguration prüfen
curl http://localhost:8080/products/config

# Secret-Check Endpoint
curl http://localhost:8080/secrets/check
```

### 7. Secrets im Pod überprüfen

```powershell
# Pod-Name ermitteln
$POD_NAME = kubectl get pods -l app.kubernetes.io/name=catalog-api -o jsonpath="{.items[0].metadata.name}"

# In den Pod einsteigen
kubectl exec -it $POD_NAME -- /bin/bash

# Im Pod: Secrets anzeigen
ls -la /app/secrets
cat /app/secrets/username
cat /app/secrets/password
exit
```

### 8. Update durchführen

Wenn Sie Änderungen am Code vorgenommen haben:

```powershell
# 1. Neues Image bauen
cd C:\projects\helm-external-secrets-operator-localstack\CatalogApi
docker build -t catalog-api:latest -f CatalogApi/Dockerfile .

# 2. Image in Kubernetes laden (bei Bedarf)
minikube image load catalog-api:latest  # oder kind load docker-image catalog-api:latest

# 3. Helm upgrade
cd C:\projects\helm-external-secrets-operator-localstack
helm upgrade catalog-api ./CatalogApiChart

# 4. Pods neu starten erzwingen
kubectl rollout restart deployment/catalog-api
```

### 9. Aufräumen

```powershell
# Helm Release entfernen
helm uninstall catalog-api

# Secret entfernen
kubectl delete secret my-app-credentials
```

## Troubleshooting

### Pod startet nicht
```powershell
kubectl describe pod -l app.kubernetes.io/name=catalog-api
```

### Image Pull Error
```powershell
# Stellen Sie sicher, dass imagePullPolicy auf IfNotPresent gesetzt ist
# und das Image lokal verfügbar ist
kubectl get pods -o yaml | grep -A 3 imagePullPolicy
```

### Secrets werden nicht gemountet
```powershell
# Überprüfen Sie, ob das Secret existiert
kubectl get secret my-app-credentials -o yaml

# Überprüfen Sie die Volume-Mounts im Pod
kubectl describe pod -l app.kubernetes.io/name=catalog-api | grep -A 10 "Mounts:"
```

## Alternative: Mit External Secrets Operator

Wenn Sie den External Secrets Operator verwenden möchten (bereits im Workspace vorhanden):

1. Installieren Sie zuerst den ESO (falls noch nicht geschehen):
```powershell
cd C:\projects\helm-external-secrets-operator-localstack\EsoSetup
helm dependency update
helm install eso-setup .
```

2. Das Secret wird dann automatisch vom External Secrets Operator erstellt und kann von der CatalogApi verwendet werden.


# Helm External Secrets Operator + CatalogApi

Dieses Projekt demonstriert die Verwendung von Kubernetes Secrets in einer .NET-Anwendung mit Helm Charts. Es enthält:

- **CatalogApi**: Eine .NET 10.0 Web API Anwendung
- **CatalogApiChart**: Helm Chart für das Deployment in Kubernetes
- **EsoSetup**: External Secrets Operator Setup (optional)

## 📁 Projektstruktur

```
.
├── CatalogApi/                 # .NET Web API Anwendung
│   ├── CatalogApi/
│   │   ├── Controllers/        # API Controllers
│   │   ├── Models/             # Datenmodelle
│   │   ├── Services/           # Business Logic (inkl. SecretService)
│   │   ├── Program.cs          # Anwendungseinstieg
│   │   └── Dockerfile          # Docker Image Definition
│   └── CatalogApi.sln
│
├── CatalogApiChart/            # Helm Chart für CatalogApi
│   ├── templates/              # Kubernetes Manifests
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── secret.yaml
│   ├── Chart.yaml
│   ├── values.yaml             # Standard-Konfiguration
│   ├── values-dev.yaml         # Entwicklungs-Konfiguration
│   ├── values-prod.yaml        # Produktions-Konfiguration
│   └── README.md
│
├── EsoSetup/                   # External Secrets Operator (optional)
│   ├── templates/
│   ├── Chart.yaml
│   └── values.yaml
│
├── deploy.ps1                  # Automatisches Deployment-Skript
├── dev.ps1                     # Entwickler-Helper-Skript
├── QUICKSTART.md               # Schnellstart-Anleitung
└── DEPLOYMENT.md               # Detaillierte Deployment-Anleitung
```

## 🚀 Schnellstart

### Voraussetzungen

- Docker Desktop mit Kubernetes **ODER** Minikube/Kind
- Helm 3.x
- kubectl
- PowerShell 5.1 oder höher

### Deployment in 3 Schritten

```powershell
# 1. Ins Projektverzeichnis wechseln
cd C:\projects\helm-external-secrets-operator-localstack

# 2. Deployment ausführen
.\deploy.ps1

# 3. Port-Forward einrichten und testen
kubectl port-forward svc/catalog-api 8080:80

# In einem anderen Terminal:
curl http://localhost:8080/secrets/check
```

## 🎯 Features

### CatalogApi Features

- ✅ RESTful API mit .NET 10.0
- ✅ Kubernetes Secret-Mounting
- ✅ SecretService für einfachen Secret-Zugriff
- ✅ Health Check Endpoints
- ✅ Docker-optimiertes Multi-Stage Build
- ✅ OpenAPI/Swagger Support

### Helm Chart Features

- ✅ Vollständig konfigurierbar via values.yaml
- ✅ Secret-Mounting als Dateien
- ✅ Liveness & Readiness Probes
- ✅ Resource Limits & Requests
- ✅ Horizontal Pod Autoscaling (optional)
- ✅ Ingress Support (optional)
- ✅ Multi-Environment Support (dev/prod)

## 📝 Verwendung

### Entwickler-Workflow

```powershell
# Image bauen
.\dev.ps1 build

# In Kubernetes deployen
.\dev.ps1 deploy

# Status anzeigen
.\dev.ps1 status

# Logs anzeigen
.\dev.ps1 logs

# Shell im Pod öffnen
.\dev.ps1 shell

# Anwendung testen
.\dev.ps1 test

# Port-Forward starten
.\dev.ps1 port-forward

# Deployment neu starten
.\dev.ps1 restart

# Alles aufräumen
.\dev.ps1 clean
```

### API Endpoints

| Endpoint | Methode | Beschreibung |
|----------|---------|--------------|
| `/products` | GET | Gibt Produktdaten zurück (demonstriert Secret-Verwendung in Logs) |
| `/products/config` | GET | Zeigt Secret-Konfiguration und verfügbare Secret-Keys |
| `/secrets/check` | GET | Überprüft Secret-Mounting und zeigt Preview der Werte |

### Secrets im Code verwenden

Die Anwendung stellt einen `SecretService` bereit, der über Dependency Injection verwendet werden kann:

```csharp
public class MyController : ControllerBase
{
    private readonly SecretService _secretService;
    
    public MyController(SecretService secretService)
    {
        _secretService = secretService;
    }
    
    public IActionResult GetData()
    {
        // Secret-Wert lesen
        var apiKey = _secretService.GetSecret("api-key");
        
        // Verfügbare Secrets auflisten
        var secrets = _secretService.GetAvailableSecrets();
        
        // Prüfen ob Secret-Mounting verfügbar ist
        if (_secretService.IsSecretMountAvailable())
        {
            // Secrets sind verfügbar...
        }
        
        return Ok();
    }
}
```

## 🔧 Konfiguration

### Helm Values anpassen

**Entwicklung:**
```powershell
helm install catalog-api ./CatalogApiChart -f ./CatalogApiChart/values-dev.yaml
```

**Produktion:**
```powershell
helm install catalog-api ./CatalogApiChart -f ./CatalogApiChart/values-prod.yaml
```

**Custom Values:**
```yaml
# custom-values.yaml
replicaCount: 2
secret:
  name: my-custom-secret
  mountPath: /app/config
resources:
  limits:
    memory: 1Gi
```

```powershell
helm install catalog-api ./CatalogApiChart -f custom-values.yaml
```

### Secret-Werte ändern

```powershell
# Secret aktualisieren
kubectl create secret generic my-app-credentials \
  --from-literal=username=newuser \
  --from-literal=password=newpassword \
  --dry-run=client -o yaml | kubectl apply -f -

# Pod neu starten, um neue Werte zu laden
kubectl rollout restart deployment/catalog-api
```

## 🔒 Secret-Management

### Option 1: Manuelle Secrets (Standard)

Secrets werden manuell in Kubernetes erstellt:

```powershell
kubectl create secret generic my-app-credentials \
  --from-literal=username=myuser \
  --from-literal=password=mypassword \
  --from-literal=api-key=secret123
```

### Option 2: Secrets via Helm

Aktivieren Sie `createSecret` in values.yaml:

```yaml
secret:
  createSecret: true
  data:
    username: dXNlcm5hbWU=  # base64 encoded
    password: cGFzc3dvcmQ=
```

### Option 3: External Secrets Operator

Für Integration mit externen Secret-Stores (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault):

```powershell
# ESO installieren
cd EsoSetup
helm install eso ./

# ExternalSecret wird automatisch my-app-credentials erstellen
```

## 📊 Monitoring

### Status überprüfen

```powershell
# Alle Ressourcen anzeigen
.\dev.ps1 status

# Oder einzeln:
kubectl get all -l app.kubernetes.io/name=catalog-api
kubectl get secret my-app-credentials
```

### Logs analysieren

```powershell
# Live-Logs
.\dev.ps1 logs

# Oder direkt:
kubectl logs -l app.kubernetes.io/name=catalog-api -f

# Logs eines bestimmten Pods
kubectl logs <pod-name>
```

### Secrets im Pod überprüfen

```powershell
# In Pod einsteigen
.\dev.ps1 shell

# Im Pod:
ls -la /app/secrets
cat /app/secrets/username
cat /app/secrets/password
```

## 🔨 Lokale Entwicklung

### Anwendung lokal ausführen

```powershell
cd CatalogApi/CatalogApi
dotnet run
```

**Hinweis:** Lokal sind keine Secrets gemountet. Die Anwendung erkennt das und funktioniert trotzdem.

### Lokales Testing mit Docker

```powershell
# Image bauen
docker build -t catalog-api:latest -f CatalogApi/Dockerfile ./CatalogApi

# Container mit Secret-Volume starten
mkdir C:\temp\secrets
echo "testuser" > C:\temp\secrets\username
echo "testpass" > C:\temp\secrets\password

docker run -p 8080:8080 \
  -e ASPNETCORE_URLS="http://+:8080" \
  -e SECRET_MOUNT_PATH="/app/secrets" \
  -v C:\temp\secrets:/app/secrets:ro \
  catalog-api:latest
```

## 📚 Dokumentation

- [QUICKSTART.md](./QUICKSTART.md) - Schnellstart-Anleitung
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Detaillierte Deployment-Anleitung
- [CatalogApiChart/README.md](./CatalogApiChart/README.md) - Helm Chart Dokumentation

## 🤝 Best Practices

1. **Verwenden Sie spezifische Image-Tags in Produktion** - Nicht `latest`
2. **Secrets niemals im Code committen** - Verwenden Sie Kubernetes Secrets oder External Secrets
3. **Resource Limits setzen** - Vermeiden Sie Resource-Exhaustion
4. **Liveness & Readiness Probes konfigurieren** - Für automatisches Health-Management
5. **Horizontal Pod Autoscaling aktivieren** - Für Lastverteilung
6. **Pod Disruption Budgets verwenden** - Für Hochverfügbarkeit
7. **Secret-Rotation implementieren** - Mit External Secrets Operator

## ❓ Troubleshooting

### Pod startet nicht

```powershell
kubectl describe pod -l app.kubernetes.io/name=catalog-api
kubectl logs -l app.kubernetes.io/name=catalog-api
```

### ImagePullBackOff Error

```powershell
# Image erneut laden
docker build -t catalog-api:latest -f CatalogApi/Dockerfile ./CatalogApi
minikube image load catalog-api:latest  # oder kind load

# imagePullPolicy überprüfen
kubectl get deployment catalog-api -o yaml | grep imagePullPolicy
```

### Secrets werden nicht gelesen

```powershell
# Secret existiert?
kubectl get secret my-app-credentials -o yaml

# Volume korrekt gemountet?
kubectl describe pod -l app.kubernetes.io/name=catalog-api | grep -A 10 "Mounts:"

# Dateien im Pod vorhanden?
kubectl exec -it <pod-name> -- ls -la /app/secrets
```

## 🧹 Cleanup

```powershell
# Alles entfernen
.\dev.ps1 clean

# Oder manuell:
helm uninstall catalog-api
kubectl delete secret my-app-credentials
```

## 📄 Lizenz

Dieses Projekt dient zu Demonstrationszwecken.

## 🙋 Support

Bei Fragen oder Problemen:
1. Überprüfen Sie die Dokumentation in [QUICKSTART.md](./QUICKSTART.md) und [DEPLOYMENT.md](./DEPLOYMENT.md)
2. Verwenden Sie `.\dev.ps1 status` für einen Überblick
3. Prüfen Sie die Logs mit `.\dev.ps1 logs`


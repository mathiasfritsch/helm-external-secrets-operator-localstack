namespace CatalogApi.Services;

/// <summary>
/// Service zum Lesen von gemounteten Kubernetes Secrets
/// </summary>
public class SecretService
{
    private readonly string _secretPath;
    private readonly ILogger<SecretService> _logger;

    public SecretService(ILogger<SecretService> logger)
    {
        _logger = logger;
        _secretPath = Environment.GetEnvironmentVariable("SECRET_MOUNT_PATH") ?? "/app/secrets";
    }

    /// <summary>
    /// Liest einen Secret-Wert aus einer gemounteten Datei
    /// </summary>
    /// <param name="secretKey">Der Name des Secret-Keys (Dateiname)</param>
    /// <returns>Der Secret-Wert oder null, wenn nicht gefunden</returns>
    public string? GetSecret(string secretKey)
    {
        try
        {
            var secretFile = Path.Combine(_secretPath, secretKey);
            
            if (!File.Exists(secretFile))
            {
                _logger.LogWarning("Secret-Datei nicht gefunden: {SecretFile}", secretFile);
                return null;
            }

            var value = File.ReadAllText(secretFile).Trim();
            _logger.LogInformation("Secret erfolgreich gelesen: {SecretKey}", secretKey);
            return value;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Fehler beim Lesen des Secrets: {SecretKey}", secretKey);
            return null;
        }
    }

    /// <summary>
    /// Gibt alle verfügbaren Secret-Keys zurück
    /// </summary>
    public IEnumerable<string> GetAvailableSecrets()
    {
        try
        {
            if (!Directory.Exists(_secretPath))
            {
                _logger.LogWarning("Secret-Verzeichnis existiert nicht: {SecretPath}", _secretPath);
                return Enumerable.Empty<string>();
            }

            return Directory.GetFiles(_secretPath).Select(Path.GetFileName).OfType<string>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Fehler beim Auflisten der Secrets");
            return Enumerable.Empty<string>();
        }
    }

    /// <summary>
    /// Prüft, ob Secret-Mounting verfügbar ist
    /// </summary>
    public bool IsSecretMountAvailable()
    {
        return Directory.Exists(_secretPath);
    }
}


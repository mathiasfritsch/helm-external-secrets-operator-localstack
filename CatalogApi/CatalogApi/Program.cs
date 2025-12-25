namespace CatalogApi;

using CatalogApi.Services;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Add services to the container.
        builder.Services.AddSingleton<SecretService>();

        builder.Services.AddControllers();
        // Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
        builder.Services.AddOpenApi();

        var app = builder.Build();

        // Configure the HTTP request pipeline.
        if (app.Environment.IsDevelopment())
        {
            app.MapOpenApi();
        }

        // Only use HTTPS redirection in Development (not in Kubernetes)
        if (app.Environment.IsDevelopment())
        {
            app.UseHttpsRedirection();
        }

        app.UseAuthorization();

        app.MapControllers();

        // Health check endpoint für Kubernetes Probes
        app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }));
        app.MapGet("/", () => Results.Ok(new { 
            name = "CatalogApi", 
            version = "1.0.0", 
            status = "running",
            endpoints = new[] { "/products", "/products/config", "/secrets/check", "/health" }
        }));

        // Endpoint zum Testen des Secret-Zugriffs
        app.MapGet("/secrets/check", () =>
        {
            var secretPath = Environment.GetEnvironmentVariable("SECRET_MOUNT_PATH") ?? "/app/secrets";
            
            if (!Directory.Exists(secretPath))
            {
                return Results.Ok(new 
                { 
                    message = "Secret path nicht gefunden (läuft wahrscheinlich lokal)", 
                    path = secretPath 
                });
            }

            try
            {
                var files = Directory.GetFiles(secretPath);
                var secrets = new Dictionary<string, string>();
                
                foreach (var file in files)
                {
                    var fileName = Path.GetFileName(file);
                    var value = File.ReadAllText(file).Trim();
                    // Nur die ersten 3 Zeichen des Werts anzeigen (aus Sicherheitsgründen)
                    secrets[fileName] = value.Length > 3 ? value.Substring(0, 3) + "***" : "***";
                }

                return Results.Ok(new 
                { 
                    message = "Secrets erfolgreich gelesen",
                    path = secretPath,
                    secretFiles = files.Select(Path.GetFileName).ToArray(),
                    secretsPreview = secrets
                });
            }
            catch (Exception ex)
            {
                return Results.Problem($"Fehler beim Lesen der Secrets: {ex.Message}");
            }
        });

        app.Run();
    }
}
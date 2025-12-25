using Microsoft.AspNetCore.Mvc;
using CatalogApi.Models;
using CatalogApi.Services;

namespace CatalogApi.Controllers;

[ApiController]
[Route("[controller]")]
public class ProductsController : ControllerBase
{
    private readonly SecretService _secretService;
    private readonly ILogger<ProductsController> _logger;

    public ProductsController(SecretService secretService, ILogger<ProductsController> logger)
    {
        _secretService = secretService;
        _logger = logger;
    }

    [HttpGet(Name = "GetProduct")]
    public Product Get()
    {
        // Beispiel: Secret auslesen (falls verfügbar)
        var username = _secretService.GetSecret("username");
        if (username != null)
        {
            _logger.LogInformation("Verbindung würde mit Benutzer {Username} hergestellt", username);
        }

        return new Product
        {
            Id = 1,
            Name = "Sample Product"
        };
    }

    [HttpGet("config")]
    public IActionResult GetConfiguration()
    {
        var isAvailable = _secretService.IsSecretMountAvailable();
        var availableSecrets = _secretService.GetAvailableSecrets().ToList();

        return Ok(new
        {
            secretMountAvailable = isAvailable,
            availableSecrets,
            secretCount = availableSecrets.Count
        });
    }
}


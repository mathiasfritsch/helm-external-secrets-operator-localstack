using Microsoft.AspNetCore.Mvc;
using CatalogApi.Models;

namespace CatalogApi.Controllers;

[ApiController]
[Route("[controller]")]
public class ProductsController : ControllerBase
{
    [HttpGet(Name = "GetProduct")]
    public Product Get()
    {
        return new Product
        {
            Id = 1,
            Name = "Sample Product"
        };
    }
}


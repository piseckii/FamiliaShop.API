using FamiliaShop.API.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// CORS - allow frontend to call API
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Register DB connection
builder.Services.AddSingleton<DatabaseContext>(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    var connString = config.GetConnectionString("DefaultConnection")!;
    return new DatabaseContext(connString);
});

// Serve static files (our HTML/CSS/JS frontend)
builder.Services.AddDirectoryBrowser();

var app = builder.Build();

app.UseCors("AllowAll");
app.UseStaticFiles();
app.UseDefaultFiles();
app.UseAuthorization();
app.MapControllers();

// Redirect root to index.html
app.MapGet("/", () => Results.Redirect("/index.html"));

app.Run();
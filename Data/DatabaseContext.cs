using Npgsql;
using System.Data;

namespace FamiliaShop.API.Data;

public class DatabaseContext
{
    private readonly string _connectionString;

    public DatabaseContext(string connectionString)
    {
        _connectionString = connectionString;
        // Register legacy timestamp behavior for Npgsql
        AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);
    }

    public IDbConnection CreateConnection()
    {
        return new NpgsqlConnection(_connectionString);
    }
}
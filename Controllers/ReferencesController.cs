using Dapper;
using FamiliaShop.API.Data;
using FamiliaShop.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace FamiliaShop.API.Controllers;

// ---- Купоны ----
[ApiController]
[Route("api/[controller]")]
public class CouponsController : ControllerBase
{
    private readonly DatabaseContext _db;
    public CouponsController(DatabaseContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT ""Код_купона"" AS Kod_kupona, ""Промокод"" AS Promokod,
                   ""Тип_скидки"" AS Tip_skidki, ""Размер_скидки"" AS Razmer_skidki,
                   ""Дата_начала"" AS Data_nachala, ""Дата_окончания"" AS Data_okonchaniya,
                   ""Минимальная_сумма_заказа"" AS Minimalnaya_summa_zakaza
            FROM ""Купон"" ORDER BY ""Код_купона""";
        return Ok(await conn.QueryAsync<KuponDto>(sql));
    }

    [HttpGet("validate/{code}")]
    public async Task<IActionResult> Validate(string code)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT ""Код_купона"" AS Kod_kupona, ""Промокод"" AS Promokod,
                   ""Тип_скидки"" AS Tip_skidki, ""Размер_скидки"" AS Razmer_skidki,
                   ""Дата_начала"" AS Data_nachala, ""Дата_окончания"" AS Data_okonchaniya,
                   ""Минимальная_сумма_заказа"" AS Minimalnaya_summa_zakaza
            FROM ""Купон""
            WHERE ""Промокод"" = @Code
              AND ""Дата_начала"" <= CURRENT_DATE
              AND ""Дата_окончания"" >= CURRENT_DATE";
        var kupon = await conn.QueryFirstOrDefaultAsync<KuponDto>(sql, new { Code = code });
        if (kupon == null) return NotFound(new { message = "Купон не найден или истёк" });
        return Ok(kupon);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] KuponDto dto)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            INSERT INTO ""Купон"" (""Промокод"", ""Тип_скидки"", ""Размер_скидки"",
                ""Дата_начала"", ""Дата_окончания"", ""Минимальная_сумма_заказа"")
            VALUES (@Promo, @Tip, @Razmer, @DataN, @DataO, @MinSumma)
            RETURNING ""Код_купона""";
        var id = await conn.QuerySingleAsync<int>(sql, new
        {
            Promo = dto.Promokod, Tip = dto.Tip_skidki, Razmer = dto.Razmer_skidki,
            DataN = dto.Data_nachala, DataO = dto.Data_okonchaniya,
            MinSumma = dto.Minimalnaya_summa_zakaza
        });
        return Ok(new { id });
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        using var conn = _db.CreateConnection();
        await conn.ExecuteAsync(@"DELETE FROM ""Купон"" WHERE ""Код_купона"" = @Id", new { Id = id });
        return NoContent();
    }
}

// ---- Скидки ----
[ApiController]
[Route("api/[controller]")]
public class DiscountsController : ControllerBase
{
    private readonly DatabaseContext _db;
    public DiscountsController(DatabaseContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT ""Код_скидки"" AS Kod_skidki, ""Название"" AS Nazvanie,
                   ""Тип"" AS Tip, ""Размер"" AS Razmer,
                   ""Дата_начала"" AS Data_nachala, ""Дата_окончания"" AS Data_okonchaniya
            FROM ""Скидка"" ORDER BY ""Код_скидки""";
        return Ok(await conn.QueryAsync<SkidkaDto>(sql));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] SkidkaDto dto)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            INSERT INTO ""Скидка"" (""Название"", ""Тип"", ""Размер"", ""Дата_начала"", ""Дата_окончания"")
            VALUES (@Name, @Tip, @Razmer, @DataN, @DataO)
            RETURNING ""Код_скидки""";
        var id = await conn.QuerySingleAsync<int>(sql, new
        {
            Name = dto.Nazvanie, Tip = dto.Tip, Razmer = dto.Razmer,
            DataN = dto.Data_nachala, DataO = dto.Data_okonchaniya
        });
        return Ok(new { id });
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        using var conn = _db.CreateConnection();
        await conn.ExecuteAsync(@"DELETE FROM ""Скидка"" WHERE ""Код_скидки"" = @Id", new { Id = id });
        return NoContent();
    }
}

// ---- Справочники ----
[ApiController]
[Route("api/[controller]")]
public class ReferencesController : ControllerBase
{
    private readonly DatabaseContext _db;
    public ReferencesController(DatabaseContext db) => _db = db;

    [HttpGet("brands")]
    public async Task<IActionResult> GetBrands()
    {
        using var conn = _db.CreateConnection();
        var sql = @"SELECT ""Код_бренда"" AS Kod_brenda, ""Название"" AS Nazvanie,
                           ""Страна_происхождения"" AS Strana_proiskhozhdeniya, ""Описание"" AS Opisanie
                    FROM ""Бренд"" ORDER BY ""Название""";
        return Ok(await conn.QueryAsync<BrendDto>(sql));
    }

    [HttpPost("brands")]
    public async Task<IActionResult> CreateBrand([FromBody] BrendDto dto)
    {
        using var conn = _db.CreateConnection();
        var id = await conn.QuerySingleAsync<int>(
            @"INSERT INTO ""Бренд"" (""Название"", ""Страна_происхождения"", ""Описание"")
              VALUES (@N, @S, @O) RETURNING ""Код_бренда""",
            new { N = dto.Nazvanie, S = dto.Strana_proiskhozhdeniya, O = dto.Opisanie });
        return Ok(new { id });
    }

    [HttpDelete("brands/{id}")]
    public async Task<IActionResult> DeleteBrand(int id)
    {
        using var conn = _db.CreateConnection();
        await conn.ExecuteAsync(@"DELETE FROM ""Бренд"" WHERE ""Код_бренда"" = @Id", new { Id = id });
        return NoContent();
    }

    [HttpGet("sizes")]
    public async Task<IActionResult> GetSizes()
    {
        using var conn = _db.CreateConnection();
        var sql = @"SELECT ""Код_размера"" AS Kod_razmera, ""Значение"" AS Znachenie,
                           ""Тип_размерной_сетки"" AS Tip_razmernoy_setki
                    FROM ""Размер"" ORDER BY ""Тип_размерной_сетки"", ""Значение""";
        return Ok(await conn.QueryAsync<RazmerDto>(sql));
    }

    [HttpPost("sizes")]
    public async Task<IActionResult> CreateSize([FromBody] RazmerDto dto)
    {
        using var conn = _db.CreateConnection();
        var id = await conn.QuerySingleAsync<int>(
            @"INSERT INTO ""Размер"" (""Значение"", ""Тип_размерной_сетки"")
              VALUES (@V, @T) RETURNING ""Код_размера""",
            new { V = dto.Znachenie, T = dto.Tip_razmernoy_setki });
        return Ok(new { id });
    }

    [HttpGet("categories")]
    public async Task<IActionResult> GetCategories()
    {
        using var conn = _db.CreateConnection();
        var sql = @"SELECT ""Код_категории"" AS Kod_kategorii, ""Название"" AS Nazvanie,
                           ""Описание"" AS Opisanie
                    FROM ""Категория"" ORDER BY ""Название""";
        return Ok(await conn.QueryAsync<KategoriyaDto>(sql));
    }

    [HttpPost("categories")]
    public async Task<IActionResult> CreateCategory([FromBody] KategoriyaDto dto)
    {
        using var conn = _db.CreateConnection();
        var id = await conn.QuerySingleAsync<int>(
            @"INSERT INTO ""Категория"" (""Название"", ""Описание"")
              VALUES (@N, @O) RETURNING ""Код_категории""",
            new { N = dto.Nazvanie, O = dto.Opisanie });
        return Ok(new { id });
    }

    [HttpDelete("categories/{id}")]
    public async Task<IActionResult> DeleteCategory(int id)
    {
        using var conn = _db.CreateConnection();
        await conn.ExecuteAsync(@"DELETE FROM ""Категория"" WHERE ""Код_категории"" = @Id", new { Id = id });
        return NoContent();
    }

    [HttpGet("delivery-methods")]
    public async Task<IActionResult> GetDeliveryMethods()
    {
        using var conn = _db.CreateConnection();
        var sql = @"SELECT ""Код_способа_получения"" AS Kod_sposoba_polucheniya,
                           ""Название"" AS Nazvanie, ""Описание"" AS Opisanie
                    FROM ""СпособПолучения"" ORDER BY ""Код_способа_получения""";
        return Ok(await conn.QueryAsync<SpособPolucheniyaDto>(sql));
    }

    [HttpGet("payment-methods")]
    public async Task<IActionResult> GetPaymentMethods()
    {
        using var conn = _db.CreateConnection();
        var sql = @"SELECT ""Код_способа_оплаты"" AS Kod_sposoba_oplaty,
                           ""Название"" AS Nazvanie, ""Описание"" AS Opisanie
                    FROM ""СпособОплаты"" ORDER BY ""Код_способа_оплаты""";
        return Ok(await conn.QueryAsync<SposobOplatyDto>(sql));
    }
}
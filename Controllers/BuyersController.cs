using Dapper;
using FamiliaShop.API.Data;
using FamiliaShop.API.DTOs;
using Microsoft.AspNetCore.Mvc;
using Npgsql;

namespace FamiliaShop.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BuyersController : ControllerBase
{
    private readonly DatabaseContext _db;
    public BuyersController(DatabaseContext db) => _db = db;

    // GET api/buyers
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT
                ""Код_покупателя""   AS ""Kod_pokupatelya"",
                ""Имя""              AS ""Imya"",
                ""Email""            AS ""Email"",
                ""Телефон""          AS ""Telefon"",
                ""Дата_регистрации"" AS ""Data_registracii""
            FROM ""Покупатель""
            ORDER BY ""Код_покупателя""";
        return Ok(await conn.QueryAsync<BuyerDto>(sql));
    }

    // GET api/buyers/5
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT
                ""Код_покупателя""   AS ""Kod_pokupatelya"",
                ""Имя""              AS ""Imya"",
                ""Email""            AS ""Email"",
                ""Телефон""          AS ""Telefon"",
                ""Дата_регистрации"" AS ""Data_registracii""
            FROM ""Покупатель""
            WHERE ""Код_покупателя"" = @Id";
        var buyer = await conn.QueryFirstOrDefaultAsync<BuyerDto>(sql, new { Id = id });
        if (buyer == null) return NotFound();
        return Ok(buyer);
    }

    // GET api/buyers/email/{email}
    [HttpGet("email/{email}")]
    public async Task<IActionResult> GetByEmail(string email)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT
                ""Код_покупателя""   AS ""Kod_pokupatelya"",
                ""Имя""              AS ""Imya"",
                ""Email""            AS ""Email"",
                ""Телефон""          AS ""Telefon"",
                ""Дата_регистрации"" AS ""Data_registracii""
            FROM ""Покупатель""
            WHERE ""Email""::VARCHAR = @Email";
        var buyer = await conn.QueryFirstOrDefaultAsync<BuyerDto>(sql, new { Email = email });
        if (buyer == null) return NotFound();
        return Ok(buyer);
    }

    // POST api/buyers — регистрация нового покупателя.
    // Корзину создавать НЕ нужно — это делает триггер trg_АвтоКорзина.
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] BuyerCreateDto dto)
    {
        using var conn = _db.CreateConnection();

        // Проверяем уникальность email до вставки
        var exists = await conn.ExecuteScalarAsync<int>(
            @"SELECT COUNT(*) FROM ""Покупатель"" WHERE ""Email""::VARCHAR = @Email",
            new { Email = dto.Email });

        if (exists > 0)
            return Conflict(new { message = "Покупатель с таким email уже существует" });

        try
        {
            // INSERT — триггер trg_АвтоКорзина автоматически создаст корзину
            var sql = @"
                INSERT INTO ""Покупатель"" (""Имя"", ""Email"", ""Телефон"")
                VALUES (@Imya, @Email::email_type, @Telefon)
                RETURNING ""Код_покупателя""";

            var newId = await conn.QuerySingleAsync<int>(sql, new
            {
                Imya    = dto.Imya,
                Email   = dto.Email,
                Telefon = dto.Telefon
            });

            return Ok(new { id = newId });
        }
        catch (PostgresException ex)
        {
            return BadRequest(new { message = ex.MessageText });
        }
    }

    // PUT api/buyers/5 — обновление через хранимую процедуру sp_ОбновитьПокупателя
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, [FromBody] BuyerCreateDto dto)
    {
        using var conn = (NpgsqlConnection)_db.CreateConnection();
        await conn.OpenAsync();

        try
        {
            // CALL процедура выполняет UPDATE с проверками
            using var cmd = new NpgsqlCommand(
                "CALL sp_ОбновитьПокупателя(@p_id, @p_imya, @p_email, @p_tel)",
                conn);

            cmd.Parameters.AddWithValue("p_id",    id);
            cmd.Parameters.AddWithValue("p_imya",  dto.Imya);
            cmd.Parameters.AddWithValue("p_email", dto.Email);
            cmd.Parameters.AddWithValue("p_tel",
                string.IsNullOrEmpty(dto.Telefon) ? DBNull.Value : (object)dto.Telefon);

            await cmd.ExecuteNonQueryAsync();
            return NoContent();
        }
        catch (PostgresException ex)
        {
            return BadRequest(new { message = ex.MessageText });
        }
    }

    // DELETE api/buyers/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        using var conn = _db.CreateConnection();
        await conn.ExecuteAsync(
            @"DELETE FROM ""Покупатель"" WHERE ""Код_покупателя"" = @Id",
            new { Id = id });
        return NoContent();
    }

    // GET api/buyers/5/addresses
    [HttpGet("{id}/addresses")]
    public async Task<IActionResult> GetAddresses(int id)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT
                ""Код_адреса""       AS ""Kod_adresa"",
                ""Код_покупателя""   AS ""Kod_pokupatelya"",
                ""Населённый_пункт"" AS ""Naselennyy_punkt"",
                ""Улица""            AS ""Ulica"",
                ""Дом""              AS ""Dom"",
                ""Квартира""         AS ""Kvartira"",
                ""Почтовый_индекс""  AS ""Pochtovyy_indeks""
            FROM ""Адрес""
            WHERE ""Код_покупателя"" = @Id
            ORDER BY ""Код_адреса""";
        return Ok(await conn.QueryAsync<AdresDto>(sql, new { Id = id }));
    }

    // POST api/buyers/addresses
    [HttpPost("addresses")]
    public async Task<IActionResult> AddAddress([FromBody] AdresCreateDto dto)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            INSERT INTO ""Адрес""
                (""Код_покупателя"", ""Населённый_пункт"", ""Улица"",
                 ""Дом"", ""Квартира"", ""Почтовый_индекс"")
            VALUES (@Pok, @Punkt, @Ulica, @Dom, @Kv, @Index)
            RETURNING ""Код_адреса""";

        var newId = await conn.QuerySingleAsync<int>(sql, new
        {
            Pok   = dto.Kod_pokupatelya,
            Punkt = dto.Naselennyy_punkt,
            Ulica = dto.Ulica,
            Dom   = dto.Dom,
            Kv    = dto.Kvartira,
            Index = dto.Pochtovyy_indeks
        });
        return Ok(new { id = newId });
    }

    // GET api/buyers/5/orders — заказы покупателя из представления v_ЗаказыПолные
    [HttpGet("{id}/orders")]
    public async Task<IActionResult> GetOrders(int id)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT
                ""Код_заказа""       AS ""Kod_zakaza"",
                ""Код_покупателя""   AS ""Kod_pokupatelya"",
                ""Итоговая_сумма""   AS ""Itogovaya_summa"",
                ""Статус""           AS ""Status"",
                ""Дата_оформления""  AS ""Data_oformleniya"",
                ""Способ_получения"" AS ""Sposob_polucheniya"",
                ""Способ_оплаты""    AS ""Sposob_oplaty"",
                ""Промокод""         AS Promokod,
                ""Состав_заказа""    AS Sostav_zakaza
            FROM ""v_ЗаказыПолные""
            WHERE ""Код_покупателя"" = @Id
            ORDER BY ""Дата_оформления"" DESC";
        return Ok(await conn.QueryAsync<ZakazDto>(sql, new { Id = id }));
    }
}
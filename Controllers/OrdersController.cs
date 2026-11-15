using Dapper;
using FamiliaShop.API.Data;
using FamiliaShop.API.DTOs;
using Microsoft.AspNetCore.Mvc;
using Npgsql;

namespace FamiliaShop.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly DatabaseContext _db;
    public OrdersController(DatabaseContext db) => _db = db;

    // GET api/orders — читаем из представления v_ЗаказыПолные
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? status)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT
                ""Код_заказа""          AS ""Kod_zakaza"",
                ""Код_покупателя""      AS Kod_pokupatelya,
                ""Имя_покупателя""      AS Imya_pokupatelya,
                ""Итоговая_сумма""      AS Itogovaya_summa,
                ""Статус""              AS Status,
                ""Дата_оформления""     AS Data_oformleniya,
                ""Способ_получения""    AS Sposob_polucheniya,
                ""Способ_оплаты""       AS Sposob_oplaty,
                ""Промокод""            AS Promokod
            FROM ""v_ЗаказыПолные""
            WHERE (@Status::TEXT IS NULL OR ""Статус"" = @Status)
            ORDER BY ""Дата_оформления"" DESC";

        var result = await conn.QueryAsync<ZakazDto>(sql, new { Status = status });
        return Ok(result);
    }

    // GET api/orders/5 — читаем из представления v_ЗаказыПолные
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT
                ""Код_заказа""          AS Kod_zakaza,
                ""Код_покупателя""      AS Kod_pokupatelya,
                ""Имя_покупателя""      AS Imya_pokupatelya,
                ""Код_адреса""          AS Kod_adresa,
                ""Адрес_полный""        AS Adres_polnyy,
                ""Способ_получения""    AS Sposob_polucheniya,
                ""Способ_оплаты""       AS Sposob_oplaty,
                ""Промокод""            AS Promokod,
                ""Дата_оформления""     AS Data_oformleniya,
                ""Итоговая_сумма""      AS Itogovaya_summa,
                ""Статус""              AS Status
            FROM ""v_ЗаказыПолные""
            WHERE ""Код_заказа"" = @Id";

        var order = await conn.QueryFirstOrDefaultAsync<ZakazDto>(sql, new { Id = id });
        if (order == null) return NotFound();

        var itemsSql = @"
            SELECT
                sz.""Код_товара""               AS Kod_tovara,
                t.""Наименование""              AS Naimenovanie,
                t.""Артикул""                   AS Artikul,
                sz.""Количество""               AS Kolichestvo,
                sz.""Цена_на_момент_покупки""   AS Cena_na_moment_pokupki
            FROM ""СодержимоеЗаказа"" sz
            JOIN ""Товар"" t ON t.""Код_товара"" = sz.""Код_товара""
            WHERE sz.""Код_заказа"" = @Id";

        order.Tovary = (await conn.QueryAsync<ZakazTovarDto>(itemsSql, new { Id = id })).ToList();
        return Ok(order);
    }

    // POST api/orders — вызываем хранимую процедуру sp_ОформитьЗаказ
    // Процедура сама переносит корзину в заказ через курсор,
    // применяет купон и очищает корзину.
    [HttpPost]
public async Task<IActionResult> Create([FromBody] ZakazFromCartDto dto)
{
    Console.WriteLine(System.Text.Json.JsonSerializer.Serialize(dto));

        if (dto == null)
            return BadRequest("DTO is null");
        
        using var conn = (NpgsqlConnection)_db.CreateConnection();
        await conn.OpenAsync();

        try
        {
            // Вызываем хранимую процедуру через параметризованную команду.
            // sp_ОформитьЗаказ возвращает OUT-параметр p_new_zakaz_id.
            using var cmd = new NpgsqlCommand(
                "CALL sp_ОформитьЗаказ(@p_pok, @p_adr, @p_spol, @p_sopl, @p_kupon, @p_new_id)",
                conn);

            cmd.Parameters.AddWithValue("p_pok",    dto.Kod_pokupatelya);
            cmd.Parameters.AddWithValue("p_adr",    dto.Kod_adresa);
            cmd.Parameters.AddWithValue("p_spol",   dto.Kod_sposoba_polucheniya);
            cmd.Parameters.AddWithValue("p_sopl",   dto.Kod_sposoba_oplaty);
            cmd.Parameters.AddWithValue("p_kupon",
                dto.Kod_kupona.HasValue ? (object)dto.Kod_kupona.Value : DBNull.Value);

            // OUT-параметр
            var outParam = new NpgsqlParameter("p_new_id", NpgsqlTypes.NpgsqlDbType.Integer)
            {
                Direction = System.Data.ParameterDirection.InputOutput,
                Value     = DBNull.Value
            };
            cmd.Parameters.Add(outParam);

            await cmd.ExecuteNonQueryAsync();

            var newId = outParam.Value != DBNull.Value
                ? Convert.ToInt32(outParam.Value)
                : 0;

            return Ok(new { id = newId });
        }
        catch (PostgresException ex)
        {
            // Передаём сообщение из RAISE EXCEPTION процедуры клиенту
            return BadRequest(new { message = ex.MessageText });
        }
    }

    // PATCH api/orders/5/status — обновляем статус (триггер запишет в лог)
    [HttpPatch("{id}/status")]
    public async Task<IActionResult> UpdateStatus(int id, [FromBody] StatusUpdateDto dto)
    {
        var valid = new[] { "Оформлен", "В сборке", "Передан в доставку", "Доставлен", "Отменён" };
        if (!valid.Contains(dto.Status))
            return BadRequest(new { message = "Недопустимый статус" });

        using var conn = _db.CreateConnection();
        try
        {
            // Триггер trg_ЛогСтатусов автоматически запишет смену статуса в лог
            await conn.ExecuteAsync(
                @"UPDATE ""Заказ"" SET ""Статус"" = @Status WHERE ""Код_заказа"" = @Id",
                new { Status = dto.Status, Id = id });
            return NoContent();
        }
        catch (PostgresException ex)
        {
            return BadRequest(new { message = ex.MessageText });
        }
    }

    // GET api/orders/5/log — история смены статусов (из лог-таблицы)
    [HttpGet("{id}/log")]
    public async Task<IActionResult> GetStatusLog(int id)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT
                ""Код_записи""      AS Kod_zapisi,
                ""Код_заказа""      AS Kod_zakaza,
                ""Статус_старый""   AS Status_staryy,
                ""Статус_новый""    AS Status_novyy,
                ""Дата_изменения""  AS Data_izmeneniya,
                ""Комментарий""     AS Kommentariy
            FROM ""ЛогСтатусовЗаказа""
            WHERE ""Код_заказа"" = @Id
            ORDER BY ""Дата_изменения"" DESC";

        var result = await conn.QueryAsync(sql, new { Id = id });
        return Ok(result);
    }
}

public class StatusUpdateDto
{
    public string Status { get; set; } = "";
}

// DTO для создания заказа из корзины через процедуру
// (не нужно передавать список товаров — процедура берёт их из корзины)
public class ZakazFromCartDto
{
    public int  Kod_pokupatelya             { get; set; }
    public int  Kod_adresa                  { get; set; }
    public int  Kod_sposoba_polucheniya     { get; set; }
    public int  Kod_sposoba_oplaty          { get; set; }
    public int? Kod_kupona                  { get; set; }
}
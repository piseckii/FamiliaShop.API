using Dapper;
using FamiliaShop.API.Data;
using FamiliaShop.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace FamiliaShop.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReviewsController : ControllerBase
{
    private readonly DatabaseContext _db;
    public ReviewsController(DatabaseContext db) => _db = db;

    // GET api/reviews/product/5
    [HttpGet("product/{productId}")]
    public async Task<IActionResult> GetByProduct(int productId)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT o.""Код_отзыва"" AS Kod_otzyva,
                   o.""Код_покупателя"" AS Kod_pokupatelya,
                   p.""Имя"" AS Imya_pokupatelya,
                   o.""Код_товара"" AS Kod_tovara,
                   o.""Текст"" AS Tekst,
                   o.""Оценка"" AS Ocenka,
                   o.""Дата"" AS Data
            FROM ""Отзыв"" o
            JOIN ""Покупатель"" p ON p.""Код_покупателя"" = o.""Код_покупателя""
            WHERE o.""Код_товара"" = @ProductId
            ORDER BY o.""Дата"" DESC";
        var result = await conn.QueryAsync<OtzyvDto>(sql, new { ProductId = productId });
        return Ok(result);
    }

    // GET api/reviews/buyer/5
    [HttpGet("buyer/{buyerId}")]
    public async Task<IActionResult> GetByBuyer(int buyerId)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT o.""Код_отзыва"" AS Kod_otzyva,
                   o.""Код_покупателя"" AS Kod_pokupatelya,
                   p.""Имя"" AS Imya_pokupatelya,
                   o.""Код_товара"" AS Kod_tovara,
                   t.""Наименование"" AS Naimenovanie,
                   o.""Текст"" AS Tekst,
                   o.""Оценка"" AS Ocenka,
                   o.""Дата"" AS Data
            FROM ""Отзыв"" o
            JOIN ""Покупатель"" p ON p.""Код_покупателя"" = o.""Код_покупателя""
            JOIN ""Товар"" t ON t.""Код_товара"" = o.""Код_товара""
            WHERE o.""Код_покупателя"" = @BuyerId
            ORDER BY o.""Дата"" DESC";
        var result = await conn.QueryAsync(sql, new { BuyerId = buyerId });
        return Ok(result);
    }

    // POST api/reviews
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] OtzyvCreateDto dto)
    {
        if (dto.Ocenka < 1 || dto.Ocenka > 5)
            return BadRequest(new { message = "Оценка должна быть от 1 до 5" });

        using var conn = _db.CreateConnection();

        // 1. Проверяем, покупал ли пользователь этот товар и получил его (статус 'Доставлен')
        var hasOrdered = await conn.ExecuteScalarAsync<bool>(@"
            SELECT EXISTS (
                SELECT 1
                FROM ""СодержимоеЗаказа"" sz
                JOIN ""Заказ"" z ON z.""Код_заказа"" = sz.""Код_заказа""
                WHERE z.""Код_покупателя"" = @Pok
                  AND sz.""Код_товара"" = @Tov
                  AND z.""Статус"" = 'Доставлен'
            )", new { Pok = dto.Kod_pokupatelya, Tov = dto.Kod_tovara });

        if (!hasOrdered)
            return BadRequest(new { message = "Вы можете оставить отзыв только на товары, которые вы заказывали и получили." });

        // 2. Проверяем, не оставлял ли уже отзыв
        var hasReview = await conn.ExecuteScalarAsync<bool>(@"
            SELECT EXISTS (
                SELECT 1 FROM ""Отзыв""
                WHERE ""Код_покупателя"" = @Pok AND ""Код_товара"" = @Tov
            )", new { Pok = dto.Kod_pokupatelya, Tov = dto.Kod_tovara });

        if (hasReview)
            return BadRequest(new { message = "Вы уже оставили отзыв на этот товар." });

        // 3. Вставляем отзыв
        var sql = @"
            INSERT INTO ""Отзыв"" (""Код_покупателя"", ""Код_товара"", ""Текст"", ""Оценка"")
            VALUES (@Pok, @Tov, @Tekst, @Ocenka)
            RETURNING ""Код_отзыва""";
        var newId = await conn.QuerySingleAsync<int>(sql, new
        {
            Pok = dto.Kod_pokupatelya,
            Tov = dto.Kod_tovara,
            Tekst = dto.Tekst,
            Ocenka = dto.Ocenka
        });
        return Ok(new { id = newId });
    }

    // DELETE api/reviews/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        using var conn = _db.CreateConnection();
        await conn.ExecuteAsync(
            @"DELETE FROM ""Отзыв"" WHERE ""Код_отзыва"" = @Id",
            new { Id = id });
        return NoContent();
    }
}
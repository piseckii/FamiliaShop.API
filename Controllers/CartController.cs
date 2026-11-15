using Dapper;
using FamiliaShop.API.Data;
using FamiliaShop.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace FamiliaShop.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CartController : ControllerBase
{
    private readonly DatabaseContext _db;
    public CartController(DatabaseContext db) => _db = db;

    // GET api/cart/5
    [HttpGet("{buyerId}")]
    public async Task<IActionResult> GetCart(int buyerId)
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT sk.""Код_товара"" AS Kod_tovara,
                   t.""Наименование"" AS Naimenovanie,
                   t.""Артикул"" AS Artikul,
                   t.""Цена"" AS Cena,
                   b.""Название"" AS Brand,
                   r.""Значение"" AS Razmer,
                   sk.""Количество"" AS Kolichestvo
            FROM ""СодержимоеКорзины"" sk
            JOIN ""Товар"" t ON t.""Код_товара"" = sk.""Код_товара""
            LEFT JOIN ""Бренд"" b ON b.""Код_бренда"" = t.""Код_бренда""
            LEFT JOIN ""Размер"" r ON r.""Код_размера"" = t.""Код_размера""
            WHERE sk.""Код_покупателя"" = @BuyerId";

        var items = await conn.QueryAsync<KorzinaItemDto>(sql, new { BuyerId = buyerId });
        return Ok(items);
    }

    // POST api/cart/5/items  { "kod_tovara": 3, "kolichestvo": 1 }
    [HttpPost("{buyerId}/items")]
    public async Task<IActionResult> AddItem(int buyerId, [FromBody] CartItemDto dto)
    {
        using var conn = _db.CreateConnection();

        // Ensure cart exists
        var cartExists = await conn.ExecuteScalarAsync<int>(
            @"SELECT COUNT(*) FROM ""Корзина"" WHERE ""Код_покупателя"" = @Id",
            new { Id = buyerId });
        if (cartExists == 0)
        {
            await conn.ExecuteAsync(
                @"INSERT INTO ""Корзина"" (""Код_покупателя"") VALUES (@Id)",
                new { Id = buyerId });
        }

        // Upsert item
        await conn.ExecuteAsync(@"
            INSERT INTO ""СодержимоеКорзины"" (""Код_покупателя"", ""Код_товара"", ""Количество"")
            VALUES (@BuyerId, @TovarId, @Qty)
            ON CONFLICT (""Код_покупателя"", ""Код_товара"")
            DO UPDATE SET ""Количество"" = ""СодержимоеКорзины"".""Количество"" + @Qty",
            new { BuyerId = buyerId, TovarId = dto.Kod_tovara, Qty = dto.Kolichestvo });

        return Ok(new { success = true, message = "Товар добавлен в корзину" });
    }

    // PUT api/cart/5/items/3  { "kolichestvo": 2 }
    [HttpPut("{buyerId}/items/{tovarId}")]
    public async Task<IActionResult> UpdateItem(int buyerId, int tovarId, [FromBody] CartQtyDto dto)
    {
        using var conn = _db.CreateConnection();
        if (dto.Kolichestvo <= 0)
        {
            await conn.ExecuteAsync(
                @"DELETE FROM ""СодержимоеКорзины"" WHERE ""Код_покупателя"" = @B AND ""Код_товара"" = @T",
                new { B = buyerId, T = tovarId });
        }
        else
        {
            await conn.ExecuteAsync(
                @"UPDATE ""СодержимоеКорзины"" SET ""Количество"" = @Qty
                  WHERE ""Код_покупателя"" = @B AND ""Код_товара"" = @T",
                new { Qty = dto.Kolichestvo, B = buyerId, T = tovarId });
        }
        return NoContent();
    }

    // DELETE api/cart/5/items/3
    [HttpDelete("{buyerId}/items/{tovarId}")]
    public async Task<IActionResult> RemoveItem(int buyerId, int tovarId)
    {
        using var conn = _db.CreateConnection();
        await conn.ExecuteAsync(
            @"DELETE FROM ""СодержимоеКорзины"" WHERE ""Код_покупателя"" = @B AND ""Код_товара"" = @T",
            new { B = buyerId, T = tovarId });
        return NoContent();
    }

    // DELETE api/cart/5
    [HttpDelete("{buyerId}")]
    public async Task<IActionResult> ClearCart(int buyerId)
    {
        using var conn = _db.CreateConnection();
        await conn.ExecuteAsync(
            @"DELETE FROM ""СодержимоеКорзины"" WHERE ""Код_покупателя"" = @B",
            new { B = buyerId });
        return NoContent();
    }
}

public class CartItemDto
{
    public int Kod_tovara { get; set; }
    public int Kolichestvo { get; set; } = 1;
}

public class CartQtyDto
{
    public int Kolichestvo { get; set; }
}
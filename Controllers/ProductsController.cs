using Dapper;
using FamiliaShop.API.Data;
using FamiliaShop.API.DTOs;
using Microsoft.AspNetCore.Mvc;
using Npgsql;

namespace FamiliaShop.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly DatabaseContext _db;
    public ProductsController(DatabaseContext db) => _db = db;

    // GET api/products — читаем из представления v_Каталог
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] int?     kategoria,
        [FromQuery] int?     brand,
        [FromQuery] decimal? minPrice,
        [FromQuery] decimal? maxPrice,
        [FromQuery] string?  search,
        [FromQuery] int?     razmer)
    {
        using var conn = _db.CreateConnection();

        // v_Каталог уже содержит бренд, размер, рейтинг и скидки
        var sql = @"
            SELECT DISTINCT
                ""Код_товара""          AS ""Kod_tovara"",
                ""Артикул""             AS ""Artikul"",
                ""Наименование""        AS ""Naimenovanie"",
                ""Описание""            AS ""Opisanie"",
                ""Цена""                AS ""Cena"",
                ""Бренд""               AS ""Brand"",
                ""Код_бренда""          AS ""Kod_brenda"",
                ""Размер""              AS ""Razmer"",
                ""Код_размера""         AS ""Kod_razmera"",
                ""Средняя_оценка""      AS ""Srednyaya_ocenka"",
                ""Количество_отзывов""  AS ""Kolichestvo_otzyvov"",
                ""Тип_скидки""          AS ""Tip_skidki"",
                ""Размер_скидки""       AS ""Razmer_skidki"",
                ""Цена_со_скидкой""     AS ""Cena_so_skidkoy"",
                ""Категории""           AS ""Kategorii_str""
            FROM ""v_Каталог""
            WHERE 1=1
        ";
        

        var parameters = new DynamicParameters();

        if (brand.HasValue)
        {
            sql += @" AND ""Код_бренда"" = @Brand";
            parameters.Add("Brand", brand.Value);
        }
        if (minPrice.HasValue)
        {
            sql += @" AND ""Цена"" >= @MinPrice";
            parameters.Add("MinPrice", minPrice.Value);
        }
        if (maxPrice.HasValue)
        {
            sql += @" AND ""Цена"" <= @MaxPrice";
            parameters.Add("MaxPrice", maxPrice.Value);
        }
        if (!string.IsNullOrWhiteSpace(search))
        {
            sql += @" AND (""Наименование"" ILIKE @Search OR ""Артикул"" ILIKE @Search OR ""Бренд"" ILIKE @Search)";
            parameters.Add("Search", $"%{search}%");
        }
        if (razmer.HasValue)
        {
            sql += @" AND ""Код_размера"" = @Razmer";
            parameters.Add("Razmer", razmer.Value);
        }
        if (kategoria.HasValue)
        {
            // Фильтр по категории через подзапрос к ТоварКатегория
            sql += @" AND ""Код_товара"" IN (
                SELECT ""Код_товара"" FROM ""ТоварКатегория""
                WHERE ""Код_категории"" = @Kategoria)";
            parameters.Add("Kategoria", kategoria.Value);
        }

        sql += @" ORDER BY ""Код_товара""";

        var rows = await conn.QueryAsync(sql, parameters);

        // Маппим в ProductDto — все касты через Convert чтобы избежать
        // RuntimeBinderException при null или несовпадении типов (long vs int)
        var products = rows.Select(r => MapProductDto(r)).ToList();

        return Ok(products);
    }

    // GET api/products/5 — карточка товара из v_Каталог
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        using var conn = _db.CreateConnection();

        var sql = @"
            SELECT
                ""Код_товара""          AS ""Kod_tovara"",
                ""Артикул""             AS ""Artikul"",
                ""Наименование""        AS ""Naimenovanie"",
                ""Описание""            AS ""Opisanie"",
                ""Цена""                AS ""Cena"",
                ""Бренд""               AS ""Brand"",
                ""Код_бренда""          AS ""Kod_brenda"",
                ""Размер""              AS ""Razmer"",
                ""Код_размера""         AS ""Kod_razmera"",
                ""Средняя_оценка""      AS ""Srednyaya_ocenka"",
                ""Количество_отзывов""  AS ""Kolichestvo_otzyvov"",
                ""Тип_скидки""          AS ""Tip_skidki"",
                ""Размер_скидки""       AS ""Razmer_skidki"",
                ""Цена_со_скидкой""     AS ""Cena_so_skidkoy"",
                ""Категории""           AS ""Kategorii_str""
            FROM ""v_Каталог""
            WHERE ""Код_товара"" = @Id
            LIMIT 1";

        var r = await conn.QueryFirstOrDefaultAsync(sql, new { Id = id });
        if (r == null) return NotFound();

        return Ok(MapProductDto(r));
    }

    // POST api/products — вызываем хранимую процедуру sp_ДобавитьТовар
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] ProductCreateDto dto)
    {
        using var conn = (NpgsqlConnection)_db.CreateConnection();
        await conn.OpenAsync();

        try
        {
            // Формируем массив категорий для PostgreSQL
            var kategoriiArray = dto.Kategorii != null && dto.Kategorii.Count > 0
                ? dto.Kategorii.ToArray()
                : Array.Empty<int>();

            using var cmd = new NpgsqlCommand(
                "CALL sp_ДобавитьТовар(@p_brand, @p_razmer, @p_art, @p_name, @p_desc, @p_price, @p_kats, @p_new_id)",
                conn);

            cmd.Parameters.AddWithValue("p_brand",
                dto.Kod_brenda.HasValue ? (object)dto.Kod_brenda.Value : DBNull.Value);
            cmd.Parameters.AddWithValue("p_razmer",
                dto.Kod_razmera.HasValue ? (object)dto.Kod_razmera.Value : DBNull.Value);
            cmd.Parameters.AddWithValue("p_art",   dto.Artikul);
            cmd.Parameters.AddWithValue("p_name",  dto.Naimenovanie);
            cmd.Parameters.AddWithValue("p_desc",
                string.IsNullOrEmpty(dto.Opisanie) ? DBNull.Value : (object)dto.Opisanie);
            cmd.Parameters.AddWithValue("p_price", dto.Cena);
            cmd.Parameters.Add(new NpgsqlParameter("p_kats", NpgsqlTypes.NpgsqlDbType.Array | NpgsqlTypes.NpgsqlDbType.Integer)
            {
                Value = kategoriiArray
            });

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
            return BadRequest(new { message = ex.MessageText });
        }
    }

    // PUT api/products/5 — обновляем товар напрямую (UPDATE через v_Каталог недоступен для всех полей)
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, [FromBody] ProductCreateDto dto)
    {
        using var conn = _db.CreateConnection();
        conn.Open();
        using var tx = conn.BeginTransaction();

        try
        {
            await conn.ExecuteAsync(@"
                UPDATE ""Товар"" SET
                    ""Код_бренда""  = @Brend,
                    ""Код_размера"" = @Razmer,
                    ""Артикул""     = @Artikul,
                    ""Наименование""= @Name,
                    ""Описание""    = @Desc,
                    ""Цена""        = @Price
                WHERE ""Код_товара"" = @Id",
                new {
                    Brend  = dto.Kod_brenda,
                    Razmer = dto.Kod_razmera,
                    Artikul= dto.Artikul,
                    Name   = dto.Naimenovanie,
                    Desc   = dto.Opisanie,
                    Price  = dto.Cena,
                    Id     = id
                }, tx);

            await conn.ExecuteAsync(
                @"DELETE FROM ""ТоварКатегория"" WHERE ""Код_товара"" = @Id",
                new { Id = id }, tx);

            if (dto.Kategorii != null)
            {
                foreach (var katId in dto.Kategorii)
                {
                    await conn.ExecuteAsync(
                        @"INSERT INTO ""ТоварКатегория"" (""Код_товара"", ""Код_категории"")
                          VALUES (@T, @K) ON CONFLICT DO NOTHING",
                        new { T = id, K = katId }, tx);
                }
            }

            tx.Commit();
            return NoContent();
        }
        catch
        {
            tx.Rollback();
            throw;
        }
    }

    // DELETE api/products/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        using var conn = _db.CreateConnection();
        await conn.ExecuteAsync(
            @"DELETE FROM ""Товар"" WHERE ""Код_товара"" = @Id",
            new { Id = id });
        return NoContent();
    }

    // GET api/products/stats — рейтинг товаров из представления v_РейтингТоваров
    [HttpGet("stats")]
    public async Task<IActionResult> GetStats()
    {
        using var conn = _db.CreateConnection();
        var sql = @"
            SELECT
                ""Код_товара""          AS Kod_tovara,
                ""Наименование""        AS Naimenovanie,
                ""Артикул""             AS Artikul,
                ""Цена_базовая""        AS Cena_bazovaya,
                ""Бренд""               AS Brand,
                ""Количество_отзывов""  AS Kolichestvo_otzyvov,
                ""Средняя_оценка""      AS Srednyaya_ocenka,
                ""Оценок_5""            AS Otsenok_5,
                ""Оценок_4""            AS Otsenok_4,
                ""Оценок_3""            AS Otsenok_3,
                ""Оценок_1_2""          AS Otsenok_1_2,
                ""Продано_штук""        AS Prodano_shtuk,
                ""Выручка_всего""       AS Viruchka_vsego,
                ""Активных_скидок""     AS Aktivnyh_skidok
            FROM ""v_РейтингТоваров""
            ORDER BY ""Средняя_оценка"" DESC NULLS LAST, ""Продано_штук"" DESC";

        var result = await conn.QueryAsync(sql);
        return Ok(result);
    }

    // Вспомогательный метод: безопасный маппинг dynamic → ProductDto.
    // Dapper возвращает числовые поля PostgreSQL как long (int8),
    // а nullable-колонки (LEFT JOIN) могут быть null — прямой каст (int) падает.
    // Используем Convert.ToInt32 / оператор ?. для всех полей.
    private static ProductDto MapProductDto(dynamic r)
    {
        // Разбиваем строку категорий "Платья, Юбки" в список
        var kategoriiStr = r.Kategorii_str as string;
        var kategorii = !string.IsNullOrEmpty(kategoriiStr)
            ? kategoriiStr.Split(", ", StringSplitOptions.RemoveEmptyEntries).ToList()
            : new List<string>();

        // Скидка: собираем из двух отдельных полей представления
        var skidki = new List<SkidkaDto>();
        if (r.Tip_skidki != null && r.Razmer_skidki != null)
        {
            skidki.Add(new SkidkaDto
            {
                Tip    = (string)r.Tip_skidki,
                Razmer = Convert.ToDecimal(r.Razmer_skidki)
            });
        }

        return new ProductDto
        {
            Kod_tovara          = Convert.ToInt32(r.Kod_tovara),
            Artikul             = r.Artikul as string,
            Naimenovanie        = r.Naimenovanie as string,
            Opisanie            = r.Opisanie as string,
            Cena                = Convert.ToDecimal(r.Cena),
            Brand               = r.Brand as string,
            Kod_brenda          = r.Kod_brenda  == null ? (int?)null : Convert.ToInt32(r.Kod_brenda),
            Razmer              = r.Razmer as string,
            Kod_razmera         = r.Kod_razmera == null ? (int?)null : Convert.ToInt32(r.Kod_razmera),
            Srednyaya_ocenka    = r.Srednyaya_ocenka  == null ? (double?)null : Convert.ToDouble(r.Srednyaya_ocenka),
            Kolichestvo_otzyvov = r.Kolichestvo_otzyvov == null ? (int?)null : Convert.ToInt32(r.Kolichestvo_otzyvov),
            Tip_skidki          = r.Tip_skidki as string,
            Razmer_skidki       = r.Razmer_skidki  == null ? (decimal?)null : Convert.ToDecimal(r.Razmer_skidki),
            Cena_so_skidkoy     = r.Cena_so_skidkoy == null ? (decimal?)null : Convert.ToDecimal(r.Cena_so_skidkoy),
            Kategorii           = kategorii,
            Skidki              = skidki
        };
    }
}
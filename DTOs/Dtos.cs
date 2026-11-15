namespace FamiliaShop.API.DTOs;

// ---- Товар ----
public class ProductDto
{
    public int Kod_tovara { get; set; }
    public string? Artikul { get; set; }
    public string? Naimenovanie { get; set; }
    public string? Opisanie { get; set; }
    public decimal Cena { get; set; }
    public string? Brand { get; set; }
    public int? Kod_brenda { get; set; }
    public string? Razmer { get; set; }
    public string? Tip_razmernoy_setki { get; set; }
    public int? Kod_razmera { get; set; }
    public double? Srednyaya_ocenka { get; set; }
    public int? Kolichestvo_otzyvov { get; set; }
    // Из v_Каталог — скидка и итоговая цена
    public string? Tip_skidki { get; set; }
    public decimal? Razmer_skidki { get; set; }
    public decimal? Cena_so_skidkoy { get; set; }
    // Категории: список строк (заполняется из Kategorii_str)
    public List<string>? Kategorii { get; set; }
    // Устаревшее поле — оставляем для совместимости с фронтом
    public List<SkidkaDto>? Skidki { get; set; }
}

public class ProductCreateDto
{
    public int? Kod_brenda { get; set; }
    public int? Kod_razmera { get; set; }
    public string Artikul { get; set; } = "";
    public string Naimenovanie { get; set; } = "";
    public string? Opisanie { get; set; }
    public decimal Cena { get; set; }
    public List<int>? Kategorii { get; set; }
}

// ---- Покупатель ----
public class BuyerDto
{
    public int Kod_pokupatelya { get; set; }
    public string? Imya { get; set; }
    public string? Email { get; set; }
    public string? Telefon { get; set; }
    public DateTime Data_registracii { get; set; }
}

public class BuyerCreateDto
{
    public string Imya { get; set; } = "";
    public string Email { get; set; } = "";
    public string? Telefon { get; set; }
}

// ---- Адрес ----
public class AdresDto
{
    public int Kod_adresa { get; set; }
    public int Kod_pokupatelya { get; set; }
    public string? Naselennyy_punkt { get; set; }
    public string? Ulica { get; set; }
    public string? Dom { get; set; }
    public string? Kvartira { get; set; }
    public string? Pochtovyy_indeks { get; set; }
}

public class AdresCreateDto
{
    public int Kod_pokupatelya { get; set; }
    public string Naselennyy_punkt { get; set; } = "";
    public string Ulica { get; set; } = "";
    public string Dom { get; set; } = "";
    public string? Kvartira { get; set; }
    public string Pochtovyy_indeks { get; set; } = "";
}

// ---- Заказ ----
public class ZakazDto
{
    public int Kod_zakaza { get; set; }
    public int Kod_pokupatelya { get; set; }
    public string? Imya_pokupatelya { get; set; }
    public string? Email_pokupatelya { get; set; }
    public string? Telefon_pokupatelya { get; set; }
    public int Kod_adresa { get; set; }
    public string? Adres_polnyy { get; set; }
    public int Kod_sposoba_polucheniya { get; set; }
    public string? Sposob_polucheniya { get; set; }
    public int Kod_sposoba_oplaty { get; set; }
    public string? Sposob_oplaty { get; set; }
    public int? Kod_kupona { get; set; }
    public string? Promokod { get; set; }
    public string? Tip_kupona { get; set; }
    public decimal? Razmer_kupona { get; set; }
    public DateTime Data_oformleniya { get; set; }
    public decimal Itogovaya_summa { get; set; }
    public string? Status { get; set; }
    public int? Kolichestvo_poziciy { get; set; }
    public string? Sostav_zakaza { get; set; }   // из v_ЗаказыПолные
    public List<ZakazTovarDto>? Tovary { get; set; }
}

public class ZakazTovarDto
{
    public int Kod_tovara { get; set; }
    public string? Naimenovanie { get; set; }
    public string? Artikul { get; set; }
    public int Kolichestvo { get; set; }
    public decimal Cena_na_moment_pokupki { get; set; }
}

// DTO для создания заказа через sp_ОформитьЗаказ:
// товары берутся из корзины в БД, список передавать не нужно
public class ZakazFromCartDto
{
    public int  Kod_pokupatelya             { get; set; }
    public int  Kod_adresa                  { get; set; }
    public int  Kod_sposoba_polucheniya     { get; set; }
    public int  Kod_sposoba_oplaty          { get; set; }
    public int? Kod_kupona                  { get; set; }
}

// Старый DTO — оставляем чтобы не ломать другие места компиляции
public class ZakazCreateDto
{
    public int Kod_pokupatelya { get; set; }
    public int Kod_adresa { get; set; }
    public int Kod_sposoba_polucheniya { get; set; }
    public int Kod_sposoba_oplaty { get; set; }
    public int? Kod_kupona { get; set; }
    public decimal Itogovaya_summa { get; set; }
    public List<ZakazTovarCreateDto> Tovary { get; set; } = new();
}

public class ZakazTovarCreateDto
{
    public int Kod_tovara { get; set; }
    public int Kolichestvo { get; set; }
    public decimal Cena_na_moment_pokupki { get; set; }
}

// ---- Корзина ----
public class KorzinaItemDto
{
    public int Kod_tovara { get; set; }
    public string? Naimenovanie { get; set; }
    public string? Artikul { get; set; }
    public decimal Cena { get; set; }
    public string? Brand { get; set; }
    public string? Razmer { get; set; }
    public int Kolichestvo { get; set; }
}

// ---- Отзыв ----
public class OtzyvDto
{
    public int Kod_otzyva { get; set; }
    public int Kod_pokupatelya { get; set; }
    public string? Imya_pokupatelya { get; set; }
    public int Kod_tovara { get; set; }
    public string? Naimenovanie { get; set; }
    public string? Tekst { get; set; }
    public int Ocenka { get; set; }
    public DateTime Data { get; set; }
}

public class OtzyvCreateDto
{
    public int Kod_pokupatelya { get; set; }
    public int Kod_tovara { get; set; }
    public string? Tekst { get; set; }
    public int Ocenka { get; set; }
}

// ---- Скидка / Купон ----
public class SkidkaDto
{
    public int Kod_skidki { get; set; }
    public string? Nazvanie { get; set; }
    public string? Tip { get; set; }
    public decimal Razmer { get; set; }
    public DateTime Data_nachala { get; set; }
    public DateTime Data_okonchaniya { get; set; }
}

public class KuponDto
{
    public int Kod_kupona { get; set; }
    public string? Promokod { get; set; }
    public string? Tip_skidki { get; set; }
    public decimal Razmer_skidki { get; set; }
    public DateTime Data_nachala { get; set; }
    public DateTime Data_okonchaniya { get; set; }
    public decimal Minimalnaya_summa_zakaza { get; set; }
}

// ---- Лог статусов ----
public class LogStatusaDto
{
    public int Kod_zapisi { get; set; }
    public int Kod_zakaza { get; set; }
    public string? Status_staryy { get; set; }
    public string? Status_novyy { get; set; }
    public DateTime Data_izmeneniya { get; set; }
    public string? Kommentariy { get; set; }
}

// ---- Статистика товара (из v_РейтингТоваров) ----
public class ProductStatsDto
{
    public int Kod_tovara { get; set; }
    public string? Naimenovanie { get; set; }
    public string? Artikul { get; set; }
    public decimal Cena_bazovaya { get; set; }
    public string? Brand { get; set; }
    public long Kolichestvo_otzyvov { get; set; }
    public double? Srednyaya_ocenka { get; set; }
    public int? Otsenok_5 { get; set; }
    public int? Otsenok_4 { get; set; }
    public int? Otsenok_3 { get; set; }
    public int? Otsenok_1_2 { get; set; }
    public long Prodano_shtuk { get; set; }
    public decimal Viruchka_vsego { get; set; }
    public long Aktivnyh_skidok { get; set; }
}

// ---- Справочники ----
public class BrendDto
{
    public int Kod_brenda { get; set; }
    public string? Nazvanie { get; set; }
    public string? Strana_proiskhozhdeniya { get; set; }
    public string? Opisanie { get; set; }
}

public class RazmerDto
{
    public int Kod_razmera { get; set; }
    public string? Znachenie { get; set; }
    public string? Tip_razmernoy_setki { get; set; }
}

public class KategoriyaDto
{
    public int Kod_kategorii { get; set; }
    public string? Nazvanie { get; set; }
    public string? Opisanie { get; set; }
}

public class SpособPolucheniyaDto
{
    public int Kod_sposoba_polucheniya { get; set; }
    public string? Nazvanie { get; set; }
    public string? Opisanie { get; set; }
}

public class SposobOplatyDto
{
    public int Kod_sposoba_oplaty { get; set; }
    public string? Nazvanie { get; set; }
    public string? Opisanie { get; set; }
}
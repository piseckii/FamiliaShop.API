--
-- PostgreSQL database dump
--


-- Dumped from database version 16.10
-- Dumped by pg_dump version 16.10

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: email_type; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.email_type AS character varying(200) NOT NULL
	CONSTRAINT chk_email_format CHECK (((VALUE)::text ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'::text));


--
-- Name: DOMAIN email_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON DOMAIN public.email_type IS 'Пользовательский тип для хранения email-адреса. Проверяет формат через регулярное выражение.';


--
-- Name: fn_АвтоКорзина(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."fn_АвтоКорзина"() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "Корзина" ("Код_покупателя", "Дата_обновления")
    VALUES (NEW."Код_покупателя", NOW())
    ON CONFLICT ("Код_покупателя") DO NOTHING;

    RAISE NOTICE 'Корзина автоматически создана для покупателя %',
        NEW."Код_покупателя";

    RETURN NEW;
END;
$$;


--
-- Name: fn_ЛогСтатусов(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."fn_ЛогСтатусов"() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Курсор: последние 5 записей лога по данному заказу
    cur_history CURSOR FOR
        SELECT "Статус_новый", "Дата_изменения"
        FROM "ЛогСтатусовЗаказа"
        WHERE "Код_заказа" = NEW."Код_заказа"
        ORDER BY "Дата_изменения" DESC
        LIMIT 5;

    v_log_rec       RECORD;
    v_last_status   VARCHAR(50) := NULL;
    v_comment       TEXT;
    -- Допустимые переходы статусов
    v_valid         BOOLEAN := TRUE;
BEGIN
    -- Игнорируем если статус не изменился
    IF NEW."Статус" = OLD."Статус" THEN
        RETURN NEW;
    END IF;

    -- Через курсор читаем историю статусов заказа
    -- и выясняем последний зафиксированный статус
    OPEN cur_history;
    FETCH cur_history INTO v_log_rec;
    IF FOUND THEN
        v_last_status := v_log_rec."Статус_новый";
    END IF;
    CLOSE cur_history;

    -- Проверяем допустимость перехода
    -- Нельзя вернуть отменённый или доставленный заказ назад
    IF OLD."Статус" IN ('Доставлен', 'Отменён') THEN
        RAISE EXCEPTION
            'Нельзя изменить статус заказа #% — он уже "%"',
            NEW."Код_заказа", OLD."Статус";
    END IF;

    -- Формируем комментарий к записи лога
    v_comment := FORMAT(
        'Смена статуса заказа #%s: "%s" → "%s"',
        NEW."Код_заказа", OLD."Статус", NEW."Статус"
    );

    -- Записываем в лог
    INSERT INTO "ЛогСтатусовЗаказа"
        ("Код_заказа", "Статус_старый", "Статус_новый",
         "Дата_изменения", "Комментарий")
    VALUES
        (NEW."Код_заказа", OLD."Статус", NEW."Статус",
         NOW(), v_comment);

    RAISE NOTICE '%', v_comment;
    RETURN NEW;
END;
$$;


--
-- Name: fn_ПереносКорзиныВЗаказ(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."fn_ПереносКорзиныВЗаказ"() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    cur_korzina CURSOR (p_pokupatel INTEGER) FOR
        SELECT
            sk."Код_товара",
            sk."Количество",
            t."Цена" AS "Цена_на_момент"
        FROM "СодержимоеКорзины" sk
        JOIN "Товар" t ON t."Код_товара" = sk."Код_товара"
        WHERE sk."Код_покупателя" = p_pokupatel;

    v_rec           RECORD;
    v_subtotal      NUMERIC(12,2) := 0;
    v_skidka        NUMERIC(12,2) := 0;
    v_itog          NUMERIC(12,2) := 0;
    v_kupon         RECORD;
    v_count         INTEGER := 0;
BEGIN
    -- Если в заказе уже есть позиции – выходим (защита от дублирования)
    IF EXISTS (SELECT 1 FROM "СодержимоеЗаказа" WHERE "Код_заказа" = NEW."Код_заказа") THEN
        RAISE NOTICE 'Триггер: заказ #% уже содержит позиции, пропускаем.', NEW."Код_заказа";
        RETURN NEW;
    END IF;

    -- Проверяем, есть ли товары в корзине
    IF NOT EXISTS (SELECT 1 FROM "СодержимоеКорзины" WHERE "Код_покупателя" = NEW."Код_покупателя") THEN
        RAISE NOTICE 'Корзина покупателя % пуста, заказ #% останется без товаров.', NEW."Код_покупателя", NEW."Код_заказа";
        RETURN NEW;
    END IF;

    -- Переносим товары из корзины
    OPEN cur_korzina(NEW."Код_покупателя");
    LOOP
        FETCH cur_korzina INTO v_rec;
        EXIT WHEN NOT FOUND;

        INSERT INTO "СодержимоеЗаказа"
            ("Код_заказа", "Код_товара", "Количество", "Цена_на_момент_покупки")
        VALUES
            (NEW."Код_заказа", v_rec."Код_товара", v_rec."Количество", v_rec."Цена_на_момент")
        ON CONFLICT ("Код_заказа", "Код_товара") DO NOTHING;

        v_subtotal := v_subtotal + (v_rec."Цена_на_момент" * v_rec."Количество");
        v_count := v_count + 1;
    END LOOP;
    CLOSE cur_korzina;

    -- ★★★ НОВАЯ ПРОВЕРКА МИНИМАЛЬНОЙ СУММЫ ДЛЯ КУПОНА ★★★
    IF NEW."Код_купона" IS NOT NULL THEN
        SELECT * INTO v_kupon
        FROM "Купон"
        WHERE "Код_купона" = NEW."Код_купона"
          AND "Дата_начала" <= CURRENT_DATE
          AND "Дата_окончания" >= CURRENT_DATE;

        IF FOUND THEN
            -- Проверяем минимальную сумму заказа
            IF v_subtotal < v_kupon."Минимальная_сумма_заказа" THEN
                RAISE EXCEPTION 'Сумма заказа (%.2f ₽) меньше минимальной для купона "%" (%.2f ₽)',
                    v_subtotal, v_kupon."Промокод", v_kupon."Минимальная_сумма_заказа";
            END IF;

            -- Применяем скидку
            IF v_kupon."Тип_скидки" = 'процентная' THEN
                v_skidka := ROUND(v_subtotal * v_kupon."Размер_скидки" / 100, 2);
            ELSE
                v_skidka := LEAST(v_kupon."Размер_скидки", v_subtotal);
            END IF;
        ELSE
            RAISE WARNING 'Купон % неактивен, скидка не применена.', NEW."Код_купона";
        END IF;
    END IF;

    v_itog := GREATEST(v_subtotal - v_skidka, 0);

    -- Обновляем итоговую сумму в заказе
    UPDATE "Заказ"
       SET "Итоговая_сумма" = v_itog
     WHERE "Код_заказа" = NEW."Код_заказа";

    -- Очищаем корзину
    DELETE FROM "СодержимоеКорзины"
    WHERE "Код_покупателя" = NEW."Код_покупателя";

    -- Обновляем дату корзины
    UPDATE "Корзина"
       SET "Дата_обновления" = NOW()
     WHERE "Код_покупателя" = NEW."Код_покупателя";

    RAISE NOTICE 'Триггер: перенесено % позиций в заказ #%, сумма товаров %.2f ₽, скидка %.2f ₽, итого %.2f ₽',
        v_count, NEW."Код_заказа", v_subtotal, v_skidka, v_itog;

    RETURN NEW;
END;
$$;


--
-- Name: fn_ПересчётИтогаЗаказа(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."fn_ПересчётИтогаЗаказа"() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Внешний курсор: уникальные заказы, затронутые операцией
    -- (в AFTER-триггере FOR EACH ROW всегда один заказ,
    --  но оформляем через курсор для демонстрации вложенности)
    cur_zakazy CURSOR FOR
        SELECT DISTINCT "Код_заказа"
        FROM "СодержимоеЗаказа"
        WHERE "Код_заказа" = NEW."Код_заказа";

    -- Внутренний курсор: позиции конкретного заказа
    cur_pozicii CURSOR (p_zakaz_id INTEGER) FOR
        SELECT
            sz."Количество",
            sz."Цена_на_момент_покупки"
        FROM "СодержимоеЗаказа" sz
        WHERE sz."Код_заказа" = p_zakaz_id;

    v_zakaz_id      INTEGER;
    v_poziciya      RECORD;
    v_new_itogo     NUMERIC(12,2);
    v_kupon         RECORD;
    v_skidka        NUMERIC(12,2) := 0;
    v_subtotal      NUMERIC(12,2);
BEGIN
    -- Внешний курсор: перебираем затронутые заказы
    OPEN cur_zakazy;
    LOOP
        FETCH cur_zakazy INTO v_zakaz_id;
        EXIT WHEN NOT FOUND;

        v_subtotal := 0;

        -- Внутренний (вложенный) курсор: суммируем позиции заказа
        OPEN cur_pozicii(v_zakaz_id);
        LOOP
            FETCH cur_pozicii INTO v_poziciya;
            EXIT WHEN NOT FOUND;

            v_subtotal := v_subtotal +
                (v_poziciya."Цена_на_момент_покупки" * v_poziciya."Количество");
        END LOOP;
        CLOSE cur_pozicii;

        -- Учитываем купон если есть
        v_skidka := 0;
        SELECT k.* INTO v_kupon
        FROM "Заказ" z
        JOIN "Купон" k ON k."Код_купона" = z."Код_купона"
        WHERE z."Код_заказа" = v_zakaz_id
          AND k."Дата_начала" <= CURRENT_DATE
          AND k."Дата_окончания" >= CURRENT_DATE;

        IF FOUND THEN
            IF v_kupon."Тип_скидки" = 'процентная' THEN
                v_skidka := ROUND(
                    v_subtotal * v_kupon."Размер_скидки" / 100, 2
                );
            ELSE
                v_skidka := LEAST(v_kupon."Размер_скидки", v_subtotal);
            END IF;
        END IF;

        v_new_itogo := GREATEST(v_subtotal - v_skidka, 0);

        -- Обновляем итоговую сумму заказа
        UPDATE "Заказ"
           SET "Итоговая_сумма" = v_new_itogo
         WHERE "Код_заказа" = v_zakaz_id;

        RAISE NOTICE
            'Пересчёт заказа #%: подитог %.2f ₽, скидка %.2f ₽, итого %.2f ₽',
            v_zakaz_id, v_subtotal, v_skidka, v_new_itogo;
    END LOOP;
    CLOSE cur_zakazy;

    RETURN NEW;
END;
$$;


--
-- Name: sp_ДобавитьТовар(integer, integer, character varying, character varying, text, numeric, integer[]); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."sp_ДобавитьТовар"(IN p_kod_brenda integer, IN p_kod_razmera integer, IN p_artikul character varying, IN p_naimenovanie character varying, IN p_opisanie text, IN p_cena numeric, IN p_kategorii integer[], OUT p_new_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_kat_id    INTEGER;
BEGIN
    -- Проверки входных данных
    IF p_artikul IS NULL OR TRIM(p_artikul) = '' THEN
        RAISE EXCEPTION 'Артикул не может быть пустым';
    END IF;

    IF p_naimenovanie IS NULL OR TRIM(p_naimenovanie) = '' THEN
        RAISE EXCEPTION 'Наименование не может быть пустым';
    END IF;

    IF p_cena < 0 THEN
        RAISE EXCEPTION 'Цена не может быть отрицательной: %', p_cena;
    END IF;

    IF EXISTS (
        SELECT 1 FROM "Товар" WHERE "Артикул" = p_artikul
    ) THEN
        RAISE EXCEPTION 'Товар с артикулом "%" уже существует', p_artikul;
    END IF;

    -- Вставляем товар
    INSERT INTO "Товар"
        ("Код_бренда", "Код_размера", "Артикул",
         "Наименование", "Описание", "Цена")
    VALUES
        (p_kod_brenda, p_kod_razmera, p_artikul,
         p_naimenovanie, p_opisanie, p_cena)
    RETURNING "Код_товара" INTO p_new_id;

    -- Привязываем категории (если переданы)
    IF p_kategorii IS NOT NULL AND array_length(p_kategorii, 1) > 0 THEN
        FOREACH v_kat_id IN ARRAY p_kategorii
        LOOP
            -- Проверяем существование категории
            IF NOT EXISTS (
                SELECT 1 FROM "Категория"
                WHERE "Код_категории" = v_kat_id
            ) THEN
                RAISE WARNING 'Категория % не найдена, пропускаем', v_kat_id;
                CONTINUE;
            END IF;

            INSERT INTO "ТоварКатегория"
                ("Код_товара", "Код_категории")
            VALUES
                (p_new_id, v_kat_id)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    RAISE NOTICE 'Товар "%" добавлен с кодом %', p_naimenovanie, p_new_id;
END;
$$;


--
-- Name: PROCEDURE "sp_ДобавитьТовар"(IN p_kod_brenda integer, IN p_kod_razmera integer, IN p_artikul character varying, IN p_naimenovanie character varying, IN p_opisanie text, IN p_cena numeric, IN p_kategorii integer[], OUT p_new_id integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON PROCEDURE public."sp_ДобавитьТовар"(IN p_kod_brenda integer, IN p_kod_razmera integer, IN p_artikul character varying, IN p_naimenovanie character varying, IN p_opisanie text, IN p_cena numeric, IN p_kategorii integer[], OUT p_new_id integer) IS 'Добавляет новый товар в каталог. Выполняет проверки артикула и цены, привязывает категории. Таблицы: Товар, ТоварКатегория.';


--
-- Name: sp_ОбновитьПокупателя(integer, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."sp_ОбновитьПокупателя"(IN p_kod_pokupatelya integer, IN p_imya character varying, IN p_email character varying, IN p_telefon character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rows_updated INTEGER;
BEGIN
    -- Проверяем существование покупателя
    IF NOT EXISTS (
        SELECT 1 FROM "Покупатель"
        WHERE "Код_покупателя" = p_kod_pokupatelya
    ) THEN
        RAISE EXCEPTION 'Покупатель % не найден', p_kod_pokupatelya;
    END IF;

    -- Проверяем имя
    IF p_imya IS NULL OR TRIM(p_imya) = '' THEN
        RAISE EXCEPTION 'Имя покупателя не может быть пустым';
    END IF;

    -- Проверяем что email не занят другим покупателем
    IF EXISTS (
        SELECT 1 FROM "Покупатель"
        WHERE "Email"::VARCHAR = p_email
          AND "Код_покупателя" <> p_kod_pokupatelya
    ) THEN
        RAISE EXCEPTION 'Email "%" уже используется другим покупателем', p_email;
    END IF;

    -- Обновляем профиль
    UPDATE "Покупатель"
       SET "Имя"     = p_imya,
           "Email"   = p_email::email_type,
           "Телефон" = p_telefon
     WHERE "Код_покупателя" = p_kod_pokupatelya;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    IF v_rows_updated = 0 THEN
        RAISE WARNING 'Данные покупателя % не изменились', p_kod_pokupatelya;
    ELSE
        RAISE NOTICE 'Профиль покупателя % обновлён', p_kod_pokupatelya;
    END IF;
END;
$$;


--
-- Name: PROCEDURE "sp_ОбновитьПокупателя"(IN p_kod_pokupatelya integer, IN p_imya character varying, IN p_email character varying, IN p_telefon character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON PROCEDURE public."sp_ОбновитьПокупателя"(IN p_kod_pokupatelya integer, IN p_imya character varying, IN p_email character varying, IN p_telefon character varying) IS 'Обновляет профиль покупателя: имя, email, телефон. Проверяет уникальность email и существование записи. Таблица: Покупатель.';


--
-- Name: sp_ОформитьЗаказ(integer, integer, integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."sp_ОформитьЗаказ"(IN p_kod_pokupatelya integer, IN p_kod_adresa integer, IN p_kod_sposoba_polucheniya integer, IN p_kod_sposoba_oplaty integer, IN p_kod_kupona integer, OUT p_new_zakaz_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем покупателя
    IF NOT EXISTS (SELECT 1 FROM "Покупатель" WHERE "Код_покупателя" = p_kod_pokupatelya) THEN
        RAISE EXCEPTION 'Покупатель % не найден', p_kod_pokupatelya;
    END IF;

    -- Проверяем адрес
    IF NOT EXISTS (SELECT 1 FROM "Адрес" WHERE "Код_адреса" = p_kod_adresa AND "Код_покупателя" = p_kod_pokupatelya) THEN
        RAISE EXCEPTION 'Адрес % не принадлежит покупателю %', p_kod_adresa, p_kod_pokupatelya;
    END IF;

    -- Проверяем купон (если передан) – срок действия и минимальную сумму
    IF p_kod_kupona IS NOT NULL THEN
        PERFORM 1 FROM "Купон"
        WHERE "Код_купона" = p_kod_kupona
          AND "Дата_начала" <= CURRENT_DATE
          AND "Дата_окончания" >= CURRENT_DATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Купон % недействителен или истёк', p_kod_kupona;
        END IF;
    END IF;

    -- Создаём заказ с нулевой суммой (триггер пересчитает)
    INSERT INTO "Заказ"
        ("Код_покупателя", "Код_адреса", "Код_способа_получения",
         "Код_способа_оплаты", "Код_купона", "Итоговая_сумма", "Статус")
    VALUES
        (p_kod_pokupatelya, p_kod_adresa, p_kod_sposoba_polucheniya,
         p_kod_sposoba_oplaty, p_kod_kupona, 0, 'Оформлен')
    RETURNING "Код_заказа" INTO p_new_zakaz_id;

    RAISE NOTICE 'Заказ #% создан, ожидает переноса товаров из корзины.', p_new_zakaz_id;
END;
$$;


--
-- Name: PROCEDURE "sp_ОформитьЗаказ"(IN p_kod_pokupatelya integer, IN p_kod_adresa integer, IN p_kod_sposoba_polucheniya integer, IN p_kod_sposoba_oplaty integer, IN p_kod_kupona integer, OUT p_new_zakaz_id integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON PROCEDURE public."sp_ОформитьЗаказ"(IN p_kod_pokupatelya integer, IN p_kod_adresa integer, IN p_kod_sposoba_polucheniya integer, IN p_kod_sposoba_oplaty integer, IN p_kod_kupona integer, OUT p_new_zakaz_id integer) IS 'Оформляет заказ из корзины покупателя. Переносит товары через курсор, применяет купон, очищает корзину. Таблицы: Заказ, СодержимоеЗаказа, СодержимоеКорзины.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: Адрес; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Адрес" (
    "Код_адреса" integer NOT NULL,
    "Код_покупателя" integer NOT NULL,
    "Населённый_пункт" character varying(150) NOT NULL,
    "Улица" character varying(150) NOT NULL,
    "Дом" character varying(20) NOT NULL,
    "Квартира" character varying(20),
    "Почтовый_индекс" character varying(10) NOT NULL
);


--
-- Name: Заказ; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Заказ" (
    "Код_заказа" integer NOT NULL,
    "Код_покупателя" integer NOT NULL,
    "Код_адреса" integer NOT NULL,
    "Код_способа_получения" integer NOT NULL,
    "Код_способа_оплаты" integer NOT NULL,
    "Код_купона" integer,
    "Дата_оформления" timestamp without time zone DEFAULT now() NOT NULL,
    "Итоговая_сумма" numeric(12,2) NOT NULL,
    "Статус" character varying(50) DEFAULT 'Оформлен'::character varying NOT NULL,
    CONSTRAINT "CHK_Заказ_Статус" CHECK ((("Статус")::text = ANY (ARRAY[('Оформлен'::character varying)::text, ('В сборке'::character varying)::text, ('Передан в доставку'::character varying)::text, ('Доставлен'::character varying)::text, ('Отменён'::character varying)::text]))),
    CONSTRAINT "CHK_Заказ_Сумма" CHECK (("Итоговая_сумма" >= (0)::numeric))
);


--
-- Name: COLUMN "Заказ"."Статус"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Заказ"."Статус" IS 'Умолчание: Оформлен. Допустимые значения: Оформлен, В сборке, Передан в доставку, Доставлен, Отменён.';


--
-- Name: Купон; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Купон" (
    "Код_купона" integer NOT NULL,
    "Промокод" character varying(50) NOT NULL,
    "Тип_скидки" character varying(20) NOT NULL,
    "Размер_скидки" numeric(10,2) NOT NULL,
    "Дата_начала" date NOT NULL,
    "Дата_окончания" date NOT NULL,
    "Минимальная_сумма_заказа" numeric(12,2) DEFAULT 0 NOT NULL,
    CONSTRAINT "CHK_Купон_Даты" CHECK (("Дата_окончания" >= "Дата_начала")),
    CONSTRAINT "CHK_Купон_МинСумма" CHECK (("Минимальная_сумма_заказа" >= (0)::numeric)),
    CONSTRAINT "CHK_Купон_Размер" CHECK (("Размер_скидки" > (0)::numeric)),
    CONSTRAINT "CHK_Купон_Тип" CHECK ((("Тип_скидки")::text = ANY (ARRAY[('процентная'::character varying)::text, ('фиксированная'::character varying)::text])))
);


--
-- Name: COLUMN "Купон"."Минимальная_сумма_заказа"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Купон"."Минимальная_сумма_заказа" IS 'Умолчание: 0. При 0 купон применяется к любому заказу без ограничений.';


--
-- Name: Покупатель; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Покупатель" (
    "Код_покупателя" integer NOT NULL,
    "Имя" character varying(150) NOT NULL,
    "Email" public.email_type NOT NULL,
    "Телефон" character varying(20),
    "Дата_регистрации" date DEFAULT CURRENT_DATE NOT NULL
);


--
-- Name: COLUMN "Покупатель"."Дата_регистрации"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Покупатель"."Дата_регистрации" IS 'Умолчание: CURRENT_DATE. Дата первой регистрации покупателя в системе.';


--
-- Name: СодержимоеЗаказа; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."СодержимоеЗаказа" (
    "Код_заказа" integer NOT NULL,
    "Код_товара" integer NOT NULL,
    "Количество" integer DEFAULT 1 NOT NULL,
    "Цена_на_момент_покупки" numeric(12,2) NOT NULL,
    CONSTRAINT "CHK_СодЗак_Количество" CHECK (("Количество" > 0)),
    CONSTRAINT "CHK_СодЗак_Цена" CHECK (("Цена_на_момент_покупки" >= (0)::numeric))
);


--
-- Name: COLUMN "СодержимоеЗаказа"."Количество"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."СодержимоеЗаказа"."Количество" IS 'Умолчание: 1. Количество единиц товара в составе заказа.';


--
-- Name: СпособОплаты; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."СпособОплаты" (
    "Код_способа_оплаты" integer NOT NULL,
    "Название" character varying(100) NOT NULL,
    "Описание" text
);


--
-- Name: СпособПолучения; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."СпособПолучения" (
    "Код_способа_получения" integer NOT NULL,
    "Название" character varying(100) NOT NULL,
    "Описание" text
);


--
-- Name: Товар; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Товар" (
    "Код_товара" integer NOT NULL,
    "Код_бренда" integer,
    "Код_размера" integer,
    "Артикул" character varying(50) NOT NULL,
    "Наименование" character varying(200) NOT NULL,
    "Описание" text,
    "Цена" numeric(12,2) NOT NULL,
    CONSTRAINT "CHK_Товар_Цена" CHECK (("Цена" >= (0)::numeric))
);


--
-- Name: v_ЗаказыПолные; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public."v_ЗаказыПолные" AS
 SELECT z."Код_заказа",
    z."Код_покупателя",
    p."Имя" AS "Имя_покупателя",
    p."Email" AS "Email_покупателя",
    p."Телефон" AS "Телефон_покупателя",
    z."Код_адреса",
    concat(a."Населённый_пункт", ', ', a."Улица", ' ', a."Дом",
        CASE
            WHEN (a."Квартира" IS NOT NULL) THEN (', кв. '::text || (a."Квартира")::text)
            ELSE ''::text
        END, ', ', a."Почтовый_индекс") AS "Адрес_полный",
    sp."Название" AS "Способ_получения",
    so."Название" AS "Способ_оплаты",
    k."Промокод",
    k."Тип_скидки" AS "Тип_купона",
    k."Размер_скидки" AS "Размер_купона",
    z."Дата_оформления",
    z."Итоговая_сумма",
    z."Статус",
    ( SELECT count(*) AS count
           FROM public."СодержимоеЗаказа" sz
          WHERE (sz."Код_заказа" = z."Код_заказа")) AS "Количество_позиций",
    ( SELECT string_agg((((t."Наименование")::text || ' ×'::text) || sz."Количество"), '; '::text ORDER BY t."Наименование") AS string_agg
           FROM (public."СодержимоеЗаказа" sz
             JOIN public."Товар" t ON ((t."Код_товара" = sz."Код_товара")))
          WHERE (sz."Код_заказа" = z."Код_заказа")) AS "Состав_заказа"
   FROM (((((public."Заказ" z
     JOIN public."Покупатель" p ON ((p."Код_покупателя" = z."Код_покупателя")))
     JOIN public."Адрес" a ON ((a."Код_адреса" = z."Код_адреса")))
     JOIN public."СпособПолучения" sp ON ((sp."Код_способа_получения" = z."Код_способа_получения")))
     JOIN public."СпособОплаты" so ON ((so."Код_способа_оплаты" = z."Код_способа_оплаты")))
     LEFT JOIN public."Купон" k ON ((k."Код_купона" = z."Код_купона")));


--
-- Name: VIEW "v_ЗаказыПолные"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public."v_ЗаказыПолные" IS 'Полная информация по каждому заказу: покупатель, адрес, способы доставки и оплаты, применённый купон, состав заказа.';


--
-- Name: Бренд; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Бренд" (
    "Код_бренда" integer NOT NULL,
    "Название" character varying(100) NOT NULL,
    "Страна_происхождения" character varying(100),
    "Описание" text
);


--
-- Name: Категория; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Категория" (
    "Код_категории" integer NOT NULL,
    "Название" character varying(100) NOT NULL,
    "Описание" text
);


--
-- Name: Отзыв; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Отзыв" (
    "Код_отзыва" integer NOT NULL,
    "Код_покупателя" integer NOT NULL,
    "Код_товара" integer NOT NULL,
    "Текст" text,
    "Оценка" smallint NOT NULL,
    "Дата" timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT "CHK_Отзыв_Оценка" CHECK ((("Оценка" >= 1) AND ("Оценка" <= 5)))
);


--
-- Name: Размер; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Размер" (
    "Код_размера" integer NOT NULL,
    "Значение" character varying(10) NOT NULL,
    "Тип_размерной_сетки" character varying(50) NOT NULL
);


--
-- Name: Скидка; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Скидка" (
    "Код_скидки" integer NOT NULL,
    "Название" character varying(150) NOT NULL,
    "Тип" character varying(20) NOT NULL,
    "Размер" numeric(10,2) NOT NULL,
    "Дата_начала" date NOT NULL,
    "Дата_окончания" date NOT NULL,
    CONSTRAINT "CHK_Скидка_Даты" CHECK (("Дата_окончания" >= "Дата_начала")),
    CONSTRAINT "CHK_Скидка_Размер" CHECK (("Размер" > (0)::numeric)),
    CONSTRAINT "CHK_Скидка_Тип" CHECK ((("Тип")::text = ANY (ARRAY[('процентная'::character varying)::text, ('фиксированная'::character varying)::text])))
);


--
-- Name: СкидкаТовара; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."СкидкаТовара" (
    "Код_товара" integer NOT NULL,
    "Код_скидки" integer NOT NULL
);


--
-- Name: ТоварКатегория; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ТоварКатегория" (
    "Код_товара" integer NOT NULL,
    "Код_категории" integer NOT NULL
);


--
-- Name: v_Каталог; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public."v_Каталог" AS
 SELECT t."Код_товара",
    t."Артикул",
    t."Наименование",
    t."Описание",
    t."Цена",
    b."Название" AS "Бренд",
    t."Код_бренда",
    r."Значение" AS "Размер",
    r."Тип_размерной_сетки",
    t."Код_размера",
    ( SELECT string_agg((k."Название")::text, ', '::text ORDER BY (k."Название")::text) AS string_agg
           FROM (public."ТоварКатегория" tk
             JOIN public."Категория" k ON ((k."Код_категории" = tk."Код_категории")))
          WHERE (tk."Код_товара" = t."Код_товара")) AS "Категории",
    round(avg(o."Оценка") OVER (PARTITION BY t."Код_товара"), 1) AS "Средняя_оценка",
    count(o."Код_отзыва") OVER (PARTITION BY t."Код_товара") AS "Количество_отзывов",
    ( SELECT s."Тип"
           FROM (public."СкидкаТовара" st
             JOIN public."Скидка" s ON ((s."Код_скидки" = st."Код_скидки")))
          WHERE ((st."Код_товара" = t."Код_товара") AND (s."Дата_начала" <= CURRENT_DATE) AND (s."Дата_окончания" >= CURRENT_DATE))
          ORDER BY s."Размер" DESC
         LIMIT 1) AS "Тип_скидки",
    ( SELECT s."Размер"
           FROM (public."СкидкаТовара" st
             JOIN public."Скидка" s ON ((s."Код_скидки" = st."Код_скидки")))
          WHERE ((st."Код_товара" = t."Код_товара") AND (s."Дата_начала" <= CURRENT_DATE) AND (s."Дата_окончания" >= CURRENT_DATE))
          ORDER BY s."Размер" DESC
         LIMIT 1) AS "Размер_скидки",
        CASE
            WHEN ((( SELECT s."Тип"
               FROM (public."СкидкаТовара" st
                 JOIN public."Скидка" s ON ((s."Код_скидки" = st."Код_скидки")))
              WHERE ((st."Код_товара" = t."Код_товара") AND (s."Дата_начала" <= CURRENT_DATE) AND (s."Дата_окончания" >= CURRENT_DATE))
              ORDER BY s."Размер" DESC
             LIMIT 1))::text = 'процентная'::text) THEN round((t."Цена" * ((1)::numeric - ( SELECT (s."Размер" / (100)::numeric)
               FROM (public."СкидкаТовара" st
                 JOIN public."Скидка" s ON ((s."Код_скидки" = st."Код_скидки")))
              WHERE ((st."Код_товара" = t."Код_товара") AND (s."Дата_начала" <= CURRENT_DATE) AND (s."Дата_окончания" >= CURRENT_DATE))
              ORDER BY s."Размер" DESC
             LIMIT 1))), 2)
            WHEN ((( SELECT s."Тип"
               FROM (public."СкидкаТовара" st
                 JOIN public."Скидка" s ON ((s."Код_скидки" = st."Код_скидки")))
              WHERE ((st."Код_товара" = t."Код_товара") AND (s."Дата_начала" <= CURRENT_DATE) AND (s."Дата_окончания" >= CURRENT_DATE))
              ORDER BY s."Размер" DESC
             LIMIT 1))::text = 'фиксированная'::text) THEN GREATEST((t."Цена" - ( SELECT s."Размер"
               FROM (public."СкидкаТовара" st
                 JOIN public."Скидка" s ON ((s."Код_скидки" = st."Код_скидки")))
              WHERE ((st."Код_товара" = t."Код_товара") AND (s."Дата_начала" <= CURRENT_DATE) AND (s."Дата_окончания" >= CURRENT_DATE))
              ORDER BY s."Размер" DESC
             LIMIT 1)), (0)::numeric)
            ELSE t."Цена"
        END AS "Цена_со_скидкой"
   FROM (((public."Товар" t
     LEFT JOIN public."Бренд" b ON ((b."Код_бренда" = t."Код_бренда")))
     LEFT JOIN public."Размер" r ON ((r."Код_размера" = t."Код_размера")))
     LEFT JOIN public."Отзыв" o ON ((o."Код_товара" = t."Код_товара")));


--
-- Name: VIEW "v_Каталог"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public."v_Каталог" IS 'Витрина каталога: товары с брендом, размером, средней оценкой, категориями и активными скидками на текущую дату.';


--
-- Name: v_РейтингТоваров; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public."v_РейтингТоваров" AS
 SELECT t."Код_товара",
    t."Наименование",
    t."Артикул",
    t."Цена" AS "Цена_базовая",
    b."Название" AS "Бренд",
    count(o."Код_отзыва") AS "Количество_отзывов",
    round(avg(o."Оценка"), 2) AS "Средняя_оценка",
    min(o."Оценка") AS "Мин_оценка",
    max(o."Оценка") AS "Макс_оценка",
    count(o."Оценка") FILTER (WHERE (o."Оценка" = 5)) AS "Оценок_5",
    count(o."Оценка") FILTER (WHERE (o."Оценка" = 4)) AS "Оценок_4",
    count(o."Оценка") FILTER (WHERE (o."Оценка" = 3)) AS "Оценок_3",
    count(o."Оценка") FILTER (WHERE (o."Оценка" <= 2)) AS "Оценок_1_2",
    COALESCE(sum(sz."Количество"), (0)::bigint) AS "Продано_штук",
    COALESCE(sum(((sz."Количество")::numeric * sz."Цена_на_момент_покупки")), (0)::numeric) AS "Выручка_всего",
    ( SELECT count(*) AS count
           FROM (public."СкидкаТовара" st
             JOIN public."Скидка" s ON ((s."Код_скидки" = st."Код_скидки")))
          WHERE ((st."Код_товара" = t."Код_товара") AND (s."Дата_начала" <= CURRENT_DATE) AND (s."Дата_окончания" >= CURRENT_DATE))) AS "Активных_скидок"
   FROM (((public."Товар" t
     LEFT JOIN public."Бренд" b ON ((b."Код_бренда" = t."Код_бренда")))
     LEFT JOIN public."Отзыв" o ON ((o."Код_товара" = t."Код_товара")))
     LEFT JOIN public."СодержимоеЗаказа" sz ON ((sz."Код_товара" = t."Код_товара")))
  GROUP BY t."Код_товара", t."Наименование", t."Артикул", t."Цена", b."Название";


--
-- Name: VIEW "v_РейтингТоваров"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public."v_РейтингТоваров" IS 'Агрегированная статистика по товарам: средняя оценка, количество отзывов с распределением, объём продаж и выручка.';


--
-- Name: Адрес_Код_адреса_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Адрес_Код_адреса_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Адрес_Код_адреса_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Адрес_Код_адреса_seq" OWNED BY public."Адрес"."Код_адреса";


--
-- Name: Бренд_Код_бренда_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Бренд_Код_бренда_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Бренд_Код_бренда_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Бренд_Код_бренда_seq" OWNED BY public."Бренд"."Код_бренда";


--
-- Name: Заказ_Код_заказа_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Заказ_Код_заказа_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Заказ_Код_заказа_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Заказ_Код_заказа_seq" OWNED BY public."Заказ"."Код_заказа";


--
-- Name: Категория_Код_категории_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Категория_Код_категории_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Категория_Код_категории_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Категория_Код_категории_seq" OWNED BY public."Категория"."Код_категории";


--
-- Name: Корзина; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Корзина" (
    "Код_покупателя" integer NOT NULL,
    "Дата_обновления" timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: Купон_Код_купона_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Купон_Код_купона_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Купон_Код_купона_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Купон_Код_купона_seq" OWNED BY public."Купон"."Код_купона";


--
-- Name: ЛогСтатусовЗаказа; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ЛогСтатусовЗаказа" (
    "Код_записи" integer NOT NULL,
    "Код_заказа" integer NOT NULL,
    "Статус_старый" character varying(50),
    "Статус_новый" character varying(50) NOT NULL,
    "Дата_изменения" timestamp without time zone DEFAULT now() NOT NULL,
    "Комментарий" text
);


--
-- Name: TABLE "ЛогСтатусовЗаказа"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."ЛогСтатусовЗаказа" IS 'Журнал всех изменений статуса заказов. Заполняется автоматически триггером trg_ЛогСтатусов.';


--
-- Name: ЛогСтатусовЗаказа_Код_записи_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."ЛогСтатусовЗаказа_Код_записи_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ЛогСтатусовЗаказа_Код_записи_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."ЛогСтатусовЗаказа_Код_записи_seq" OWNED BY public."ЛогСтатусовЗаказа"."Код_записи";


--
-- Name: Отзыв_Код_отзыва_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Отзыв_Код_отзыва_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Отзыв_Код_отзыва_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Отзыв_Код_отзыва_seq" OWNED BY public."Отзыв"."Код_отзыва";


--
-- Name: ОтслеживаниеТоваров; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ОтслеживаниеТоваров" (
    "Код_покупателя" integer NOT NULL,
    "Код_товара" integer NOT NULL,
    "Дата_добавления" timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: Покупатель_Код_покупателя_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Покупатель_Код_покупателя_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Покупатель_Код_покупателя_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Покупатель_Код_покупателя_seq" OWNED BY public."Покупатель"."Код_покупателя";


--
-- Name: Размер_Код_размера_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Размер_Код_размера_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Размер_Код_размера_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Размер_Код_размера_seq" OWNED BY public."Размер"."Код_размера";


--
-- Name: Скидка_Код_скидки_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Скидка_Код_скидки_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Скидка_Код_скидки_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Скидка_Код_скидки_seq" OWNED BY public."Скидка"."Код_скидки";


--
-- Name: СкидкаЗаказа; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."СкидкаЗаказа" (
    "Код_заказа" integer NOT NULL,
    "Код_скидки" integer NOT NULL
);


--
-- Name: СодержимоеКорзины; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."СодержимоеКорзины" (
    "Код_покупателя" integer NOT NULL,
    "Код_товара" integer NOT NULL,
    "Количество" integer DEFAULT 1 NOT NULL,
    CONSTRAINT "CHK_СодКорз_Количество" CHECK (("Количество" > 0))
);


--
-- Name: COLUMN "СодержимоеКорзины"."Количество"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."СодержимоеКорзины"."Количество" IS 'Умолчание: 1. Количество единиц товара в корзине покупателя.';


--
-- Name: СпособОплаты_Код_способа_оплаты_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."СпособОплаты_Код_способа_оплаты_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: СпособОплаты_Код_способа_оплаты_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."СпособОплаты_Код_способа_оплаты_seq" OWNED BY public."СпособОплаты"."Код_способа_оплаты";


--
-- Name: СпособПолучени_Код_способа_пол_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."СпособПолучени_Код_способа_пол_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: СпособПолучени_Код_способа_пол_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."СпособПолучени_Код_способа_пол_seq" OWNED BY public."СпособПолучения"."Код_способа_получения";


--
-- Name: Товар_Код_товара_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Товар_Код_товара_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Товар_Код_товара_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Товар_Код_товара_seq" OWNED BY public."Товар"."Код_товара";


--
-- Name: Адрес Код_адреса; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Адрес" ALTER COLUMN "Код_адреса" SET DEFAULT nextval('public."Адрес_Код_адреса_seq"'::regclass);


--
-- Name: Бренд Код_бренда; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Бренд" ALTER COLUMN "Код_бренда" SET DEFAULT nextval('public."Бренд_Код_бренда_seq"'::regclass);


--
-- Name: Заказ Код_заказа; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Заказ" ALTER COLUMN "Код_заказа" SET DEFAULT nextval('public."Заказ_Код_заказа_seq"'::regclass);


--
-- Name: Категория Код_категории; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Категория" ALTER COLUMN "Код_категории" SET DEFAULT nextval('public."Категория_Код_категории_seq"'::regclass);


--
-- Name: Купон Код_купона; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Купон" ALTER COLUMN "Код_купона" SET DEFAULT nextval('public."Купон_Код_купона_seq"'::regclass);


--
-- Name: ЛогСтатусовЗаказа Код_записи; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ЛогСтатусовЗаказа" ALTER COLUMN "Код_записи" SET DEFAULT nextval('public."ЛогСтатусовЗаказа_Код_записи_seq"'::regclass);


--
-- Name: Отзыв Код_отзыва; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Отзыв" ALTER COLUMN "Код_отзыва" SET DEFAULT nextval('public."Отзыв_Код_отзыва_seq"'::regclass);


--
-- Name: Покупатель Код_покупателя; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Покупатель" ALTER COLUMN "Код_покупателя" SET DEFAULT nextval('public."Покупатель_Код_покупателя_seq"'::regclass);


--
-- Name: Размер Код_размера; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Размер" ALTER COLUMN "Код_размера" SET DEFAULT nextval('public."Размер_Код_размера_seq"'::regclass);


--
-- Name: Скидка Код_скидки; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Скидка" ALTER COLUMN "Код_скидки" SET DEFAULT nextval('public."Скидка_Код_скидки_seq"'::regclass);


--
-- Name: СпособОплаты Код_способа_оплаты; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СпособОплаты" ALTER COLUMN "Код_способа_оплаты" SET DEFAULT nextval('public."СпособОплаты_Код_способа_оплаты_seq"'::regclass);


--
-- Name: СпособПолучения Код_способа_получения; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СпособПолучения" ALTER COLUMN "Код_способа_получения" SET DEFAULT nextval('public."СпособПолучени_Код_способа_пол_seq"'::regclass);


--
-- Name: Товар Код_товара; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Товар" ALTER COLUMN "Код_товара" SET DEFAULT nextval('public."Товар_Код_товара_seq"'::regclass);


--
-- Name: ОтслеживаниеТоваров PK_ОтслеживаниеТоваров; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ОтслеживаниеТоваров"
    ADD CONSTRAINT "PK_ОтслеживаниеТоваров" PRIMARY KEY ("Код_покупателя", "Код_товара");


--
-- Name: СкидкаЗаказа PK_СкидкаЗаказа; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СкидкаЗаказа"
    ADD CONSTRAINT "PK_СкидкаЗаказа" PRIMARY KEY ("Код_заказа", "Код_скидки");


--
-- Name: СкидкаТовара PK_СкидкаТовара; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СкидкаТовара"
    ADD CONSTRAINT "PK_СкидкаТовара" PRIMARY KEY ("Код_товара", "Код_скидки");


--
-- Name: СодержимоеЗаказа PK_СодержимоеЗаказа; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СодержимоеЗаказа"
    ADD CONSTRAINT "PK_СодержимоеЗаказа" PRIMARY KEY ("Код_заказа", "Код_товара");


--
-- Name: СодержимоеКорзины PK_СодержимоеКорзины; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СодержимоеКорзины"
    ADD CONSTRAINT "PK_СодержимоеКорзины" PRIMARY KEY ("Код_покупателя", "Код_товара");


--
-- Name: ТоварКатегория PK_ТоварКатегория; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ТоварКатегория"
    ADD CONSTRAINT "PK_ТоварКатегория" PRIMARY KEY ("Код_товара", "Код_категории");


--
-- Name: Купон UQ_Купон_Промокод; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Купон"
    ADD CONSTRAINT "UQ_Купон_Промокод" UNIQUE ("Промокод");


--
-- Name: Покупатель UQ_Покупатель_Email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Покупатель"
    ADD CONSTRAINT "UQ_Покупатель_Email" UNIQUE ("Email");


--
-- Name: Размер UQ_Размер_Значение_Тип; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Размер"
    ADD CONSTRAINT "UQ_Размер_Значение_Тип" UNIQUE ("Значение", "Тип_размерной_сетки");


--
-- Name: Товар UQ_Товар_Артикул; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Товар"
    ADD CONSTRAINT "UQ_Товар_Артикул" UNIQUE ("Артикул");


--
-- Name: Адрес Адрес_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Адрес"
    ADD CONSTRAINT "Адрес_pkey" PRIMARY KEY ("Код_адреса");


--
-- Name: Бренд Бренд_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Бренд"
    ADD CONSTRAINT "Бренд_pkey" PRIMARY KEY ("Код_бренда");


--
-- Name: Заказ Заказ_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Заказ"
    ADD CONSTRAINT "Заказ_pkey" PRIMARY KEY ("Код_заказа");


--
-- Name: Категория Категория_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Категория"
    ADD CONSTRAINT "Категория_pkey" PRIMARY KEY ("Код_категории");


--
-- Name: Корзина Корзина_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Корзина"
    ADD CONSTRAINT "Корзина_pkey" PRIMARY KEY ("Код_покупателя");


--
-- Name: Купон Купон_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Купон"
    ADD CONSTRAINT "Купон_pkey" PRIMARY KEY ("Код_купона");


--
-- Name: ЛогСтатусовЗаказа ЛогСтатусовЗаказа_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ЛогСтатусовЗаказа"
    ADD CONSTRAINT "ЛогСтатусовЗаказа_pkey" PRIMARY KEY ("Код_записи");


--
-- Name: Отзыв Отзыв_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Отзыв"
    ADD CONSTRAINT "Отзыв_pkey" PRIMARY KEY ("Код_отзыва");


--
-- Name: Покупатель Покупатель_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Покупатель"
    ADD CONSTRAINT "Покупатель_pkey" PRIMARY KEY ("Код_покупателя");


--
-- Name: Размер Размер_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Размер"
    ADD CONSTRAINT "Размер_pkey" PRIMARY KEY ("Код_размера");


--
-- Name: Скидка Скидка_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Скидка"
    ADD CONSTRAINT "Скидка_pkey" PRIMARY KEY ("Код_скидки");


--
-- Name: СпособОплаты СпособОплаты_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СпособОплаты"
    ADD CONSTRAINT "СпособОплаты_pkey" PRIMARY KEY ("Код_способа_оплаты");


--
-- Name: СпособПолучения СпособПолучения_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СпособПолучения"
    ADD CONSTRAINT "СпособПолучения_pkey" PRIMARY KEY ("Код_способа_получения");


--
-- Name: Товар Товар_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Товар"
    ADD CONSTRAINT "Товар_pkey" PRIMARY KEY ("Код_товара");


--
-- Name: v_ЗаказыПолные rule_ЗапретВставкиВЗаказы; Type: RULE; Schema: public; Owner: -
--

CREATE RULE "rule_ЗапретВставкиВЗаказы" AS
    ON INSERT TO public."v_ЗаказыПолные" DO INSTEAD NOTHING;


--
-- Name: RULE "rule_ЗапретВставкиВЗаказы" ON "v_ЗаказыПолные"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON RULE "rule_ЗапретВставкиВЗаказы" ON public."v_ЗаказыПолные" IS 'Правило 3: Блокирует прямую вставку в представление заказов. Создание заказов — только через процедуру sp_ОформитьЗаказ.';


--
-- Name: v_Каталог rule_ЗапретУдаленияИзКаталога; Type: RULE; Schema: public; Owner: -
--

CREATE RULE "rule_ЗапретУдаленияИзКаталога" AS
    ON DELETE TO public."v_Каталог" DO INSTEAD NOTHING;


--
-- Name: RULE "rule_ЗапретУдаленияИзКаталога" ON "v_Каталог"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON RULE "rule_ЗапретУдаленияИзКаталога" ON public."v_Каталог" IS 'Правило 1: Блокирует прямое удаление товаров через представление. Удаление выполняется только через процедуру sp_УдалитьТовар.';


--
-- Name: v_Каталог rule_ОбновлениеЦеныЧерезКаталог; Type: RULE; Schema: public; Owner: -
--

CREATE RULE "rule_ОбновлениеЦеныЧерезКаталог" AS
    ON UPDATE TO public."v_Каталог"
   WHERE (old."Цена" IS DISTINCT FROM new."Цена") DO  UPDATE public."Товар" SET "Цена" = new."Цена"
  WHERE ("Товар"."Код_товара" = old."Код_товара");


--
-- Name: RULE "rule_ОбновлениеЦеныЧерезКаталог" ON "v_Каталог"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON RULE "rule_ОбновлениеЦеныЧерезКаталог" ON public."v_Каталог" IS 'Правило 2: При изменении цены через представление v_Каталог автоматически обновляет цену в базовой таблице Товар.';


--
-- Name: Покупатель trg_АвтоКорзина; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_АвтоКорзина" AFTER INSERT ON public."Покупатель" FOR EACH ROW EXECUTE FUNCTION public."fn_АвтоКорзина"();


--
-- Name: TRIGGER "trg_АвтоКорзина" ON "Покупатель"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER "trg_АвтоКорзина" ON public."Покупатель" IS 'Триггер 1: Автоматически создаёт пустую корзину при каждой регистрации нового покупателя.';


--
-- Name: Заказ trg_ЛогСтатусов; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_ЛогСтатусов" AFTER UPDATE OF "Статус" ON public."Заказ" FOR EACH ROW EXECUTE FUNCTION public."fn_ЛогСтатусов"();


--
-- Name: TRIGGER "trg_ЛогСтатусов" ON "Заказ"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER "trg_ЛогСтатусов" ON public."Заказ" IS 'Триггер 3 (с курсором): При изменении статуса заказа проверяет историю через курсор и записывает событие в ЛогСтатусовЗаказа.';


--
-- Name: Заказ trg_ПереносКорзиныВЗаказ; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_ПереносКорзиныВЗаказ" AFTER INSERT ON public."Заказ" FOR EACH ROW EXECUTE FUNCTION public."fn_ПереносКорзиныВЗаказ"();


--
-- Name: TRIGGER "trg_ПереносКорзиныВЗаказ" ON "Заказ"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER "trg_ПереносКорзиныВЗаказ" ON public."Заказ" IS 'Триггер 4 (с курсором): При вставке заказа переносит товары из корзины покупателя в состав заказа через курсор. Основной сценарий: корзина → заказ.';


--
-- Name: СодержимоеЗаказа trg_ПересчётИтогаЗаказа; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_ПересчётИтогаЗаказа" AFTER INSERT OR UPDATE ON public."СодержимоеЗаказа" FOR EACH ROW EXECUTE FUNCTION public."fn_ПересчётИтогаЗаказа"();


--
-- Name: TRIGGER "trg_ПересчётИтогаЗаказа" ON "СодержимоеЗаказа"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER "trg_ПересчётИтогаЗаказа" ON public."СодержимоеЗаказа" IS 'Триггер 5 (с вложенным курсором): При добавлении или изменении позиции заказа пересчитывает итоговую сумму. Внешний курсор — заказы, внутренний — позиции каждого заказа.';


--
-- Name: Адрес FK_Адрес_Покупатель; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Адрес"
    ADD CONSTRAINT "FK_Адрес_Покупатель" FOREIGN KEY ("Код_покупателя") REFERENCES public."Покупатель"("Код_покупателя") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Заказ FK_Заказ_Адрес; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Заказ"
    ADD CONSTRAINT "FK_Заказ_Адрес" FOREIGN KEY ("Код_адреса") REFERENCES public."Адрес"("Код_адреса") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Заказ FK_Заказ_Купон; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Заказ"
    ADD CONSTRAINT "FK_Заказ_Купон" FOREIGN KEY ("Код_купона") REFERENCES public."Купон"("Код_купона") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Заказ FK_Заказ_Покупатель; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Заказ"
    ADD CONSTRAINT "FK_Заказ_Покупатель" FOREIGN KEY ("Код_покупателя") REFERENCES public."Покупатель"("Код_покупателя") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Заказ FK_Заказ_СпособОплаты; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Заказ"
    ADD CONSTRAINT "FK_Заказ_СпособОплаты" FOREIGN KEY ("Код_способа_оплаты") REFERENCES public."СпособОплаты"("Код_способа_оплаты") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Заказ FK_Заказ_СпособПолучения; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Заказ"
    ADD CONSTRAINT "FK_Заказ_СпособПолучения" FOREIGN KEY ("Код_способа_получения") REFERENCES public."СпособПолучения"("Код_способа_получения") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Корзина FK_Корзина_Покупатель; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Корзина"
    ADD CONSTRAINT "FK_Корзина_Покупатель" FOREIGN KEY ("Код_покупателя") REFERENCES public."Покупатель"("Код_покупателя") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ЛогСтатусовЗаказа FK_Лог_Заказ; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ЛогСтатусовЗаказа"
    ADD CONSTRAINT "FK_Лог_Заказ" FOREIGN KEY ("Код_заказа") REFERENCES public."Заказ"("Код_заказа") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Отзыв FK_Отзыв_Покупатель; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Отзыв"
    ADD CONSTRAINT "FK_Отзыв_Покупатель" FOREIGN KEY ("Код_покупателя") REFERENCES public."Покупатель"("Код_покупателя") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Отзыв FK_Отзыв_Товар; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Отзыв"
    ADD CONSTRAINT "FK_Отзыв_Товар" FOREIGN KEY ("Код_товара") REFERENCES public."Товар"("Код_товара") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ОтслеживаниеТоваров FK_ОтслТов_Покупатель; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ОтслеживаниеТоваров"
    ADD CONSTRAINT "FK_ОтслТов_Покупатель" FOREIGN KEY ("Код_покупателя") REFERENCES public."Покупатель"("Код_покупателя") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ОтслеживаниеТоваров FK_ОтслТов_Товар; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ОтслеживаниеТоваров"
    ADD CONSTRAINT "FK_ОтслТов_Товар" FOREIGN KEY ("Код_товара") REFERENCES public."Товар"("Код_товара") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: СкидкаЗаказа FK_СкидЗак_Заказ; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СкидкаЗаказа"
    ADD CONSTRAINT "FK_СкидЗак_Заказ" FOREIGN KEY ("Код_заказа") REFERENCES public."Заказ"("Код_заказа") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: СкидкаЗаказа FK_СкидЗак_Скидка; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СкидкаЗаказа"
    ADD CONSTRAINT "FK_СкидЗак_Скидка" FOREIGN KEY ("Код_скидки") REFERENCES public."Скидка"("Код_скидки") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: СкидкаТовара FK_СкидТов_Скидка; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СкидкаТовара"
    ADD CONSTRAINT "FK_СкидТов_Скидка" FOREIGN KEY ("Код_скидки") REFERENCES public."Скидка"("Код_скидки") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: СкидкаТовара FK_СкидТов_Товар; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СкидкаТовара"
    ADD CONSTRAINT "FK_СкидТов_Товар" FOREIGN KEY ("Код_товара") REFERENCES public."Товар"("Код_товара") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: СодержимоеЗаказа FK_СодЗак_Заказ; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СодержимоеЗаказа"
    ADD CONSTRAINT "FK_СодЗак_Заказ" FOREIGN KEY ("Код_заказа") REFERENCES public."Заказ"("Код_заказа") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: СодержимоеЗаказа FK_СодЗак_Товар; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СодержимоеЗаказа"
    ADD CONSTRAINT "FK_СодЗак_Товар" FOREIGN KEY ("Код_товара") REFERENCES public."Товар"("Код_товара") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: СодержимоеКорзины FK_СодКорз_Корзина; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СодержимоеКорзины"
    ADD CONSTRAINT "FK_СодКорз_Корзина" FOREIGN KEY ("Код_покупателя") REFERENCES public."Корзина"("Код_покупателя") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: СодержимоеКорзины FK_СодКорз_Товар; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."СодержимоеКорзины"
    ADD CONSTRAINT "FK_СодКорз_Товар" FOREIGN KEY ("Код_товара") REFERENCES public."Товар"("Код_товара") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ТоварКатегория FK_ТовКат_Категория; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ТоварКатегория"
    ADD CONSTRAINT "FK_ТовКат_Категория" FOREIGN KEY ("Код_категории") REFERENCES public."Категория"("Код_категории") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ТоварКатегория FK_ТовКат_Товар; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ТоварКатегория"
    ADD CONSTRAINT "FK_ТовКат_Товар" FOREIGN KEY ("Код_товара") REFERENCES public."Товар"("Код_товара") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Товар FK_Товар_Бренд; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Товар"
    ADD CONSTRAINT "FK_Товар_Бренд" FOREIGN KEY ("Код_бренда") REFERENCES public."Бренд"("Код_бренда") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Товар FK_Товар_Размер; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Товар"
    ADD CONSTRAINT "FK_Товар_Размер" FOREIGN KEY ("Код_размера") REFERENCES public."Размер"("Код_размера") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--



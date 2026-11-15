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
-- Data for Name: Покупатель; Type: TABLE DATA; Schema: public; Owner: -
--

SET SESSION AUTHORIZATION DEFAULT;

ALTER TABLE public."Покупатель" DISABLE TRIGGER ALL;

COPY public."Покупатель" ("Код_покупателя", "Имя", "Email", "Телефон", "Дата_регистрации") FROM stdin;
2	Дмитрий Козлов	buyer2@example.com	+7 (900) 000-00-02	2024-05-22
3	Екатерина Новикова	buyer3@example.com	+7 (900) 000-00-03	2024-07-10
4	Иван Петров	buyer4@example.com	+7 (900) 000-00-04	2024-08-03
5	Мария Соколова	buyer5@example.com	+7 (900) 000-00-05	2024-09-18
6	Алексей Морозов	buyer6@example.com	+7 (900) 000-00-06	2024-10-05
7	Ольга Волкова	buyer7@example.com	+7 (900) 000-00-07	2024-11-14
8	Сергей Лебедев	buyer8@example.com	+7 (900) 000-00-08	2024-12-01
9	Наталья Кузнецова	buyer9@example.com	+7 (900) 000-00-09	2025-01-20
\.


ALTER TABLE public."Покупатель" ENABLE TRIGGER ALL;

--
-- Data for Name: Адрес; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Адрес" DISABLE TRIGGER ALL;

COPY public."Адрес" ("Код_адреса", "Код_покупателя", "Населённый_пункт", "Улица", "Дом", "Квартира", "Почтовый_индекс") FROM stdin;
3	2	Санкт-Петербург	Невский проспект	100	5	190000
4	3	Москва	Ленинградский пр-т	32	101	125167
5	4	Краснодар	ул. Красная	55	\N	350000
6	5	Екатеринбург	ул. Ленина	24А	67	620000
7	6	Новосибирск	пр. Октября	11	33	630000
8	7	Москва	ул. Профсоюзная	45	12	117997
9	8	Казань	ул. Баумана	18	\N	420111
10	9	Ростов-на-Дону	пр. Ворошиловский	72	89	344000
\.


ALTER TABLE public."Адрес" ENABLE TRIGGER ALL;

--
-- Data for Name: Бренд; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Бренд" DISABLE TRIGGER ALL;

COPY public."Бренд" ("Код_бренда", "Название", "Страна_происхождения", "Описание") FROM stdin;
1	Nike	США	Американский бренд спортивной одежды и обуви
2	Adidas	Германия	Немецкий спортивный бренд с более чем 70-летней историей
3	Zara	Испания	Испанский бренд fast-fashion одежды
4	H&M	Швеция	Шведский бренд доступной повседневной одежды
5	Levis	США	Американский производитель джинсовой одежды с 1853 года
6	Uniqlo	Япония	Японский бренд базовой одежды высокого качества
7	Pull&Bear	Испания	Молодёжный испанский бренд повседневной одежды
8	Befree	Россия	Российский бренд актуальной молодёжной одежды
\.


ALTER TABLE public."Бренд" ENABLE TRIGGER ALL;

--
-- Data for Name: Купон; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Купон" DISABLE TRIGGER ALL;

COPY public."Купон" ("Код_купона", "Промокод", "Тип_скидки", "Размер_скидки", "Дата_начала", "Дата_окончания", "Минимальная_сумма_заказа") FROM stdin;
1	FAMILIA10	процентная	10.00	2025-01-01	2026-12-31	0.00
2	SUMMER20	процентная	20.00	2025-06-01	2026-08-31	2000.00
3	WELCOME500	фиксированная	500.00	2025-01-01	2026-12-31	3000.00
4	SPORT15	процентная	15.00	2025-01-01	2026-12-31	1500.00
5	NEW2025	процентная	25.00	2025-01-01	2025-12-31	5000.00
\.


ALTER TABLE public."Купон" ENABLE TRIGGER ALL;

--
-- Data for Name: СпособОплаты; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."СпособОплаты" DISABLE TRIGGER ALL;

COPY public."СпособОплаты" ("Код_способа_оплаты", "Название", "Описание") FROM stdin;
1	Банковская карта	Visa, MasterCard, МИР — онлайн-оплата
2	СБП	Оплата через Систему быстрых платежей
3	Наличными курьеру	Оплата наличными при получении заказа
4	Рассрочка 0%	Рассрочка на 3, 6 или 12 месяцев без переплат
\.


ALTER TABLE public."СпособОплаты" ENABLE TRIGGER ALL;

--
-- Data for Name: СпособПолучения; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."СпособПолучения" DISABLE TRIGGER ALL;

COPY public."СпособПолучения" ("Код_способа_получения", "Название", "Описание") FROM stdin;
1	Курьером	Доставка курьером до двери, 1–3 рабочих дня
2	Самовывоз из магазина	Забрать из ближайшего магазина сети
3	Пункт выдачи заказов	ПВЗ СДЭК, Boxberry, Почта России
4	Почта России	Доставка Почтой России, 5–14 рабочих дней
\.


ALTER TABLE public."СпособПолучения" ENABLE TRIGGER ALL;

--
-- Data for Name: Заказ; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Заказ" DISABLE TRIGGER ALL;

COPY public."Заказ" ("Код_заказа", "Код_покупателя", "Код_адреса", "Код_способа_получения", "Код_способа_оплаты", "Код_купона", "Дата_оформления", "Итоговая_сумма", "Статус") FROM stdin;
3	2	3	1	1	\N	2025-03-18 09:00:00	14480.00	Доставлен
4	3	4	2	2	2	2025-04-22 16:45:00	3192.00	Доставлен
5	4	5	3	3	\N	2025-05-01 11:20:00	6990.00	Доставлен
6	5	6	1	1	1	2025-05-15 13:00:00	1791.00	Оформлен
7	6	7	4	1	\N	2025-05-20 08:30:00	5490.00	В сборке
8	7	8	2	2	\N	2025-05-25 17:00:00	7990.00	Передан в доставку
9	8	9	1	4	3	2025-06-01 12:00:00	4490.00	Оформлен
10	9	10	3	1	\N	2025-06-10 10:00:00	2990.00	В сборке
\.


ALTER TABLE public."Заказ" ENABLE TRIGGER ALL;

--
-- Data for Name: Категория; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Категория" DISABLE TRIGGER ALL;

COPY public."Категория" ("Код_категории", "Название", "Описание") FROM stdin;
1	Платья	Повседневные, вечерние и офисные платья
2	Футболки	Базовые и принтованные футболки и поло
3	Брюки и джинсы	Джинсы, брюки, карго и чиносы
4	Куртки и пальто	Верхняя одежда на любой сезон
5	Спортивная одежда	Одежда для фитнеса, бега и активного отдыха
6	Свитеры и кардиганы	Трикотаж, худи, джемперы
7	Блузки и рубашки	Офисные и повседневные блузки и рубашки
8	Юбки	Мини, миди и макси юбки всех фасонов
9	Пиджаки и жакеты	Деловые и casual пиджаки
10	Нижнее бельё	Бельё и домашняя одежда
\.


ALTER TABLE public."Категория" ENABLE TRIGGER ALL;

--
-- Data for Name: Корзина; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Корзина" DISABLE TRIGGER ALL;

COPY public."Корзина" ("Код_покупателя", "Дата_обновления") FROM stdin;
2	2026-06-23 18:28:55.792458
3	2026-06-23 18:28:55.792458
4	2026-06-23 18:28:55.792458
5	2026-06-23 18:28:55.792458
6	2026-06-23 18:28:55.792458
7	2026-06-23 18:28:55.792458
8	2026-06-23 18:28:55.792458
9	2026-06-23 18:28:55.792458
\.


ALTER TABLE public."Корзина" ENABLE TRIGGER ALL;

--
-- Data for Name: ЛогСтатусовЗаказа; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."ЛогСтатусовЗаказа" DISABLE TRIGGER ALL;

COPY public."ЛогСтатусовЗаказа" ("Код_записи", "Код_заказа", "Статус_старый", "Статус_новый", "Дата_изменения", "Комментарий") FROM stdin;
\.


ALTER TABLE public."ЛогСтатусовЗаказа" ENABLE TRIGGER ALL;

--
-- Data for Name: Размер; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Размер" DISABLE TRIGGER ALL;

COPY public."Размер" ("Код_размера", "Значение", "Тип_размерной_сетки") FROM stdin;
1	XS	буквенная
2	S	буквенная
3	M	буквенная
4	L	буквенная
5	XL	буквенная
6	XXL	буквенная
7	36	числовая RU
8	38	числовая RU
9	40	числовая RU
10	42	числовая RU
11	44	числовая RU
12	46	числовая RU
13	48	числовая RU
14	36	числовая EU
15	38	числовая EU
16	40	числовая EU
17	42	числовая EU
18	44	числовая EU
\.


ALTER TABLE public."Размер" ENABLE TRIGGER ALL;

--
-- Data for Name: Товар; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Товар" DISABLE TRIGGER ALL;

COPY public."Товар" ("Код_товара", "Код_бренда", "Код_размера", "Артикул", "Наименование", "Описание", "Цена") FROM stdin;
1	1	3	NK-TS-001-M	Nike Футболка Dri-FIT базовая	Классическая футболка из технологичной ткани Dri-FIT, отводящей влагу. Идеальна для тренировок и повседневной носки.	2490.00
2	1	4	NK-TS-002-L	Nike Футболка Club Essentials	Мягкая хлопковая футболка с маленьким логотипом. Базовая модель на каждый день.	1990.00
3	1	3	NK-SW-001-M	Nike Худи Tech Fleece	Флисовое худи из инновационного материала Tech Fleece — лёгкое, тёплое, стильное.	7990.00
4	2	2	AD-TS-001-S	Adidas Футболка Essentials	Базовая футболка из чистого хлопка. Лёгкая, дышащая, с логотипом три полосы.	1790.00
5	2	4	AD-TR-001-L	Adidas Брюки Tiro 23	Тренировочные брюки с классическими тремя полосами по бокам. Ткань с технологией AEROREADY.	3990.00
6	2	3	AD-JK-001-M	Adidas Куртка Windbreaker	Лёгкая ветровка из переработанных материалов. Защита от ветра и дождя.	5490.00
7	3	3	ZR-DR-001-M	Zara Платье миди с поясом	Элегантное платье миди из струящейся ткани с завязывающимся поясом. Актуальный силуэт.	4990.00
8	3	2	ZR-BL-001-S	Zara Блузка с объёмными рукавами	Лёгкая блузка из вискозы с объёмными рукавами — романтичный образ для любого случая.	3290.00
9	3	4	ZR-PT-001-L	Zara Прямые брюки высокая посадка	Классические прямые брюки с высокой посадкой. Офисный стиль с модным акцентом.	3990.00
10	4	1	HM-TS-001-XS	H&M Футболка оверсайз базовая	Мягкая хлопковая футболка оверсайз. Идеальный базовый предмет гардероба.	799.00
11	4	3	HM-DR-001-M	H&M Платье с цветочным принтом	Лёгкое летнее платье с цветочным принтом. Длина миди, рукав-рюш.	1999.00
12	4	5	HM-JK-001-XL	H&M Джинсовая куртка	Классическая джинсовая куртка прямого кроя. Вечная классика, которая никогда не выйдет из моды.	2999.00
13	5	9	LV-JN-501-42	Levis Джинсы 501 Original	Легендарные прямые джинсы 501. Оригинальная посадка, пуговицы вместо молнии. Классика с 1873 года.	6990.00
14	5	8	LV-JN-511-40	Levis Джинсы 511 Slim	Зауженные джинсы 511 — облегающий крой без стеснения движений. Современная классика.	5990.00
15	5	10	LV-JK-001-44	Levis Куртка джинсовая Trucker	Знаменитая куртка Trucker с характерными нагрудными карманами. Иконический силуэт Levi's.	8990.00
16	6	3	UQ-TS-001-M	Uniqlo Футболка Supima Cotton	Футболка из высококачественного хлопка Supima — мягче обычного хлопка, устойчива к пиллингу.	1490.00
17	6	4	UQ-SW-001-L	Uniqlo Свитер из хлопка	Лёгкий хлопковый свитер с круглым вырезом. Минимализм и высокое качество Uniqlo.	2990.00
18	7	2	PB-DR-001-S	Pull&Bear Платье с разрезом	Трикотажное платье мини с боковым разрезом. Молодёжный образ для вечернего выхода.	2490.00
19	8	3	BF-SK-001-M	Befree Юбка плиссированная	Плиссированная юбка миди из лёгкой ткани. Играет на ветру, создаёт романтичный образ.	2190.00
20	8	4	BF-CR-001-L	Befree Кардиган оверсайз	Мягкий кардиган оверсайз. Идеален для прохладных вечеров — уютно и стильно.	3490.00
\.


ALTER TABLE public."Товар" ENABLE TRIGGER ALL;

--
-- Data for Name: Отзыв; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Отзыв" DISABLE TRIGGER ALL;

COPY public."Отзыв" ("Код_отзыва", "Код_покупателя", "Код_товара", "Текст", "Оценка", "Дата") FROM stdin;
3	2	13	Легендарные 501-е. Это уже третья пара — лучше джинсов не нашёл. Покупаю только их.	5	2025-04-01 14:00:00
4	2	14	Slim fit идеально по ноге. Качество дениса отличное. Немного тугие в начале, но потом разносятся.	4	2025-04-05 16:00:00
5	3	11	Яркое и лёгкое платье! Идеально для лета. Размер совпал с таблицей. Цена приятная.	5	2025-05-01 10:00:00
6	3	8	Блузка симпатичная, но ткань показалась тонковатой. Зато объёмные рукава смотрятся отлично.	3	2025-05-02 12:00:00
7	4	13	Джинсы Levi's — это классика. Отличная посадка для размера 42. Рекомендую.	5	2025-05-10 15:00:00
8	5	10	Базовая футболка от H&M — лучшая за эту цену. Мягкая, стирается хорошо. Взяла сразу 3 цвета!	5	2025-05-20 09:00:00
9	6	6	Ветровка хорошая, лёгкая. От лёгкого дождя защищает. На спорт самое то.	4	2025-05-25 18:00:00
10	7	3	Tech Fleece — лучшее худи что у меня было. Тонкое но тёплое. Носится уже второй сезон отлично.	5	2025-06-01 11:00:00
11	7	1	Футболка Dri-FIT делает своё дело на тренировках. Пот не чувствуется. Немного большемерит.	4	2025-06-02 14:00:00
12	8	20	Мягкий уютный кардиган. Как будто в облако завернулась. Буду брать ещё в другом цвете.	5	2025-06-05 10:00:00
13	9	17	Свитер Uniqlo — воплощение японского качества. Ничего лишнего. Носить приятно.	5	2025-06-12 16:00:00
\.


ALTER TABLE public."Отзыв" ENABLE TRIGGER ALL;

--
-- Data for Name: ОтслеживаниеТоваров; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."ОтслеживаниеТоваров" DISABLE TRIGGER ALL;

COPY public."ОтслеживаниеТоваров" ("Код_покупателя", "Код_товара", "Дата_добавления") FROM stdin;
\.


ALTER TABLE public."ОтслеживаниеТоваров" ENABLE TRIGGER ALL;

--
-- Data for Name: Скидка; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Скидка" DISABLE TRIGGER ALL;

COPY public."Скидка" ("Код_скидки", "Название", "Тип", "Размер", "Дата_начала", "Дата_окончания") FROM stdin;
1	Летняя распродажа	процентная	30.00	2025-06-01	2026-12-31
2	Осенняя коллекция -15%	процентная	15.00	2025-09-01	2026-12-31
3	Хит продаж	процентная	10.00	2025-01-01	2026-12-31
4	Скидка 500₽ на спорт	фиксированная	500.00	2025-01-01	2026-12-31
\.


ALTER TABLE public."Скидка" ENABLE TRIGGER ALL;

--
-- Data for Name: СкидкаЗаказа; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."СкидкаЗаказа" DISABLE TRIGGER ALL;

COPY public."СкидкаЗаказа" ("Код_заказа", "Код_скидки") FROM stdin;
\.


ALTER TABLE public."СкидкаЗаказа" ENABLE TRIGGER ALL;

--
-- Data for Name: СкидкаТовара; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."СкидкаТовара" DISABLE TRIGGER ALL;

COPY public."СкидкаТовара" ("Код_товара", "Код_скидки") FROM stdin;
7	1
8	1
11	1
18	1
19	1
3	2
6	2
12	2
15	2
17	2
20	2
1	3
13	3
16	3
5	4
4	4
\.


ALTER TABLE public."СкидкаТовара" ENABLE TRIGGER ALL;

--
-- Data for Name: СодержимоеЗаказа; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."СодержимоеЗаказа" DISABLE TRIGGER ALL;

COPY public."СодержимоеЗаказа" ("Код_заказа", "Код_товара", "Количество", "Цена_на_момент_покупки") FROM stdin;
3	13	1	6990.00
3	14	1	5990.00
3	15	1	8990.00
4	11	1	1599.00
4	8	1	2634.00
5	13	1	6990.00
6	10	2	799.00
6	2	1	1791.00
7	6	1	4667.00
7	16	1	1490.00
8	3	1	6792.00
8	1	1	2241.00
9	20	1	2990.00
9	19	1	1530.00
10	17	1	2990.00
\.


ALTER TABLE public."СодержимоеЗаказа" ENABLE TRIGGER ALL;

--
-- Data for Name: СодержимоеКорзины; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."СодержимоеКорзины" DISABLE TRIGGER ALL;

COPY public."СодержимоеКорзины" ("Код_покупателя", "Код_товара", "Количество") FROM stdin;
5	19	1
5	20	1
\.


ALTER TABLE public."СодержимоеКорзины" ENABLE TRIGGER ALL;

--
-- Data for Name: ТоварКатегория; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."ТоварКатегория" DISABLE TRIGGER ALL;

COPY public."ТоварКатегория" ("Код_товара", "Код_категории") FROM stdin;
1	2
2	2
4	2
10	2
16	2
1	5
2	5
3	5
4	5
5	5
6	5
3	6
17	6
20	6
7	1
11	1
18	1
5	3
9	3
13	3
14	3
6	4
12	4
15	4
8	7
19	8
\.


ALTER TABLE public."ТоварКатегория" ENABLE TRIGGER ALL;

--
-- Name: Адрес_Код_адреса_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Адрес_Код_адреса_seq"', 17, true);


--
-- Name: Бренд_Код_бренда_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Бренд_Код_бренда_seq"', 8, true);


--
-- Name: Заказ_Код_заказа_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Заказ_Код_заказа_seq"', 42, true);


--
-- Name: Категория_Код_категории_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Категория_Код_категории_seq"', 10, true);


--
-- Name: Купон_Код_купона_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Купон_Код_купона_seq"', 6, true);


--
-- Name: ЛогСтатусовЗаказа_Код_записи_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."ЛогСтатусовЗаказа_Код_записи_seq"', 5, true);


--
-- Name: Отзыв_Код_отзыва_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Отзыв_Код_отзыва_seq"', 16, true);


--
-- Name: Покупатель_Код_покупателя_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Покупатель_Код_покупателя_seq"', 26, true);


--
-- Name: Размер_Код_размера_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Размер_Код_размера_seq"', 18, true);


--
-- Name: Скидка_Код_скидки_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Скидка_Код_скидки_seq"', 4, true);


--
-- Name: СпособОплаты_Код_способа_оплаты_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."СпособОплаты_Код_способа_оплаты_seq"', 4, true);


--
-- Name: СпособПолучени_Код_способа_пол_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."СпособПолучени_Код_способа_пол_seq"', 4, true);


--
-- Name: Товар_Код_товара_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Товар_Код_товара_seq"', 20, true);


--
-- PostgreSQL database dump complete
--



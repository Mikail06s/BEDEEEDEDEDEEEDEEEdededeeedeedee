-- =====================================================================
-- ВАРИАНТ 2 - тестирование объектов базы данных bookstore_db
-- =====================================================================
SET NAMES utf8mb4;
USE bookstore_db;

-- ===========================
-- 1. Тестирование хранимой процедуры sell_book
-- ===========================
-- 1.1 Успешная продажа 5 экземпляров книги 1
CALL sell_book(1, 5);
SELECT * FROM sales WHERE book_id = 1;
SELECT id, title, stock FROM books WHERE id = 1;    -- остаток 20 -> 15

-- 1.2 Ошибка: книга не найдена
CALL sell_book(999, 5);
-- Ожидаемый результат: ошибка "Книга не найдена"

-- 1.3 Варнинг: недостаточно книг на складе (продажа не выполняется)
CALL sell_book(1, 50);
SHOW WARNINGS;
-- Ожидаемый результат: варнинг "Недостаточно книг на складе"

-- 1.4 Ошибка валидации: некорректное количество
CALL sell_book(1, 0);
-- Ожидаемый результат: ошибка "Количество должно быть положительным"

SELECT * FROM sales;        -- лишних продаж быть не должно

-- ===========================
-- 2. Тестирование функции get_books_by_supplier
-- ===========================
SELECT get_books_by_supplier(1)   AS books_count;   -- 2
SELECT get_books_by_supplier(2)   AS books_count;   -- 1
SELECT get_books_by_supplier(999) AS books_count;   -- 0 (не найден)

SELECT id, name, get_books_by_supplier(id) AS books_cnt FROM suppliers;

-- ===========================
-- 3. Тестирование триггера log_stock_update
-- ===========================
UPDATE books SET stock = stock - 2 WHERE id = 1;    -- лог появится
UPDATE books SET title = 'Война и миръ' WHERE id = 1; -- stock не менялся - лога нет
SELECT * FROM change_logs;

-- ===========================
-- 4. Тестирование представления supplier_sales_summary
-- ===========================
SELECT * FROM supplier_sales_summary;
SELECT * FROM supplier_sales_summary ORDER BY total_revenue DESC;

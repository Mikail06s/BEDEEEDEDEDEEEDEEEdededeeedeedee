-- =====================================================================
-- ВАРИАНТ 5 - тестирование объектов базы данных restaurant_db
-- =====================================================================
SET NAMES utf8mb4;
USE restaurant_db;

-- ===========================
-- 1. Тестирование хранимой процедуры place_order
-- ===========================
-- 1.1 Успешное размещение заказа за столом 1
CALL place_order(1, 1, 1, 1500.00);
SELECT * FROM orders;
SELECT id, table_number, status FROM `tables` WHERE id = 1;   -- occupied

-- 1.2 Варнинг: стол уже занят
CALL place_order(1, 2, 2, 2000.00);
SHOW WARNINGS;
-- Ожидаемый результат: варнинг "Стол уже занят"

-- 1.3 Ошибка: стол не найден
CALL place_order(999, 1, 1, 1500.00);
-- Ожидаемый результат: ошибка "Стол, клиент или официант не найдены"

-- 1.4 Ошибка валидации: некорректная сумма заказа
CALL place_order(2, 1, 1, 0);
-- Ожидаемый результат: ошибка "Сумма заказа должна быть положительной"

-- Ещё один успешный заказ (для наполнения представления)
CALL place_order(2, 2, 2, 2500.00);
SELECT * FROM orders;

-- ===========================
-- 2. Тестирование функции calculate_waiter_earnings
-- ===========================
SELECT calculate_waiter_earnings(1)   AS waiter_earnings;   -- 150.00
SELECT calculate_waiter_earnings(2)   AS waiter_earnings;   -- 250.00
SELECT calculate_waiter_earnings(999) AS waiter_earnings;   -- 0 (не найден)

SELECT id, full_name, calculate_waiter_earnings(id) AS earnings FROM waiters;

-- ===========================
-- 3. Тестирование триггера log_table_status_update
-- ===========================
UPDATE `tables` SET status = 'available' WHERE id = 1;  -- лог occupied -> available
UPDATE `tables` SET status = 'occupied'  WHERE id = 1;  -- лог available -> occupied
UPDATE `tables` SET capacity = 5         WHERE id = 1;  -- статус не менялся - лога нет
SELECT * FROM change_logs;

-- ===========================
-- 4. Тестирование представления waiter_orders_summary
-- ===========================
SELECT * FROM waiter_orders_summary;
SELECT * FROM waiter_orders_summary ORDER BY total_earnings DESC;

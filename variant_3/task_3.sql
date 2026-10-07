-- =====================================================================
-- ВАРИАНТ 3 - тестирование объектов базы данных car_dealership_db
-- =====================================================================
SET NAMES utf8mb4;
USE car_dealership_db;

-- ===========================
-- 1. Тестирование хранимой процедуры sell_car
-- ===========================
-- 1.1 Успешная продажа автомобиля 1 клиенту 1 менеджером 1
CALL sell_car(1, 1, 1);
SELECT * FROM orders WHERE client_id = 1 AND car_id = 1;
SELECT id, model, status FROM cars WHERE id = 1;    -- status = sold

-- 1.2 Ошибка: клиент не найден
CALL sell_car(999, 2, 1);
-- Ожидаемый результат: ошибка "Клиент, автомобиль или менеджер не найдены"

-- 1.3 Ошибка: менеджер не найден
CALL sell_car(1, 2, 999);
-- Ожидаемый результат: ошибка "Клиент, автомобиль или менеджер не найдены"

-- 1.4 Варнинг: автомобиль уже продан
CALL sell_car(2, 1, 2);
SHOW WARNINGS;
-- Ожидаемый результат: варнинг "Автомобиль уже продан"

-- Ещё одна успешная продажа (для наполнения представления)
CALL sell_car(2, 2, 2);
SELECT * FROM orders;

-- ===========================
-- 2. Тестирование функции calculate_commission
-- ===========================
SELECT calculate_commission(1)   AS commission;   -- 2500000 * 0.01 = 25000.00
SELECT calculate_commission(2)   AS commission;   -- 5500000 * 0.02 = 110000.00
SELECT calculate_commission(999) AS commission;   -- 0 (заказ не найден)

SELECT id, total, calculate_commission(id) AS commission FROM orders;

-- ===========================
-- 3. Тестирование триггера log_car_status_update
-- ===========================
UPDATE cars SET status = 'available' WHERE id = 1;  -- лог sold -> available
UPDATE cars SET status = 'sold'      WHERE id = 1;  -- лог available -> sold
UPDATE cars SET mileage = 21000      WHERE id = 1;  -- статус не менялся - лога нет
SELECT * FROM change_logs;

-- ===========================
-- 4. Тестирование представления manager_sales_summary
-- ===========================
SELECT * FROM manager_sales_summary;
SELECT * FROM manager_sales_summary ORDER BY total_commission DESC;

-- =====================================================================
-- ВАРИАНТ 4 - тестирование объектов базы данных hotel_db
-- =====================================================================
SET NAMES utf8mb4;
USE hotel_db;

-- ===========================
-- 1. Тестирование хранимой процедуры book_room
-- ===========================
-- 1.1 Успешное бронирование номера 1 (4 дня * 3000.00 = 12000.00)
CALL book_room(1, 1, 1, '2024-06-01', '2024-06-05');
SELECT * FROM bookings;
SELECT id, room_number, status FROM rooms WHERE id = 1;   -- booked

-- 1.2 Варнинг: номер уже забронирован
CALL book_room(2, 1, 1, '2024-07-01', '2024-07-05');
SHOW WARNINGS;
-- Ожидаемый результат: варнинг "Номер уже забронирован"

-- 1.3 Ошибка: гость не найден
CALL book_room(999, 2, 1, '2024-06-01', '2024-06-05');
-- Ожидаемый результат: ошибка "Гость, номер или сотрудник не найдены"

-- 1.4 Ошибка: некорректный период проживания
CALL book_room(1, 2, 1, '2024-06-10', '2024-06-05');
-- Ожидаемый результат: ошибка "Некорректный период проживания"

-- Ещё одно успешное бронирование (для наполнения представления)
CALL book_room(2, 2, 2, '2024-06-10', '2024-06-13');   -- 3 * 5000 = 15000.00
SELECT * FROM bookings;

-- ===========================
-- 2. Тестирование функции calculate_stay_cost
-- ===========================
SELECT calculate_stay_cost(1, 4)   AS stay_cost;   -- 12000.00
SELECT calculate_stay_cost(3, 2)   AS stay_cost;   -- 16000.00
SELECT calculate_stay_cost(999, 4) AS stay_cost;   -- 0 (номер не найден)

SELECT id, room_number, calculate_stay_cost(id, 5) AS cost_5_days FROM rooms;

-- ===========================
-- 3. Тестирование триггера log_room_status_update
-- ===========================
UPDATE rooms SET status = 'available' WHERE id = 1;   -- лог booked -> available
UPDATE rooms SET status = 'booked'    WHERE id = 1;   -- лог available -> booked
UPDATE rooms SET price_per_day = 3200 WHERE id = 1;   -- статус не менялся - лога нет
SELECT * FROM change_logs;

-- ===========================
-- 4. Тестирование представления employee_booking_summary
-- ===========================
SELECT * FROM employee_booking_summary;
SELECT * FROM employee_booking_summary ORDER BY total_revenue DESC;

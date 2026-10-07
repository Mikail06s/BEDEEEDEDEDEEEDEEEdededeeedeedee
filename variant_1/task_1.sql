-- =====================================================================
-- ВАРИАНТ 1 - тестирование объектов базы данных company_db
-- =====================================================================
SET NAMES utf8mb4;
USE company_db;

-- ===========================
-- 1. Тестирование хранимой процедуры assign_employee_to_project
-- ===========================
-- 1.1 Успешный вызов: добавление сотрудника 1 в проект 2
CALL assign_employee_to_project(1, 2, 'аналитик', 50);
SELECT * FROM employee_projects WHERE employee_id = 1 AND project_id = 2;
SELECT * FROM project_changes;                     -- запись с операцией assign

-- 1.2 Ошибка: сотрудник не найден
CALL assign_employee_to_project(999, 1, 'аналитик', 50);
-- Ожидаемый результат: ошибка "Сотрудник или проект не найдены"

-- 1.3 Ошибка: проект не найден
CALL assign_employee_to_project(1, 999, 'аналитик', 50);
-- Ожидаемый результат: ошибка "Сотрудник или проект не найдены"

-- 1.4 Варнинг: сотрудник уже участвует в проекте (данные не добавляются)
CALL assign_employee_to_project(1, 1, 'аналитик', 50);
SHOW WARNINGS;
-- Ожидаемый результат: варнинг "Сотрудник уже участвует в проекте"

-- 1.5 Ошибка валидации: отрицательное количество часов
CALL assign_employee_to_project(2, 2, 'разработчик', -10);
-- Ожидаемый результат: ошибка "Количество часов должно быть неотрицательным"

-- Проверка, что при ошибках лишних записей не появилось
SELECT * FROM employee_projects;

-- ===========================
-- 2. Тестирование функции get_project_count_for_employee
-- ===========================
SELECT get_project_count_for_employee(1)   AS project_count;   -- 2
SELECT get_project_count_for_employee(3)   AS project_count;   -- 1
SELECT get_project_count_for_employee(999) AS project_count;   -- 0 (не найден)

-- Использование функции в выборке
SELECT id, full_name, get_project_count_for_employee(id) AS projects_cnt
  FROM employees;

-- ===========================
-- 3. Тестирование триггера log_project_update
-- ===========================
UPDATE projects SET project_name = 'Новая CRM-система' WHERE id = 1;
UPDATE projects SET end_date = '2024-06-30'            WHERE id = 2;
SELECT * FROM change_logs;                        -- строки лога изменений

-- ===========================
-- 4. Тестирование представления employee_project_summary
-- ===========================
SELECT * FROM employee_project_summary;
SELECT * FROM employee_project_summary WHERE hours_worked > 100;

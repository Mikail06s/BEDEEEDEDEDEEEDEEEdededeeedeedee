
SET NAMES utf8mb4;
SET foreign_key_checks = 0;

DROP DATABASE IF EXISTS company_db;
CREATE DATABASE IF NOT EXISTS company_db
    DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE company_db;

CREATE TABLE employees (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    birth_date DATE        NOT NULL,
    position  VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO employees (full_name, birth_date, position) VALUES
('Иван Иванов',    '1985-02-14', 'аналитик'),
('Петр Петров',    '1990-08-10', 'разработчик'),
('Мария Смирнова', '1987-05-22', 'тестировщик');

CREATE TABLE projects (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    project_name VARCHAR(255) NOT NULL,
    start_date   DATE NOT NULL,
    end_date     DATE DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO projects (project_name, start_date, end_date) VALUES
('CRM-система',    '2023-01-01', '2023-12-31'),
('Веб-приложение', '2023-03-01', NULL);

CREATE TABLE employee_projects (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    employee_id  INT NOT NULL,
    project_id   INT NOT NULL,
    role         VARCHAR(100) NOT NULL,
    hours_worked INT DEFAULT 0,
    FOREIGN KEY (employee_id) REFERENCES employees (id),
    FOREIGN KEY (project_id)  REFERENCES projects (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO employee_projects (employee_id, project_id, role, hours_worked) VALUES
(1, 1, 'аналитик',    120),
(2, 1, 'разработчик', 200),
(3, 2, 'тестировщик',  80);

CREATE TABLE project_changes (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    project_id     INT NOT NULL,
    operation      VARCHAR(255) NOT NULL,
    operation_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE change_logs (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    entity_id   INT,
    old_value   VARCHAR(255),
    new_value   VARCHAR(255),
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET foreign_key_checks = 1;

DROP PROCEDURE IF EXISTS assign_employee_to_project;
DELIMITER $$
CREATE PROCEDURE assign_employee_to_project(
    IN p_employee_id INT,
    IN p_project_id  INT,
    IN p_role        VARCHAR(100),
    IN p_hours       INT
)
proc_label: BEGIN
    DECLARE v_employee_count INT DEFAULT 0;
    DECLARE v_project_count  INT DEFAULT 0;
    DECLARE v_already        INT DEFAULT 0;
    DECLARE v_new_id         INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_hours IS NULL OR p_hours < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Количество часов должно быть неотрицательным';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_employee_count FROM employees WHERE id = p_employee_id;
    SELECT COUNT(*) INTO v_project_count  FROM projects  WHERE id = p_project_id;

    IF v_employee_count = 0 OR v_project_count = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Сотрудник или проект не найдены';
    END IF;

    SELECT COUNT(*) INTO v_already
      FROM employee_projects
     WHERE employee_id = p_employee_id AND project_id = p_project_id;

    IF v_already > 0 THEN
        ROLLBACK;                       -- данные не добавляются
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT = 'Сотрудник уже участвует в проекте';
        LEAVE proc_label;
    END IF;

    -- основная операция
    INSERT INTO employee_projects (employee_id, project_id, role, hours_worked)
    VALUES (p_employee_id, p_project_id, p_role, IFNULL(p_hours, 0));

    SET v_new_id = LAST_INSERT_ID();

    INSERT INTO project_changes (project_id, operation, operation_time)
    VALUES (p_project_id,
            CONCAT('assign (employee_id=', p_employee_id,
                   ', ep_id=', v_new_id, ')'),
            NOW());

    COMMIT;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS get_project_count_for_employee;
DELIMITER $$
CREATE FUNCTION get_project_count_for_employee(p_employee_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_employee_count INT DEFAULT 0;
    DECLARE v_result         INT DEFAULT 0;

    SELECT COUNT(*) INTO v_employee_count FROM employees WHERE id = p_employee_id;

    IF v_employee_count = 0 THEN
        RETURN 0; 
    END IF;

    SELECT COUNT(DISTINCT project_id) INTO v_result
      FROM employee_projects
     WHERE employee_id = p_employee_id;

    RETURN IFNULL(v_result, 0);
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS log_project_update;
DELIMITER $$
CREATE TRIGGER log_project_update
AFTER UPDATE ON projects
FOR EACH ROW
BEGIN
    INSERT INTO change_logs (entity_id, old_value, new_value, change_time)
    VALUES (OLD.id, OLD.project_name, NEW.project_name, NOW());
END$$
DELIMITER ;

DROP VIEW IF EXISTS employee_project_summary;
CREATE VIEW employee_project_summary AS
SELECT e.full_name                AS full_name,
       e.position                 AS position,
       p.project_name             AS project_name,
       IFNULL(ep.hours_worked, 0) AS hours_worked
  FROM employees e
  JOIN employee_projects ep ON ep.employee_id = e.id
  JOIN projects p          ON p.id = ep.project_id;

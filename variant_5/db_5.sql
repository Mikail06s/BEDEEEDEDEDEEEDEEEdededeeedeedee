SET NAMES utf8mb4;
SET foreign_key_checks = 0;

DROP DATABASE IF EXISTS restaurant_db;
CREATE DATABASE IF NOT EXISTS restaurant_db
    DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE restaurant_db;

CREATE TABLE `tables` (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    table_number INT NOT NULL UNIQUE,
    capacity     INT NOT NULL,
    status       ENUM('available','occupied') NOT NULL DEFAULT 'available'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `tables` (table_number, capacity, status) VALUES
(1, 4, 'available'),
(2, 2, 'available'),
(3, 6, 'available');

CREATE TABLE clients (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    phone     VARCHAR(20)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO clients (full_name, phone) VALUES
('Иван Иванов',    '8007001111'),
('Мария Смирнова', '8007002222'),
('Пётр Петров',    '8007003333');

CREATE TABLE waiters (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    phone     VARCHAR(20),
    salary    DECIMAL(10,2) NOT NULL DEFAULT 50000.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO waiters (full_name, phone, salary) VALUES
('Анна Кузнецова', '8005551234', 50000.00),
('Сергей Волков',  '8005555678', 48000.00);

CREATE TABLE orders (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    table_id   INT NOT NULL,
    client_id  INT NOT NULL,
    waiter_id  INT NOT NULL,
    order_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_cost DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (table_id)  REFERENCES `tables` (id),
    FOREIGN KEY (client_id) REFERENCES clients (id),
    FOREIGN KEY (waiter_id) REFERENCES waiters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE change_logs (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    entity_id   INT,
    old_value   VARCHAR(255),
    new_value   VARCHAR(255),
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET foreign_key_checks = 1;

DROP PROCEDURE IF EXISTS place_order;
DELIMITER $$
CREATE PROCEDURE place_order(
    IN p_table_id   INT,
    IN p_client_id  INT,
    IN p_waiter_id  INT,
    IN p_total_cost DECIMAL(10,2)
)
proc_label: BEGIN
    DECLARE v_table_count  INT DEFAULT 0;
    DECLARE v_client_count INT DEFAULT 0;
    DECLARE v_waiter_count INT DEFAULT 0;
    DECLARE v_status       VARCHAR(20) DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_total_cost IS NULL OR p_total_cost <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Сумма заказа должна быть положительной';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_table_count  FROM `tables` WHERE id = p_table_id;
    SELECT COUNT(*) INTO v_client_count FROM clients  WHERE id = p_client_id;
    SELECT COUNT(*) INTO v_waiter_count FROM waiters  WHERE id = p_waiter_id;

    IF v_table_count = 0 OR v_client_count = 0 OR v_waiter_count = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Стол, клиент или официант не найдены';
    END IF;

    SELECT status INTO v_status FROM `tables` WHERE id = p_table_id FOR UPDATE;

    IF v_status = 'occupied' THEN
        ROLLBACK;                       -- заказ не создаётся
        SIGNAL SQLSTATE '01000' SET MESSAGE_TEXT = 'Стол уже занят';
        LEAVE proc_label;
    END IF;

    INSERT INTO orders (table_id, client_id, waiter_id, order_time, total_cost)
    VALUES (p_table_id, p_client_id, p_waiter_id, NOW(), p_total_cost);

    UPDATE `tables` SET status = 'occupied' WHERE id = p_table_id;

    COMMIT;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS calculate_waiter_earnings;
DELIMITER $$
CREATE FUNCTION calculate_waiter_earnings(p_waiter_id INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_waiter_count INT DEFAULT 0;
    DECLARE v_earnings     DECIMAL(12,2) DEFAULT 0.00;

    SELECT COUNT(*) INTO v_waiter_count FROM waiters WHERE id = p_waiter_id;

    IF v_waiter_count = 0 THEN
        RETURN 0;
    END IF;

    SELECT IFNULL(SUM(total_cost) * 0.10, 0) INTO v_earnings
      FROM orders WHERE waiter_id = p_waiter_id;

    RETURN IFNULL(v_earnings, 0);
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS log_table_status_update;
DELIMITER $$
CREATE TRIGGER log_table_status_update
AFTER UPDATE ON `tables`
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO change_logs (entity_id, old_value, new_value, change_time)
        VALUES (OLD.id, OLD.status, NEW.status, NOW());
    END IF;
END$$
DELIMITER ;

DROP VIEW IF EXISTS waiter_orders_summary;
CREATE VIEW waiter_orders_summary AS
SELECT w.full_name                            AS waiter_name,
       COUNT(o.id)                            AS total_orders,
       ROUND(IFNULL(SUM(o.total_cost) * 0.10, 0.00), 2) AS total_earnings
  FROM waiters w
  LEFT JOIN orders o ON o.waiter_id = w.id
 GROUP BY w.id, w.full_name;

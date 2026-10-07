SET NAMES utf8mb4;
SET foreign_key_checks = 0;

DROP DATABASE IF EXISTS car_dealership_db;
CREATE DATABASE IF NOT EXISTS car_dealership_db
    DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE car_dealership_db;

CREATE TABLE cars (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    vin     VARCHAR(17) NOT NULL UNIQUE,
    model   VARCHAR(255) NOT NULL,
    mileage INT NOT NULL,
    price   DECIMAL(10,2) NOT NULL,
    status  ENUM('available','sold') NOT NULL DEFAULT 'available'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO cars (vin, model, mileage, price, status) VALUES
('1HGCM82633A123456', 'Toyota Camry',    20000, 2500000, 'available'),
('WBA3A5C58DF123457', 'BMW X5',          10000, 5500000, 'available'),
('KM8J3CA46KU123458', 'Hyundai Solaris', 15000, 1200000, 'available');

CREATE TABLE clients (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    phone     VARCHAR(20)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO clients (full_name, phone) VALUES
('Алексей Смирнов',  '8007001111'),
('Елена Кузнецова',  '8007002222'),
('Дмитрий Павлов',   '8007003333');

CREATE TABLE managers (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(255) NOT NULL,
    phone           VARCHAR(20),
    commission_rate DECIMAL(5,2) NOT NULL DEFAULT 0.01
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO managers (full_name, phone, commission_rate) VALUES
('Иван Иванов', '8005551234', 0.01),
('Пётр Петров', '8005555678', 0.02);

CREATE TABLE orders (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    client_id  INT NOT NULL,
    car_id     INT NOT NULL,
    manager_id INT NOT NULL,
    order_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total      DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (client_id)  REFERENCES clients (id),
    FOREIGN KEY (car_id)     REFERENCES cars (id),
    FOREIGN KEY (manager_id) REFERENCES managers (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE change_logs (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    entity_id   INT,
    old_value   VARCHAR(255),
    new_value   VARCHAR(255),
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET foreign_key_checks = 1;

DROP PROCEDURE IF EXISTS sell_car;
DELIMITER $$
CREATE PROCEDURE sell_car(
    IN p_client_id  INT,
    IN p_car_id     INT,
    IN p_manager_id INT
)
proc_label: BEGIN
    DECLARE v_client_count  INT DEFAULT 0;
    DECLARE v_car_count     INT DEFAULT 0;
    DECLARE v_manager_count INT DEFAULT 0;
    DECLARE v_status        VARCHAR(20) DEFAULT '';
    DECLARE v_price         DECIMAL(10,2) DEFAULT 0.00;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_client_count  FROM clients  WHERE id = p_client_id;
    SELECT COUNT(*) INTO v_car_count     FROM cars     WHERE id = p_car_id;
    SELECT COUNT(*) INTO v_manager_count FROM managers WHERE id = p_manager_id;

    IF v_client_count = 0 OR v_car_count = 0 OR v_manager_count = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Клиент, автомобиль или менеджер не найдены';
    END IF;

    SELECT status, price INTO v_status, v_price
      FROM cars WHERE id = p_car_id FOR UPDATE;

    IF v_status = 'sold' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '01000' SET MESSAGE_TEXT = 'Автомобиль уже продан';
        LEAVE proc_label;
    END IF;

    UPDATE cars SET status = 'sold' WHERE id = p_car_id;

    INSERT INTO orders (client_id, car_id, manager_id, order_date, total)
    VALUES (p_client_id, p_car_id, p_manager_id, NOW(), v_price);

    COMMIT;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS calculate_commission;
DELIMITER $$
CREATE FUNCTION calculate_commission(p_order_id INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_order_count INT DEFAULT 0;
    DECLARE v_commission  DECIMAL(12,2) DEFAULT 0.00;

    SELECT COUNT(*) INTO v_order_count FROM orders WHERE id = p_order_id;

    IF v_order_count = 0 THEN
        RETURN 0;
    END IF;

    SELECT o.total * m.commission_rate INTO v_commission
      FROM orders o
      JOIN managers m ON m.id = o.manager_id
     WHERE o.id = p_order_id;

    RETURN IFNULL(v_commission, 0);
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS log_car_status_update;
DELIMITER $$
CREATE TRIGGER log_car_status_update
AFTER UPDATE ON cars
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO change_logs (entity_id, old_value, new_value, change_time)
        VALUES (OLD.id, OLD.status, NEW.status, NOW());
    END IF;
END$$
DELIMITER ;

DROP VIEW IF EXISTS manager_sales_summary;
CREATE VIEW manager_sales_summary AS
SELECT m.full_name                                AS manager_name,
       COUNT(o.id)                                AS total_cars_sold,
       ROUND(IFNULL(SUM(o.total * m.commission_rate), 0), 2) AS total_commission
  FROM managers m
  LEFT JOIN orders o ON o.manager_id = m.id
  LEFT JOIN cars   c ON c.id = o.car_id AND c.status = 'sold'
 GROUP BY m.id, m.full_name;

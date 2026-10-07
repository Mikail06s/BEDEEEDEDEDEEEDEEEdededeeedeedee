SET NAMES utf8mb4;
SET foreign_key_checks = 0;

DROP DATABASE IF EXISTS hotel_db;
CREATE DATABASE IF NOT EXISTS hotel_db
    DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE hotel_db;

CREATE TABLE rooms (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    room_number   INT NOT NULL UNIQUE,
    room_type     VARCHAR(50) NOT NULL,
    price_per_day DECIMAL(10,2) NOT NULL,
    status        ENUM('available','booked') NOT NULL DEFAULT 'available'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO rooms (room_number, room_type, price_per_day, status) VALUES
(101, 'standard', 3000.00, 'available'),
(202, 'deluxe',   5000.00, 'available'),
(303, 'suite',    8000.00, 'available');

CREATE TABLE guests (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    phone     VARCHAR(15)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO guests (full_name, phone) VALUES
('Иван Иванов',    '8007001111'),
('Мария Смирнова', '8007002222'),
('Пётр Петров',    '8007003333');

CREATE TABLE employees (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    position  VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO employees (full_name, position) VALUES
('Анна Кузнецова', 'администратор'),
('Сергей Волков',  'менеджер');

CREATE TABLE bookings (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    guest_id        INT NOT NULL,
    room_id         INT NOT NULL,
    employee_id     INT NOT NULL,
    check_in_date   DATE NOT NULL,
    check_out_date  DATE NOT NULL,
    total_cost      DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (guest_id)    REFERENCES guests (id),
    FOREIGN KEY (room_id)     REFERENCES rooms (id),
    FOREIGN KEY (employee_id) REFERENCES employees (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE change_logs (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    entity_id   INT,
    old_value   VARCHAR(255),
    new_value   VARCHAR(255),
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET foreign_key_checks = 1;

DROP PROCEDURE IF EXISTS book_room;
DELIMITER $$
CREATE PROCEDURE book_room(
    IN p_guest_id       INT,
    IN p_room_id        INT,
    IN p_employee_id    INT,
    IN p_check_in_date  DATE,
    IN p_check_out_date DATE
)
proc_label: BEGIN
    DECLARE v_guest_count    INT DEFAULT 0;
    DECLARE v_room_count     INT DEFAULT 0;
    DECLARE v_employee_count INT DEFAULT 0;
    DECLARE v_status         VARCHAR(20) DEFAULT '';
    DECLARE v_price          DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_days           INT DEFAULT 0;
    DECLARE v_total          DECIMAL(10,2) DEFAULT 0.00;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- контроль дат
    IF p_check_in_date IS NULL OR p_check_out_date IS NULL
       OR p_check_out_date <= p_check_in_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Некорректный период проживания';
    END IF;

    START TRANSACTION;

    -- проверка существования гостя, номера и сотрудника
    SELECT COUNT(*) INTO v_guest_count    FROM guests    WHERE id = p_guest_id;
    SELECT COUNT(*) INTO v_room_count     FROM rooms     WHERE id = p_room_id;
    SELECT COUNT(*) INTO v_employee_count FROM employees WHERE id = p_employee_id;

    IF v_guest_count = 0 OR v_room_count = 0 OR v_employee_count = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Гость, номер или сотрудник не найдены';
    END IF;

    -- проверка доступности номера
    SELECT status, price_per_day INTO v_status, v_price
      FROM rooms WHERE id = p_room_id FOR UPDATE;

    IF v_status = 'booked' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '01000' SET MESSAGE_TEXT = 'Номер уже забронирован';
        LEAVE proc_label;
    END IF;

    SET v_days  = DATEDIFF(p_check_out_date, p_check_in_date);
    SET v_total = v_days * v_price;

    INSERT INTO bookings (guest_id, room_id, employee_id,
                          check_in_date, check_out_date, total_cost)
    VALUES (p_guest_id, p_room_id, p_employee_id,
            p_check_in_date, p_check_out_date, v_total);

    UPDATE rooms SET status = 'booked' WHERE id = p_room_id;

    COMMIT;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS calculate_stay_cost;
DELIMITER $$
CREATE FUNCTION calculate_stay_cost(p_room_id INT, p_days INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_room_count INT DEFAULT 0;
    DECLARE v_price      DECIMAL(10,2) DEFAULT 0.00;

    SELECT COUNT(*) INTO v_room_count FROM rooms WHERE id = p_room_id;

    IF v_room_count = 0 OR p_days IS NULL OR p_days <= 0 THEN
        RETURN 0;
    END IF;

    SELECT price_per_day INTO v_price FROM rooms WHERE id = p_room_id;

    RETURN IFNULL(v_price * p_days, 0);
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS log_room_status_update;
DELIMITER $$
CREATE TRIGGER log_room_status_update
AFTER UPDATE ON rooms
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO change_logs (entity_id, old_value, new_value, change_time)
        VALUES (OLD.id, OLD.status, NEW.status, NOW());
    END IF;
END$$
DELIMITER ;

DROP VIEW IF EXISTS employee_booking_summary;
CREATE VIEW employee_booking_summary AS
SELECT e.full_name                      AS employee_name,
       COUNT(b.id)                      AS total_bookings,
       IFNULL(SUM(b.total_cost), 0.00)  AS total_revenue
  FROM employees e
  LEFT JOIN bookings b ON b.employee_id = e.id
  LEFT JOIN rooms    r ON r.id = b.room_id
 GROUP BY e.id, e.full_name;

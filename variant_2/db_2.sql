SET NAMES utf8mb4;
SET foreign_key_checks = 0;

DROP DATABASE IF EXISTS bookstore_db;
CREATE DATABASE IF NOT EXISTS bookstore_db
    DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE bookstore_db;

CREATE TABLE authors (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(255) NOT NULL,
    birth_date DATE NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO authors (name, birth_date) VALUES
('Лев Толстой',       '1828-09-09'),
('Фёдор Достоевский', '1821-11-11'),
('Михаил Булгаков',   '1891-05-15');

CREATE TABLE suppliers (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255) NOT NULL,
    phone          VARCHAR(20)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO suppliers (name, contact_person, phone) VALUES
('ООО "Книжный Мир"',     'Иван Иванов', '8005551234'),
('ИП "Книги для всех"',   'Пётр Петров', '8005555678');

CREATE TABLE books (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    title       VARCHAR(255)   NOT NULL,
    author_id   INT            NOT NULL,
    supplier_id INT            NOT NULL,
    price       DECIMAL(10,2)  NOT NULL,
    stock       INT            NOT NULL,
    FOREIGN KEY (author_id)   REFERENCES authors (id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO books (title, author_id, supplier_id, price, stock) VALUES
('Война и мир',              1, 1, 500.00, 20),
('Преступление и наказание', 2, 2, 300.00, 15),
('Мастер и Маргарита',       3, 1, 400.00, 10);

CREATE TABLE sales (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    book_id   INT NOT NULL,
    sale_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    quantity  INT NOT NULL,
    total     DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (book_id) REFERENCES books (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE change_logs (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    entity_id   INT,
    old_value   VARCHAR(255),
    new_value   VARCHAR(255),
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET foreign_key_checks = 1;

DROP PROCEDURE IF EXISTS sell_book;
DELIMITER $$
CREATE PROCEDURE sell_book(
    IN p_book_id  INT,
    IN p_quantity INT
)
proc_label: BEGIN
    DECLARE v_book_count INT DEFAULT 0;
    DECLARE v_stock      INT DEFAULT 0;
    DECLARE v_price      DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_total      DECIMAL(10,2) DEFAULT 0.00;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Количество должно быть положительным';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_book_count FROM books WHERE id = p_book_id;

    IF v_book_count = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Книга не найдена';
    END IF;

    SELECT stock, price INTO v_stock, v_price
      FROM books WHERE id = p_book_id FOR UPDATE;

    IF v_stock < p_quantity THEN
        ROLLBACK;
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT = 'Недостаточно книг на складе';
        LEAVE proc_label;
    END IF;

    SET v_total = v_price * p_quantity;

    UPDATE books SET stock = stock - p_quantity WHERE id = p_book_id;

    INSERT INTO sales (book_id, sale_date, quantity, total)
    VALUES (p_book_id, NOW(), p_quantity, v_total);

    COMMIT;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS get_books_by_supplier;
DELIMITER $$
CREATE FUNCTION get_books_by_supplier(p_supplier_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_supplier_count INT DEFAULT 0;
    DECLARE v_result         INT DEFAULT 0;

    SELECT COUNT(*) INTO v_supplier_count FROM suppliers WHERE id = p_supplier_id;

    IF v_supplier_count = 0 THEN
        RETURN 0; 
    END IF;

    SELECT COUNT(*) INTO v_result FROM books WHERE supplier_id = p_supplier_id;

    RETURN IFNULL(v_result, 0);
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS log_stock_update;
DELIMITER $$
CREATE TRIGGER log_stock_update
AFTER UPDATE ON books
FOR EACH ROW
BEGIN
    IF OLD.stock <> NEW.stock THEN
        INSERT INTO change_logs (entity_id, old_value, new_value, change_time)
        VALUES (OLD.id, CAST(OLD.stock AS CHAR), CAST(NEW.stock AS CHAR), NOW());
    END IF;
END$$
DELIMITER ;

DROP VIEW IF EXISTS supplier_sales_summary;
CREATE VIEW supplier_sales_summary AS
SELECT sp.name                     AS supplier_name,
       IFNULL(SUM(s.quantity), 0)  AS total_books,
       IFNULL(SUM(s.total), 0.00)  AS total_revenue
  FROM suppliers sp
  LEFT JOIN books b ON b.supplier_id = sp.id
  LEFT JOIN sales s ON s.book_id    = b.id
 GROUP BY sp.id, sp.name;

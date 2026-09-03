--Class 1--
-- A Intro to Databases / DBMS

Create Database lab_6020;

-- ==========================================
-- 1. Database and Table Creation
-- ==========================================

Create table Products(
  pname varchar(20),
  price decimal(5,2),
  category varchar(20),
  manufacturer varchar (40)
);

-- Verify table structure
select * from Products;

-- ==========================================
-- 2. Inserting Data and Data Type Limits
-- ==========================================

-- This succeeds: 299.99 fits in DECIMAL(5,2)
insert into Products 
values("IPhone 13","299.99","Cellphone","Apple");

-- This fails: 1299.99 exceeds DECIMAL(5,2) max of 999.99
-- Error: Out of range value for column 'price'
insert into Products 
values("IPhone 17 Pro","1299.99","Cellphone","Apple");

-- Fix: ALTER TABLE to increase precision
ALTER TABLE Products 
MODIFY COLUMN price DECIMAL(7,2);

-- Now this succeeds: 1299.99 fits in DECIMAL(7,2)
insert into Products 
values("IPhone 17 Pro","1299.99","Cellphone","Apple");

-- ==========================================
-- 3. Dropping a Table
-- ==========================================

-- Drop table Products;
-- The INSERT below would fail because table no longer exists
-- insert into Products values("IPhone 17 Pro","Cellphone","Apple");

-- ==========================================
-- 4. Partial Inserts and Primary Keys
-- ==========================================

-- Partial insert: only specified columns get values, others become NULL
insert into Products(pname,manufacturer,category)
values("IPhone 11","Apple","Cellphone");

-- Add composite Primary Key on (pname, manufacturer)
ALTER TABLE Products 
ADD PRIMARY KEY (pname, manufacturer);

-- ==========================================
-- 5. Resetting Data with TRUNCATE
-- ==========================================

Truncate Table Products;

INSERT INTO Products VALUES ('Gizmo', 19.99, 'Gadgets', 'GizmoWorks');
INSERT INTO Products VALUES ('Powergizmo', 29.99, 'Gadgets', 'GizmoWorks');
INSERT INTO Products VALUES ('SingleTouch', 149.99, 'Photography', 'Canon');
INSERT INTO Products VALUES ('MultiTouch', 203.99, 'Household', 'Hitachi');

-- ==========================================
-- 6. SELECT, FROM, WHERE
-- ==========================================

-- Query 1: Returns 3 columns for Gadgets
SELECT pname, manufacturer, price FROM Products 
WHERE category = 'Gadgets';

-- Query 2: Returns 2 columns for Gadgets
SELECT pname, manufacturer FROM Products 
WHERE category = 'Gadgets';

-- ==========================================
-- 7. ORDER BY
-- ==========================================

-- Sort products by price descending (highest first)
SELECT pname, price, category FROM Products ORDER BY price DESC;

-- Sort by category ascending, then price descending within each category
SELECT pname, price, category FROM Products 
ORDER BY category ASC, price DESC;

-- ==========================================
-- 8. Handling Special Column Names
-- ==========================================

create table student(
  `Student name` varchar(20)
);

-- Query with backticks for column with space
select `Student name` from student;

-- ==========================================
-- 9. GROUP BY and HAVING
-- ==========================================

-- Count products per category
SELECT category, COUNT(*) AS product_count
FROM Products
GROUP BY category;

-- Only show categories with more than 1 product
SELECT category, COUNT(*) AS product_count
FROM Products
GROUP BY category
HAVING COUNT(*) > 1;

-- ==========================================
-- 10. JOINs (with Orders table)
-- ==========================================

-- Create an Orders table to demonstrate JOINs
Create table Orders(
  order_id int PRIMARY KEY,
  pname varchar(20),
  quantity int,
  order_date date,
  FOREIGN KEY (pname) REFERENCES Products(pname)
);

INSERT INTO Orders VALUES (1, 'Gizmo', 10, '2024-01-15');
INSERT INTO Orders VALUES (2, 'Powergizmo', 5, '2024-01-16');
INSERT INTO Orders VALUES (3, 'SingleTouch', 3, '2024-01-17');
INSERT INTO Orders VALUES (4, 'Gizmo', 8, '2024-01-18');
INSERT INTO Orders VALUES (5, 'IPhone 13', 2, '2024-01-19');

-- INNER JOIN: Only products that have orders
SELECT Products.pname, Products.price, Orders.quantity, Orders.order_date
FROM Products
INNER JOIN Orders ON Products.pname = Orders.pname;

-- LEFT JOIN: All products, even those without orders
SELECT Products.pname, Products.price, Orders.quantity
FROM Products
LEFT JOIN Orders ON Products.pname = Orders.pname;

-- ==========================================
-- 11. INTERSECT Workaround (MySQL)
-- ==========================================

-- MySQL does not support INTERSECT directly.
-- This is the equivalent using INNER JOIN:
-- Find product names that are both in 'Gadgets' category AND priced over 100
SELECT DISTINCT p1.pname
FROM Products p1
INNER JOIN Products p2 ON p1.pname = p2.pname
WHERE p1.category = 'Gadgets' AND p2.price > 100;

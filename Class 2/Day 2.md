# Day 2: Keys, Constraints, Data Integrity, and Advanced SQL

## 1. Keys and Constraints

Keys are fundamental to relational databases. They uniquely identify rows and establish relationships between tables.

### Primary Key

A column (or set of columns) that uniquely identifies each row in a table. It cannot be NULL and must be unique.

Example from Day 2.sql:

```sql
sid int PRIMARY KEY
```

Here, `sid` is the primary key of the `Students` table.

### Foreign Key

A column (or set of columns) in one table that refers to the primary key in another table. It enforces referential integrity.

Example:

```sql
FOREIGN KEY (sid) REFERENCES Students(sid)
```

This ensures every `sid` in `Enrollments` must exist in `Students`.

### Candidate Key / Super Key

- **Super Key**: Any set of columns that uniquely identifies a row.
- **Candidate Key**: A minimal super key (no subset of its columns can uniquely identify a row).
- **Primary Key**: The chosen candidate key.

### Constraints

- **NOT NULL**: Ensures a column cannot have NULL values.
  Example: `sname varchar(20) NOT NULL`
- **UNIQUE**: Ensures all values in a column are distinct.
  Example: `email varchar(30) UNIQUE`
- **DEFAULT**: Assigns a default value when no value is provided.
  Example: `credits int DEFAULT 3`
- **CHECK**: Ensures values in a column satisfy a specific condition.
  Example: `age int CHECK (age >= 5)`
- **PRIMARY KEY**: Combines NOT NULL and UNIQUE. Uniquely identifies each row.
- **FOREIGN KEY**: Enforces a link between tables.

## 2. Data Integrity

Data integrity ensures the accuracy, consistency, and reliability of data in a database.

```sql
-- Entity Integrity: Every table needs a primary key
CREATE TABLE Students (
  sid INT PRIMARY KEY,
  sname VARCHAR(20) NOT NULL
);

-- Referential Integrity: Foreign keys must reference valid primary keys
CREATE TABLE Enrollments (
  sid INT,
  cid INT,
  grade VARCHAR(2),
  PRIMARY KEY (sid, cid),
  FOREIGN KEY (sid) REFERENCES Students(sid),
  FOREIGN KEY (cid) REFERENCES Courses(cid)
);

-- Domain Integrity: Data must conform to defined domains
CREATE TABLE Courses (
  cid INT PRIMARY KEY,
  cname VARCHAR(30) NOT NULL,
  credits INT DEFAULT 3 CHECK (credits > 0 AND credits <= 6)
);
```

### Entity Integrity

Each table must have a primary key, and the primary key must be unique and not NULL.

Example: `sid int PRIMARY KEY` in `Students` ensures every student has a unique identifier.

### Referential Integrity

Foreign keys must reference valid primary keys in another table, or be NULL.

Example: The `sid` in `Enrollments` must match an existing `sid` in `Students`. You cannot enroll a non-existent student.

### Domain Integrity

Data must fall within a defined domain (valid range, type, format).

Examples:

- `age int CHECK (age >= 5)` ensures age is at least 5.
- `credits int DEFAULT 3` ensures a default value if none is provided.
- Data types enforce domain integrity (e.g., `varchar(20)` restricts string length).

## 3. More SELECT Statements

SELECT is the most used SQL command. Day 2 expands on filtering, sorting, grouping, and aggregation.

### DISTINCT

Removes duplicate values from the result set.

**Syntax:**

```sql
SELECT DISTINCT column1 FROM table_name;
```

**Example:**

```sql
SELECT DISTINCT category FROM Products;
```

This returns only unique category values, eliminating duplicates.

With multiple columns:

```sql
SELECT DISTINCT category, manufacturer FROM Products;
```

This returns unique pairs of category and manufacturer.

Common use case: Counting unique values.

```sql
SELECT COUNT(DISTINCT category) AS UniqueCategories FROM Products;
```

**Note:** `DISTINCT` applies to all selected columns. If you select multiple columns, the combination must be unique for a row to appear.

### ORDER BY

Sorts the result set.

**Example:**

```sql
SELECT sname, age FROM Students ORDER BY age DESC;
```

Returns students sorted from oldest to youngest.

### GROUP BY

Groups rows sharing the same values in specified columns.

**Example:**

```sql
SELECT c.cname, COUNT(e.sid) AS Enrolled
FROM Courses c
JOIN Enrollments e ON c.cid = e.cid
GROUP BY c.cname;
```

This returns each course name and the number of students enrolled.

### Aggregate Functions

Aggregate functions perform calculations on a set of values and return a single value.

- **COUNT(*)**: Counts all rows, including duplicates and NULLs.
  Example: `SELECT COUNT(*) AS TotalStudents FROM Students;`

- **COUNT(column)**: Counts non-NULL values in a column.
  Example: `SELECT COUNT(email) AS StudentsWithEmail FROM Students;`

- **COUNT(DISTINCT column)**: Counts unique non-NULL values.
  Example: `SELECT COUNT(DISTINCT category) AS UniqueCategories FROM Products;`
  This is useful when you want to know how many different categories exist, not how many products.

- **SUM(column)**: Sums numeric values.
  Example: `SELECT SUM(credits) FROM Courses;`

- **AVG(column)**: Calculates the average.
  Example: `SELECT AVG(age) AS AvgAge FROM Students;`

- **MIN(column) / MAX(column)**: Returns the smallest/largest value.
  Example: `SELECT MAX(age) AS Oldest FROM Students;`

**Important Notes:**

- Aggregate functions ignore NULL values (except COUNT(*)).
- When using aggregate functions with GROUP BY, the aggregate is calculated per group.
- You cannot mix aggregated and non-aggregated columns in the SELECT list without a GROUP BY clause.

## 4. Joins

Joins combine data from multiple tables.

### INNER JOIN

Returns rows when there is a match in both tables.

Example from Day 2.sql:

```sql
SELECT s.sname, c.cname, e.grade
FROM Students s
JOIN Enrollments e ON s.sid = e.sid
JOIN Courses c ON e.cid = c.cid;
```

This returns each student's name, course name, and grade for all enrollments.

### LEFT JOIN (LEFT OUTER JOIN)

Returns all rows from the left table, and matched rows from the right table. Unmatched rows show NULL.

Example:

```sql
SELECT s.sname, c.cname
FROM Students s
LEFT JOIN Enrollments e ON s.sid = e.sid
LEFT JOIN Courses c ON e.cid = c.cid;
```

This returns all students, even those not enrolled in any course (course name will be NULL).

### RIGHT JOIN

Opposite of LEFT JOIN. Returns all rows from the right table.

### Self Join

A table is joined to itself. Useful for comparing rows within the same table.

Example:

```sql
SELECT A.sname AS Student1, B.sname AS Student2, A.age
FROM Students A, Students B
WHERE A.sid < B.sid AND A.age = B.age;
```

## 5. Normalization (Overview)

Normalization is the process of organizing data to reduce redundancy and improve integrity.

```sql
-- Unnormalized table: student with multiple phone numbers in one column
CREATE TABLE UnnormalizedStudent (
  sid INT,
  sname VARCHAR(20),
  phones VARCHAR(50)  -- e.g., "123-4567, 987-6543"
);

-- 1NF: Atomic values, no repeating groups
CREATE TABLE Student1NF (
  sid INT,
  sname VARCHAR(20),
  phone VARCHAR(20)  -- Each row has one phone number
);

-- 2NF: No partial dependencies on composite key
-- If primary key is (sid, cid), then grade depends on both
CREATE TABLE Enrollment2NF (
  sid INT,
  cid INT,
  grade VARCHAR(2),
  sname VARCHAR(20),  -- depends only on sid, violates 2NF
  PRIMARY KEY (sid, cid)
);

-- Fixed 2NF: Move sname to separate Students table
CREATE TABLE Students2NF (
  sid INT PRIMARY KEY,
  sname VARCHAR(20)
);

CREATE TABLE Enrollments2NF (
  sid INT,
  cid INT,
  grade VARCHAR(2),
  PRIMARY KEY (sid, cid),
  FOREIGN KEY (sid) REFERENCES Students2NF(sid)
);

-- 3NF: No transitive dependencies
-- If dept_name depends on sid through sname, it violates 3NF
CREATE TABLE Students3NF (
  sid INT PRIMARY KEY,
  sname VARCHAR(20),
  dept_name VARCHAR(30)  -- depends on sid through sname? Actually depends directly on sid in proper design
);

-- Proper 3NF: Separate department into its own table
CREATE TABLE Departments3NF (
  dept_id INT PRIMARY KEY,
  dept_name VARCHAR(30)
);

CREATE TABLE Students3NF (
  sid INT PRIMARY KEY,
  sname VARCHAR(20),
  dept_id INT,
  FOREIGN KEY (dept_id) REFERENCES Departments3NF(dept_id)
);
```

### 1NF (First Normal Form)

Each column contains atomic (indivisible) values, and each row is unique.

Example: A column should not store multiple phone numbers separated by commas.

### 2NF (Second Normal Form)

Meets 1NF, and all non-key columns are fully functionally dependent on the primary key (no partial dependencies).

Example: If the primary key is a composite of (sid, cid), then columns like `grade` depend on both, not just one.

### 3NF (Third Normal Form)

Meets 2NF, and no non-key column is transitively dependent on the primary key.

Example: In a table with `sid`, `sname`, and `dept_name`, if `dept_name` depends on `sid` through `sname`, it violates 3NF.

## 6. Relational Algebra

Relational algebra is a theoretical foundation for SQL. It uses operators to query relational databases.

```sql
-- Selection: WHERE clause filters rows
SELECT * FROM Products WHERE category = 'Gadgets';

-- Projection: SELECT specific columns
SELECT pname, price FROM Products;

-- Union: Combine results from two queries (same columns)
SELECT pname FROM Products
UNION
SELECT pname FROM DiscontinuedProducts;

-- Set Difference: Rows in first query but not in second
SELECT pname FROM Products
EXCEPT
SELECT pname FROM DiscontinuedProducts;

-- Cartesian Product: Every row combined with every row
-- (Usually achieved through JOIN without ON condition, though rare in practice)
SELECT Students.sname, Courses.cname
FROM Students, Courses;

-- Rename: AS clause renames columns or tables
SELECT pname AS product_name, price AS product_price FROM Products;
```

- **Selection (sigma)**: Filters rows based on a condition.
  Example: `sigma_{category='Gadgets'}(Products)`

- **Projection (pi)**: Selects specific columns.
  Example: `pi_{pname, price}(Products)`

- **Union (U)**: Combines rows from two tables with the same columns, removing duplicates.
  Example: `pi_{pname}(Products) U pi_{pname}(DiscontinuedProducts)`

- **Set Difference (-)**: Returns rows in the first table but not in the second.
  Example: `pi_{pname}(Products) - pi_{pname}(DiscontinuedProducts)`

- **Cartesian Product (x)**: Combines every row of the first table with every row of the second.
  Example: `Students x Courses` (every student paired with every course)

- **Rename (rho)**: Renames a table or column.
  Example: `rho_{S}(Students)` renames Students to S

---

# Day 2 SQL Script Analysis

The Day 2 SQL script builds on Day 1 by introducing constraints, relationships, and advanced querying. Below is a detailed breakdown.

## 1. Database Setup

```sql
Create Database lab_6020;

USE lab_6020;
```

**Explanation:**

- Creates and selects the database `lab_6020` for all subsequent operations.
- `USE lab_6020;` tells the DBMS to operate within this database.

## 2. Creating Tables with Constraints

```sql
Create table Students(
  sid int PRIMARY KEY,
  sname varchar(20) NOT NULL,
  age int CHECK (age >= 5),
  email varchar(30) UNIQUE
);

Create table Courses(
  cid int PRIMARY KEY,
  cname varchar(30) NOT NULL,
  credits int DEFAULT 3
);

Create table Enrollments(
  sid int,
  cid int,
  grade varchar(2),
  PRIMARY KEY (sid, cid),
  FOREIGN KEY (sid) REFERENCES Students(sid),
  FOREIGN KEY (cid) REFERENCES Courses(cid)
);

Create table Products(
  pid int PRIMARY KEY,
  pname varchar(20),
  price decimal(5,2),
  category varchar(20),
  manufacturer varchar(40)
);
```

**Explanation:**

- `Students` table:
  - `sid` is the primary key (unique, not NULL).
  - `sname` cannot be NULL.
  - `age` must be >= 5.
  - `email` must be unique across all students.

- `Courses` table:
  - `cid` is the primary key.
  - `cname` cannot be NULL.
  - `credits` defaults to 3 if not specified.

- `Enrollments` table:
  - Composite primary key of (`sid`, `cid`) ensures a student cannot enroll in the same course twice.
  - Foreign keys link to `Students` and `Courses`, ensuring referential integrity.

- `Products` table:
  - `pid` is the primary key.
  - `price` is defined as DECIMAL(5,2) to store prices up to 999.99.
  - This table is used for DISTINCT and aggregation examples later in the script.

## 3. Inserting Sample Data

```sql
INSERT INTO Students VALUES (1, 'Alice', 20, 'alice@mail.com');
INSERT INTO Courses VALUES (101, 'Databases', 4);
INSERT INTO Enrollments VALUES (1, 101, 'A');
INSERT INTO Products VALUES (1, 'Gizmo', 19.99, 'Gadgets', 'GizmoWorks');
...
```

**Explanation:**

- Inserts sample rows into each table.
- Note that `INSERT INTO Enrollments` must use valid `sid` and `cid` values that exist in `Students` and `Courses`, or the insert will fail due to foreign key constraints.
- The `Products` table includes sample data for DISTINCT and aggregation demonstrations.

## 4. DISTINCT

`DISTINCT` removes duplicate rows from the result set.

**Syntax:**

```sql
SELECT DISTINCT column1 FROM table_name;
```

**Example:**

```sql
SELECT DISTINCT category FROM Products;
```

This returns only unique category values.

With multiple columns:

```sql
SELECT DISTINCT category, manufacturer FROM Products;
```

This returns unique pairs of category and manufacturer.

Common use case: Counting unique values.

```sql
SELECT COUNT(DISTINCT category) AS UniqueCategories FROM Products;
```

**Note:** `DISTINCT` applies to all selected columns. If you select multiple columns, the combination must be unique for a row to appear.

## 5. ORDER BY

```sql
SELECT sname, age FROM Students ORDER BY age DESC;
```

**Explanation:**

- Retrieves student names and ages, sorted from highest age to lowest.
- `ORDER BY` can use multiple columns: `ORDER BY age DESC, sname ASC;`

## 6. Aggregate Functions

```sql
SELECT COUNT(*) AS TotalStudents FROM Students;
SELECT AVG(age) AS AvgAge FROM Students;
SELECT MAX(age) AS Oldest FROM Students;
```

**Explanation:**

- `COUNT(*)` counts all rows.
- `AVG(age)` computes the average age.
- `MAX(age)` finds the oldest student's age.
- These functions ignore NULL values (except COUNT(*)).

## 7. GROUP BY with Aggregation

```sql
SELECT c.cname, COUNT(e.sid) AS Enrolled
FROM Courses c
JOIN Enrollments e ON c.cid = e.cid
GROUP BY c.cname;
```

**Explanation:**

- Groups rows by `cname` and counts how many students are enrolled in each course.
- `GROUP BY` requires that all selected columns are either aggregated or included in the `GROUP BY` clause.

## 8. JOINs

```sql
-- INNER JOIN
SELECT s.sname, c.cname, e.grade
FROM Students s
JOIN Enrollments e ON s.sid = e.sid
JOIN Courses c ON e.cid = c.cid;

-- LEFT JOIN
SELECT s.sname, c.cname
FROM Students s
LEFT JOIN Enrollments e ON s.sid = e.sid
LEFT JOIN Courses c ON e.cid = c.cid;
```

**Explanation:**

- **INNER JOIN**: Returns only students who are enrolled in courses.
- **LEFT JOIN**: Returns all students, even those with no enrollments (course name will be NULL).

## 9. Constraint Failure Examples

```sql
INSERT INTO Students VALUES (1, 'Dave', 21, 'dave@mail.com');
-- didnt work? why?
-- because sid 1 already exists (Primary Key constraint)

INSERT INTO Students VALUES (4, 'Eve', 3, 'eve@mail.com');
-- didnt work? why?
-- because age must be >= 5 (CHECK constraint)
```

**Explanation:**

- Duplicate primary key insert fails because `sid = 1` already exists.
- Invalid `CHECK` constraint fails because `age = 3` violates `age >= 5`.
- These examples demonstrate how constraints protect data integrity.

## 10. Subquery Example

```sql
SELECT sname FROM Students 
WHERE sid IN (SELECT sid FROM Enrollments WHERE cid = 101);
```

**Explanation:**

- The inner query finds all `sid` values enrolled in course 101.
- The outer query returns the names of those students.
- Subqueries can be used in `WHERE`, `FROM`, or `SELECT` clauses.

## 11. DISTINCT Examples

```sql
SELECT DISTINCT sname FROM Students;
SELECT DISTINCT cname FROM Courses;
SELECT COUNT(DISTINCT cname) AS UniqueCourses FROM Enrollments
JOIN Courses ON Enrollments.cid = Courses.cid;
```

**Explanation:**

- `SELECT DISTINCT sname` returns each student name only once, even if duplicates existed.
- `SELECT DISTINCT cname` returns unique course names.
- `COUNT(DISTINCT cname)` counts how many different courses students are enrolled in, eliminating duplicates from the join.

## 12. Aggregate Functions Examples

```sql
SELECT COUNT(*) AS TotalStudents FROM Students;
SELECT COUNT(DISTINCT sname) AS UniqueStudentNames FROM Students;
SELECT AVG(age) AS AvgAge FROM Students;
SELECT SUM(credits) AS TotalCredits FROM Courses;
SELECT MIN(age) AS Youngest, MAX(age) AS Oldest FROM Students;
```

**Explanation:**

- `COUNT(*)` counts all rows in the `Students` table.
- `COUNT(DISTINCT sname)` counts unique student names (demonstrates DISTINCT inside an aggregate).
- `AVG(age)` computes the average age of all students.
- `SUM(credits)` totals all course credits.
- `MIN(age)` and `MAX(age)` return the youngest and oldest ages in a single query.

## 13. GROUP BY with Aggregation Examples

```sql
SELECT c.cname, COUNT(e.sid) AS Enrolled
FROM Courses c
JOIN Enrollments e ON c.cid = e.cid
GROUP BY c.cname;

SELECT category,
       COUNT(*) AS ProductCount,
       AVG(price) AS AvgPrice
FROM Products
GROUP BY category
HAVING COUNT(*) > 1;
```

**Explanation:**

- The first query groups enrollments by course name and counts students per course.
- The second query demonstrates multiple aggregates (`COUNT` and `AVG`) grouped by `category`.
- The `HAVING` clause filters to show only categories with more than one product.
- This illustrates how `GROUP BY` creates groups and aggregates calculate statistics per group.

---

# Day 2 Deep Dive: DISTINCT, Aggregation, JOIN Operations, INTERSECT, ORDER BY, and HAVING

## 1. DISTINCT

`DISTINCT` eliminates duplicate rows from query results.

**Basic Usage:**

```sql
SELECT DISTINCT category FROM Products;
-- Returns: Gadgets, Photography, Cellphone (no duplicates)
```

**Multiple Columns:**

```sql
SELECT DISTINCT category, manufacturer FROM Products;
-- Returns unique combinations of category and manufacturer
```

**With Aggregate Functions:**

```sql
SELECT COUNT(DISTINCT category) AS UniqueCategories FROM Products;
-- Counts how many different categories exist
```

**Important Notes:**

- DISTINCT applies to all columns in the SELECT list.
- DISTINCT cannot be used with certain aggregate functions like COUNT(*), but COUNT(DISTINCT column) is valid.
- Using DISTINCT on large datasets can impact performance because the DBMS must sort or hash the results.

**Practical Example:**

```sql
-- Find all unique categories that have products priced over 100
SELECT DISTINCT category
FROM Products
WHERE price > 100;
```

## 2. Aggregation and Aggregate Functions

Aggregation performs calculations on multiple rows and returns a single summary value.

### Common Aggregate Functions

**COUNT:**

- `COUNT(*)`: Counts all rows, including NULLs.
  Example: `SELECT COUNT(*) AS TotalProducts FROM Products;`
- `COUNT(column)`: Counts non-NULL values only.
  Example: `SELECT COUNT(price) AS ProductsWithPrice FROM Products;`
- `COUNT(DISTINCT column)`: Counts unique non-NULL values.
  Example: `SELECT COUNT(DISTINCT category) AS UniqueCategories FROM Products;`

**SUM:**

Adds all values in a column.

Example: `SELECT SUM(credits) AS TotalCredits FROM Courses;`

**AVG:**

Calculates the average of numeric values. NULLs are ignored.

Example: `SELECT AVG(age) AS AverageAge FROM Students;`

**MIN / MAX:**

Returns the smallest/largest value.

Example: `SELECT MIN(price) AS Cheapest, MAX(price) AS MostExpensive FROM Products;`

### Rules for Aggregation

1. When using aggregate functions without GROUP BY, the entire table is treated as one group.
2. When using GROUP BY, aggregates are calculated per group.
3. You cannot mix aggregated and non-aggregated columns in SELECT without GROUP BY.
   - Bad: `SELECT sname, AVG(age) FROM Students;`
   - Good: `SELECT sname, AVG(age) FROM Students GROUP BY sname;`
4. Aggregate functions ignore NULL values (except COUNT(*)).
   Example: If a student has NULL for age, AVG(age) will not include that row.

**Example with GROUP BY and Aggregation:**

```sql
SELECT category,
       COUNT(*) AS ProductCount,
       AVG(price) AS AvgPrice,
       MIN(price) AS MinPrice,
       MAX(price) AS MaxPrice
FROM Products
GROUP BY category;
```

This returns one row per category with aggregated statistics.

## 3. JOIN Operations (Detailed)

SQL supports several types of JOINs. Understanding the differences is critical.

### INNER JOIN

Returns only matching rows from both tables.

Example:

```sql
SELECT s.sname, c.cname, e.grade
FROM Students s
INNER JOIN Enrollments e ON s.sid = e.sid
INNER JOIN Courses c ON e.cid = c.cid;
```

**Result:** Only students who are enrolled in at least one course.

### LEFT JOIN (LEFT OUTER JOIN)

Returns all rows from the left table and matched rows from the right table. Unmatched right-table columns are NULL.

Example:

```sql
SELECT s.sname, c.cname
FROM Students s
LEFT JOIN Enrollments e ON s.sid = e.sid
LEFT JOIN Courses c ON e.cid = c.cid;
```

**Result:** All students appear. If a student has no enrollments, `c.cname` is NULL.

### RIGHT JOIN (RIGHT OUTER JOIN)

Returns all rows from the right table and matched rows from the left table. Unmatched left-table columns are NULL.

Example:

```sql
SELECT s.sname, c.cname
FROM Students s
RIGHT JOIN Enrollments e ON s.sid = e.sid
RIGHT JOIN Courses c ON e.cid = c.cid;
```

**Result:** All courses appear. If a course has no students, `s.sname` is NULL.

### FULL JOIN (FULL OUTER JOIN)

Returns all rows when there is a match in either table. MySQL does not support FULL JOIN directly.

**Workaround:**

```sql
SELECT s.sname, c.cname
FROM Students s
LEFT JOIN Enrollments e ON s.sid = e.sid
LEFT JOIN Courses c ON e.cid = c.cid
UNION
SELECT s.sname, c.cname
FROM Students s
RIGHT JOIN Enrollments e ON s.sid = e.sid
RIGHT JOIN Courses c ON e.cid = c.cid;
```

### Self Join

A table is joined to itself.

Example:

```sql
SELECT A.sname AS Student1, B.sname AS Student2, A.age
FROM Students A
JOIN Students B ON A.sid < B.sid AND A.age = B.age;
```

This finds pairs of students with the same age.

## 4. INTERSECT

`INTERSECT` returns distinct rows that appear in both result sets.

**Syntax:**

```sql
SELECT column1 FROM table1
INTERSECT
SELECT column1 FROM table2;
```

**Example using Day 2 data:**

```sql
SELECT cname FROM Courses WHERE credits > 3
INTERSECT
SELECT cname FROM Courses WHERE cid > 101;
```

**Note:** MySQL does not support `INTERSECT` directly. Use `INNER JOIN` or `WHERE ... IN`:

```sql
SELECT cname FROM Courses WHERE credits > 3 AND cname IN (
  SELECT cname FROM Courses WHERE cid > 101
);
```

## 5. ORDER BY (Detailed)

`ORDER BY` sorts the result set by one or more columns.

### Sorting Direction

- `ASC`: Ascending order (default).
- `DESC`: Descending order.

### Multiple Columns

You can sort by multiple columns.

Example:

```sql
SELECT sname, age, email FROM Students ORDER BY age DESC, sname ASC;
```

This sorts by age (oldest first), then by name (A-Z) for students with the same age.

### NULL Handling

In MySQL, `ORDER BY` places NULL values first in ascending order and last in descending order.

## 6. HAVING Clause

`HAVING` filters groups created by `GROUP BY`.

### Difference between WHERE and HAVING

- `WHERE` filters rows before grouping.
- `HAVING` filters groups after grouping.

**Example from Day 2.sql concept:**

```sql
SELECT category, COUNT(*) AS product_count
FROM Products
GROUP BY category
HAVING COUNT(*) > 1;
```

This returns only categories with more than one product.

**Another example:**

```sql
SELECT c.cname, COUNT(e.sid) AS Enrolled
FROM Courses c
JOIN Enrollments e ON c.cid = e.cid
GROUP BY c.cname
HAVING COUNT(e.sid) > 1;
```

This returns courses with more than one student enrolled.

## 7. Practical Example Combining Concepts

```sql
-- Find students older than average, ordered by name
SELECT sname, age
FROM Students
WHERE age > (SELECT AVG(age) FROM Students)
ORDER BY sname ASC;

-- Find courses with more than 2 enrolled students
SELECT c.cname, COUNT(e.sid) AS Enrolled
FROM Courses c
JOIN Enrollments e ON c.cid = e.cid
GROUP BY c.cname
HAVING COUNT(e.sid) > 2;

-- Find students enrolled in both Databases and Algorithms
SELECT s.sname
FROM Students s
JOIN Enrollments e ON s.sid = e.sid
JOIN Courses c ON e.cid = c.cid
WHERE c.cname IN ('Databases', 'Algorithms')
GROUP BY s.sid, s.sname
HAVING COUNT(DISTINCT c.cname) = 2;
```

These examples demonstrate how ORDER BY, GROUP BY, HAVING, and JOINs work together to answer complex questions.

---

## NULL Values in SQL

`NULL` represents missing, unknown, or inapplicable data. It is important to understand how NULL behaves in SQL because it affects comparisons, aggregates, and joins.

### What is NULL?

- `NULL` is not the same as `0`, `''` (empty string), or `FALSE`.
- It indicates the absence of a value.
- Any comparison with `NULL` using `=`, `<`, `>`, etc. returns `NULL` (unknown), not `TRUE` or `FALSE`.

### Testing for NULL

Use `IS NULL` and `IS NOT NULL` to test for NULL values.

```sql
-- Find students with NULL email
SELECT sname, email
FROM Students
WHERE email IS NULL;

-- Find students with non-NULL email
SELECT sname, email
FROM Students
WHERE email IS NOT NULL;
```

### NULL in Aggregates

Aggregate functions behave differently with NULL:

- `COUNT(*)` counts all rows, including those with NULL values.
- `COUNT(column)` counts only non-NULL values.
- `SUM`, `AVG`, `MIN`, `MAX` ignore NULL values.

```sql
-- Example: Students table with some NULL ages
INSERT INTO Students VALUES (4, 'Dave', NULL, 'dave@mail.com');
INSERT INTO Students VALUES (5, 'Eve', 25, 'eve@mail.com');

-- COUNT(*) counts all students
SELECT COUNT(*) AS TotalStudents FROM Students;

-- COUNT(age) counts only students with non-NULL age
SELECT COUNT(age) AS StudentsWithAge FROM Students;

-- AVG(age) ignores NULL ages
SELECT AVG(age) AS AvgAge FROM Students;
```

### Handling NULLs with COALESCE and IFNULL

Use `COALESCE` or `IFNULL` to replace NULL with a default value.

```sql
-- Replace NULL age with 0
SELECT sname, COALESCE(age, 0) AS age
FROM Students;

-- MySQL-specific: IFNULL
SELECT sname, IFNULL(age, 0) AS age
FROM Students;
```

### NULL in Joins

NULL values do not match each other in JOINs.

```sql
-- Students with NULL email will not match other NULL emails in a join
-- This is important when using JOINs with nullable columns
```

### NULLIF Function

`NULLIF` returns NULL if two expressions are equal; otherwise, it returns the first expression.

```sql
-- Example: Convert empty string to NULL
SELECT NULLIF('', ' ') AS result;  -- Returns NULL if string is empty
```

### Practical NULL Examples

```sql
-- Find students who have not enrolled in any course (NULL in Enrollments)
SELECT s.sname
FROM Students s
LEFT JOIN Enrollments e ON s.sid = e.sid
WHERE e.sid IS NULL;

-- Find products with NULL price
SELECT pname, price
FROM Products
WHERE price IS NULL;

-- Replace NULL prices with average price
SELECT pname, COALESCE(price, (SELECT AVG(price) FROM Products)) AS price
FROM Products;
```

### Important NULL Rules

1. `NULL = NULL` is `NULL` (unknown), not `TRUE`. Use `IS NULL` instead.
2. `NULL != NULL` is also `NULL`.
3. `NULL` in arithmetic expressions results in `NULL`.
4. `NULL` in string concatenation results in `NULL`.
5. Aggregate functions ignore `NULL` values (except `COUNT(*)`).

---

# Day 2 SQL Script Analysis: NULL Handling and Advanced Examples

## NULL Values in SQL

`NULL` represents missing, unknown, or inapplicable data. It is important to understand how NULL behaves in SQL because it affects comparisons, aggregates, and joins.

### What is NULL?

- `NULL` is not the same as `0`, `''` (empty string), or `FALSE`.
- It indicates the absence of a value.
- Any comparison with `NULL` using `=`, `<`, `>`, etc. returns `NULL` (unknown), not `TRUE` or `FALSE`.

### Testing for NULL

Use `IS NULL` and `IS NOT NULL` to test for NULL values.

```sql
-- Find students with NULL email
SELECT sname, email
FROM Students
WHERE email IS NULL;

-- Find students with non-NULL email
SELECT sname, email
FROM Students
WHERE email IS NOT NULL;
```

### NULL in Aggregates

Aggregate functions behave differently with NULL:

- `COUNT(*)` counts all rows, including those with NULL values.
- `COUNT(column)` counts only non-NULL values.
- `SUM`, `AVG`, `MIN`, `MAX` ignore NULL values.

```sql
-- Example: Students table with some NULL ages
INSERT INTO Students VALUES (4, 'Dave', NULL, 'dave@mail.com');
INSERT INTO Students VALUES (5, 'Eve', 25, 'eve@mail.com');

-- COUNT(*) counts all students
SELECT COUNT(*) AS TotalStudents FROM Students;

-- COUNT(age) counts only students with non-NULL age
SELECT COUNT(age) AS StudentsWithAge FROM Students;

-- AVG(age) ignores NULL ages
SELECT AVG(age) AS AvgAge FROM Students;
```

### Handling NULLs with COALESCE and IFNULL

Use `COALESCE` or `IFNULL` to replace NULL with a default value.

```sql
-- Replace NULL age with 0
SELECT sname, COALESCE(age, 0) AS age
FROM Students;

-- MySQL-specific: IFNULL
SELECT sname, IFNULL(age, 0) AS age
FROM Students;
```

### NULL in Joins

NULL values do not match each other in JOINs.

```sql
-- Students with NULL email will not match other NULL emails in a join
-- This is important when using JOINs with nullable columns
```

### NULLIF Function

`NULLIF` returns NULL if two expressions are equal; otherwise, it returns the first expression.

```sql
-- Example: Convert empty string to NULL
SELECT NULLIF('', ' ') AS result;  -- Returns NULL if string is empty
```

### Practical NULL Examples

```sql
-- Find students who have not enrolled in any course (NULL in Enrollments)
SELECT s.sname
FROM Students s
LEFT JOIN Enrollments e ON s.sid = e.sid
WHERE e.sid IS NULL;

-- Find products with NULL price
SELECT pname, price
FROM Products
WHERE price IS NULL;

-- Replace NULL prices with average price
SELECT pname, COALESCE(price, (SELECT AVG(price) FROM Products)) AS price
FROM Products;
```

### Important NULL Rules

1. `NULL = NULL` is `NULL` (unknown), not `TRUE`. Use `IS NULL` instead.
2. `NULL != NULL` is also `NULL`.
3. `NULL` in arithmetic expressions results in `NULL`.
4. `NULL` in string concatenation results in `NULL`.
5. Aggregate functions ignore `NULL` values (except `COUNT(*)`).


--Class 2--
-- Keys, Constraints, and Advanced SELECT

Create Database lab_6020;

USE lab_6020;

-- Creating tables with constraints

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

--Next--

INSERT INTO Students VALUES (1, 'Alice', 20, 'alice@mail.com');
INSERT INTO Students VALUES (2, 'Bob', 22, 'bob@mail.com');
INSERT INTO Students VALUES (3, 'Charlie', 19, 'charlie@mail.com');

INSERT INTO Courses VALUES (101, 'Databases', 4);
INSERT INTO Courses VALUES (102, 'Algorithms', 3);
INSERT INTO Courses VALUES (103, 'Networks', 3);

INSERT INTO Enrollments VALUES (1, 101, 'A');
INSERT INTO Enrollments VALUES (1, 102, 'B');
INSERT INTO Enrollments VALUES (2, 101, 'A');
INSERT INTO Enrollments VALUES (2, 103, 'C');
INSERT INTO Enrollments VALUES (3, 102, 'B');

INSERT INTO Products VALUES (1, 'Gizmo', 19.99, 'Gadgets', 'GizmoWorks');
INSERT INTO Products VALUES (2, 'Powergizmo', 29.99, 'Gadgets', 'GizmoWorks');
INSERT INTO Products VALUES (3, 'SingleTouch', 149.99, 'Photography', 'Canon');
INSERT INTO Products VALUES (4, 'MultiTouch', 203.99, 'Household', 'Hitachi');
INSERT INTO Products VALUES (5, 'IPhone 13', 299.99, 'Cellphone', 'Apple');
INSERT INTO Products VALUES (6, 'IPhone 17 Pro', 1299.99, 'Cellphone', 'Apple');

--Next--

-- SELECT with ORDER BY
SELECT sname, age FROM Students ORDER BY age DESC;

--Next--

-- DISTINCT Examples
SELECT DISTINCT sname FROM Students;
SELECT DISTINCT cname FROM Courses;
SELECT COUNT(DISTINCT cname) AS UniqueCourses FROM Enrollments
JOIN Courses ON Enrollments.cid = Courses.cid;

--Next--

-- Aggregate Functions with Examples
SELECT COUNT(*) AS TotalStudents FROM Students;
SELECT COUNT(DISTINCT sname) AS UniqueStudentNames FROM Students;
SELECT AVG(age) AS AvgAge FROM Students;
SELECT SUM(credits) AS TotalCredits FROM Courses;
SELECT MIN(age) AS Youngest, MAX(age) AS Oldest FROM Students;

--Next--

-- GROUP BY with Aggregation
SELECT c.cname, COUNT(e.sid) AS Enrolled
FROM Courses c
JOIN Enrollments e ON c.cid = e.cid
GROUP BY c.cname;

-- GROUP BY with multiple aggregates
SELECT category, 
       COUNT(*) AS ProductCount, 
       AVG(price) AS AvgPrice
FROM Products
GROUP BY category;

-- HAVING example (filtering groups)
SELECT c.cname, COUNT(e.sid) AS Enrolled
FROM Courses c
JOIN Enrollments e ON c.cid = e.cid
GROUP BY c.cname
HAVING COUNT(e.sid) > 1;

-- HAVING with Products table
SELECT category, COUNT(*) AS ProductCount, AVG(price) AS AvgPrice
FROM Products
GROUP BY category
HAVING COUNT(*) > 1;

--Next--

-- JOINs
SELECT s.sname, c.cname, e.grade
FROM Students s
JOIN Enrollments e ON s.sid = e.sid
JOIN Courses c ON e.cid = c.cid;

-- LEFT JOIN example
SELECT s.sname, c.cname
FROM Students s
LEFT JOIN Enrollments e ON s.sid = e.sid
LEFT JOIN Courses c ON e.cid = c.cid;

-- RIGHT JOIN example
-- Shows all courses, even those with no students enrolled
SELECT s.sname, c.cname
FROM Students s
RIGHT JOIN Enrollments e ON s.sid = e.sid
RIGHT JOIN Courses c ON e.cid = c.cid;

-- FULL JOIN workaround (MySQL does not support FULL JOIN directly)
-- Shows all students AND all courses, with NULLs where no match exists
SELECT s.sname, c.cname
FROM Students s
LEFT JOIN Enrollments e ON s.sid = e.sid
LEFT JOIN Courses c ON e.cid = c.cid
UNION
SELECT s.sname, c.cname
FROM Students s
RIGHT JOIN Enrollments e ON s.sid = e.sid
RIGHT JOIN Courses c ON e.cid = c.cid;

-- Self Join example
-- Find pairs of students with the same age
SELECT A.sname AS Student1, B.sname AS Student2, A.age
FROM Students A
JOIN Students B ON A.sid < B.sid AND A.age = B.age;

-- INTERSECT workaround (MySQL does not support INTERSECT directly)
-- Find course names that are both in Databases/Algorithms AND have credits > 3
SELECT DISTINCT c1.cname
FROM Courses c1
INNER JOIN Courses c2 ON c1.cname = c2.cname
WHERE c1.cname IN ('Databases', 'Algorithms') AND c2.credits > 3;

--Next--

-- What if we try to insert a duplicate primary key?
INSERT INTO Students VALUES (1, 'Dave', 21, 'dave@mail.com');
-- didnt work? why? 
-- because sid 1 already exists (Primary Key constraint)

--Next--

-- What if we try to insert a bad age?
INSERT INTO Students VALUES (4, 'Eve', 3, 'eve@mail.com');
-- didnt work? why?
-- because age must be >= 5 (CHECK constraint)

--Next--

-- Subquery example
SELECT sname FROM Students 
WHERE sid IN (SELECT sid FROM Enrollments WHERE cid = 101);

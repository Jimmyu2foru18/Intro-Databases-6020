-- James McGuigan Homework Assignment 1

-- Problem 1
-- Student–Course Schema

CREATE DATABASE Homework_1_CS6020;
USE Homework_1_CS6020;

--create tables

CREATE TABLE Student 
(
	sid INT PRIMARY KEY,
	fname VARCHAR(50) NOT NULL,
	lname VARCHAR(50) NOT NULL,
	gpa DECIMAL(3,2)
);

CREATE TABLE Course 
(
	cid INT PRIMARY KEY,
	code VARCHAR(10) NOT NULL,
	name VARCHAR(100) NOT NULL,
	credithours INT NOT NULL
);

CREATE TABLE Enrolled 
(
	sid INT,
	cid INT,
	grade CHAR(2),

	PRIMARY KEY (sid, cid),
	FOREIGN KEY (sid) REFERENCES Student(sid),
	FOREIGN KEY (cid) REFERENCES Course(cid)
);

--Next Insert Values for each 

INSERT INTO Student (sid, fname, lname, gpa) VALUES
(1, 'Shamikh', 'Ahsan', 3.80),
(2, 'Nitesh kumar', 'Chahar', 3.70),
(3, 'Cathy', 'Jimenez', 3.50),
(4, 'Ayesha', 'Laraib', 3.90),
(5, 'James', 'McGuigan', 3.70),
(6, 'Muhammad Noman', 'Nazir', 3.40),
(7, 'Fatima', 'Saleem', 3.80);

INSERT INTO Course VALUES
(101, 'CS2510', 'Computer Programming I', 3),
(102, 'CS2511', 'Computer Programming II', 3),
(103, 'CS3810', 'Data Structures & Algorithms', 3),
(104, 'CS4501', 'Software Engineering', 3),
(105, 'CS4100', 'Technical Communications', 3),
(106, 'CS4550', 'Database Management Systems', 3),
(107, 'CS4510', 'Internet & Web Technologies', 3),
(108, 'CS5710', 'Computer Network', 3),
(109, 'CS5910', 'Systems Design & Implementation', 3),
(110, 'MA2310', 'Calculus & Analytical Geometry I', 4),
(111, 'MA2320', 'Calculus & Analytical Geometry II', 4),
(112, 'MA3030', 'Discrete Mathematics', 4),
(113, 'MA3160', 'Linear Algebra', 4),
(114, 'MA3210', 'Intro to Prob & Statistics', 4),
(115, 'MA3250', 'Business Analytics', 4),
(116, 'MA3330', 'Calculus & Analytical Geometry III', 4);

INSERT INTO Enrolled (sid, cid, grade) VALUES
(1, 101, 'A'),
(1, 102, 'B'),
(1, 103, 'A'),
(1, 104, 'B'),
(1, 105, 'A'),
(1, 106, 'A'),
(1, 107, 'B'),
(1, 108, 'A'),
(1, 109, 'B'),
(1, 110, 'A'),
(1, 111, 'B'),
(1, 112, 'A'),
(1, 113, 'B'),
(1, 114, 'A'),
(1, 115, 'A'),
(1, 116, 'B'),
(2, 101, 'B'),
(2, 102, 'A'),
(2, 103, 'B'),
(2, 104, 'C'),
(2, 105, 'B'),
(2, 106, 'B'),
(2, 107, 'A'),
(2, 108, 'B'),
(2, 109, 'C'),
(2, 110, 'B'),
(2, 111, 'A'),
(2, 112, 'B'),
(2, 113, 'C'),
(2, 114, 'B'),
(2, 115, 'A'),
(2, 116, 'B'),
(3, 101, 'A'),
(3, 102, 'A'),
(3, 103, 'A'),
(3, 104, 'B'),
(3, 105, 'A'),
(3, 106, 'B'),
(3, 107, 'A'),
(3, 108, 'B'),
(3, 109, 'A'),
(3, 110, 'B'),
(3, 111, 'A'),
(3, 112, 'A'),
(3, 113, 'B'),
(3, 114, 'A'),
(3, 115, 'B'),
(3, 116, 'A'),
(4, 101, 'A'),
(4, 102, 'A'),
(4, 103, 'B'),
(4, 104, 'A'),
(4, 105, 'A'),
(4, 106, 'A'),
(4, 107, 'B'),
(4, 108, 'A'),
(4, 109, 'A'),
(4, 110, 'A'),
(4, 111, 'B'),
(4, 112, 'A'),
(4, 113, 'A'),
(4, 114, 'B'),
(4, 115, 'A'),
(4, 116, 'A'),
(5, 101, 'B'),
(5, 102, 'A'),
(5, 103, 'B'),
(5, 104, 'A'),
(5, 105, 'A'),
(5, 106, 'A'),
(5, 107, 'B'),
(5, 108, 'A'),
(5, 109, 'B'),
(5, 110, 'B'),
(5, 111, 'A'),
(5, 112, 'B'),
(5, 113, 'A'),
(5, 114, 'B'),
(5, 115, 'A'),
(5, 116, 'B'),
(6, 101, 'B'),
(6, 102, 'B'),
(6, 103, 'A'),
(6, 104, 'C'),
(6, 105, 'B'),
(6, 106, 'A'),
(6, 107, 'B'),
(6, 108, 'A'),
(6, 109, 'B'),
(6, 110, 'C'),
(6, 111, 'B'),
(6, 112, 'A'),
(6, 113, 'B'),
(6, 114, 'A'),
(6, 115, 'B'),
(6, 116, 'A'),
(7, 101, 'A'),
(7, 102, 'B'),
(7, 103, 'A'),
(7, 104, 'B'),
(7, 105, 'A'),
(7, 106, 'B'),
(7, 107, 'A'),
(7, 108, 'B'),
(7, 109, 'A'),
(7, 110, 'A'),
(7, 111, 'B'),
(7, 112, 'A'),
(7, 113, 'B'),
(7, 114, 'A'),
(7, 115, 'A'),
(7, 116, 'B');

-- Now Queries

-- Print all students’ names ordered descending by GPA

SELECT fname, lname, gpa
FROM Student
ORDER BY gpa DESC;

-- Print all Computer Science courses, where course codes start with 'CS', sorted alphabetically

SELECT *
FROM Course
WHERE code LIKE 'CS%'
ORDER BY code ASC;

-- Print all students with a GPA less than 3.0.

SELECT *
FROM Student
WHERE gpa < 3.0;

-- Print all students with a GPA of at least 3.0.

SELECT *
FROM Student
WHERE gpa >= 3.0;

-- Find all students who have enrolled in the Database course.

SELECT *
FROM Course
WHERE name LIKE '%Database%';

-- Find all students who have received an A (or higher) at least once.

SELECT DISTINCT s.fname, s.lname
FROM Student s
JOIN Enrolled e ON s.sid = e.sid
WHERE e.grade >= 'A';

-- Would the above schema support retaking the same course? Explain briefly.

-- No the schema dosnt have a time to compare to or a term so it dosnt prevent conflicts like 
-- retaking the same course we would need a additional column for when the student takes any of 
-- the courses for the comparison.

-- Problem 2

-- Employee–Project Schema 

CREATE DATABASE Company_6020;
USE Company_6020;

CREATE TABLE Employee 
(
	eid INT PRIMARY KEY,
	fname VARCHAR(50) NOT NULL,
	lname VARCHAR(50) NOT NULL,
	salary DECIMAL(10,2)
);

CREATE TABLE Project 
(
	pid INT PRIMARY KEY,
	code VARCHAR(10) NOT NULL,
	pname VARCHAR(100) NOT NULL,
	budget DECIMAL(12,2)
);

CREATE TABLE WorksOn 
(
	eid INT,
	pid INT,
	role VARCHAR(50),

	PRIMARY KEY (eid, pid),
	FOREIGN KEY (eid) REFERENCES Employee(eid),
	FOREIGN KEY (pid) REFERENCES Project(pid)
);

--Next Insert Values for each 

INSERT INTO Employee (eid, fname, lname, salary) VALUES
(1, 'Shamikh', 'Ahsan', 75000),
(2, 'Nitesh kumar', 'Chahar', 45000),
(3, 'Cathy', 'Jimenez', 60000),
(4, 'Ayesha', 'Laraib', 48000),
(5, 'James', 'McGuigan', 90000),
(6, 'Muhammad Noman', 'Nazir', 55000),
(7, 'Fatima', 'Saleem', 65000);

INSERT INTO Project (pid, code, pname, budget) VALUES
(101, 'IT101', 'Database', 100000),
(102, 'IT102', 'Network', 150000),
(103, 'IT103', 'Website', 75000),
(104, 'HR101', 'Recruitment', 50000);

INSERT INTO WorksOn (eid, pid, role) VALUES
(1, 101, 'Manager'),
(1, 102, 'Developer'),
(2, 101, 'Developer'),
(3, 101, 'Manager'),
(3, 102, 'Developer'),
(4, 102, 'Tester'),
(5, 102, 'Manager'),
(5, 103, 'Developer'),
(6, 101, 'Developer'),
(6, 104, 'Manager'),
(7, 102, 'Developer'),
(7, 103, 'Manager');

-- Print all employees’ names ordered descending by salary.

SELECT fname, lname, salary
FROM Employee
ORDER BY salary DESC;

-- Print all IT projects, where project codes start with 'IT', sorted alphabetically.

SELECT *
FROM Project
WHERE code LIKE 'IT%'
ORDER BY code ASC;

-- Print all employees who earn less than 50,000.

SELECT *
FROM Employee
WHERE salary < 50000;

-- Print all employees who earn at least 50,000

SELECT *
FROM Employee
WHERE salary >= 50000;

-- Find all employees working on the Database project.

SELECT e.fname, e.lname
FROM Employee e
JOIN WorksOn w ON e.eid = w.eid
JOIN Project p ON w.pid = p.pid
WHERE p.pname LIKE '%Database%';

-- Find all employees working on the Database and Network projects.

SELECT e.fname, e.lname
FROM Employee e
JOIN WorksOn w ON e.eid = w.eid
JOIN Project p ON w.pid = p.pid
WHERE p.pname LIKE '%Database%'
   OR p.pname LIKE '%Network%'
GROUP BY e.eid, e.fname, e.lname
HAVING COUNT(*) = 2;

-- Find all employees who have worked as a Manager at least once.

SELECT DISTINCT e.fname, e.lname
FROM Employee e
JOIN WorksOn w ON e.eid = w.eid
WHERE w.role = 'Manager';


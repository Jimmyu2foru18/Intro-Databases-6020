--Class 3--
-- LeetCode Problems: Friends Count, Department Highest Salary, 
-- Students & Examinations, Combine Two Tables, Stadium

-- ==================================================
-- Problem: Count Friends (from RequestAccepted table)
-- A person's friends = people they sent requests to
-- AND people who sent them requests (bidirectional)
-- ==================================================

-- --- Solution 1: LEFT JOIN + RIGHT JOIN + UNION ---
-- Splits counting into requester and accepter, then merges via UNION.

WITH t1 AS (
    SELECT requester_id, COUNT(*) AS c1
    FROM RequestAccepted
    WHERE requester_id != accepter_id
    GROUP BY requester_id
),
t2 AS (
    SELECT accepter_id, COUNT(*) AS c2
    FROM RequestAccepted
    WHERE requester_id != accepter_id
    GROUP BY accepter_id
),
t3 AS (
    SELECT
        t1.requester_id,
        COALESCE(t1.c1, 0) + COALESCE(t2.c2, 0) AS total_friends
    FROM t1
    LEFT JOIN t2 ON t1.requester_id = t2.accepter_id
    UNION
    SELECT
        t2.accepter_id,
        COALESCE(t1.c1, 0) + COALESCE(t2.c2, 0) AS total_friends
    FROM t1
    RIGHT JOIN t2 ON t1.requester_id = t2.accepter_id
)
SELECT requester_id AS id, total_friends AS num
FROM t3
WHERE total_friends = (SELECT MAX(total_friends) FROM t3);

-- --- Solution 2: UNION ALL to normalize bidirectional pairs (preferred) ---
-- "Rotates" accepter_id into a second column, then counts per person.

WITH t1 AS (
    SELECT requester_id AS id, accepter_id AS friend_id
    FROM RequestAccepted
    UNION ALL
    SELECT accepter_id AS id, requester_id AS friend_id
    FROM RequestAccepted
),
t2 AS (
    SELECT id, COUNT(*) AS c
    FROM t1
    GROUP BY id
)
SELECT id, c AS num
FROM t2
WHERE c = (SELECT MAX(c) FROM t2);

-- ==================================================
-- Problem 184: Department Highest Salary
-- Find the highest-paid employee(s) in each department.
-- ==================================================

-- --- Solution 1: Subquery in WHERE clause ---
SELECT d.name AS Department, e.name AS Employee, e.salary
FROM Employee e
JOIN Department d ON d.id = e.departmentId
WHERE e.salary = (
    SELECT MAX(e2.salary)
    FROM Employee e2
    WHERE e2.departmentId = e.departmentId
);

-- --- Solution 2: Subquery with GROUP BY for max salary per department ---
SELECT d.name AS Department, e.name AS Employee, e.salary
FROM Employee e
JOIN Department d ON d.id = e.departmentId
JOIN (
    SELECT departmentId, MAX(salary) AS max_sal
    FROM Employee
    GROUP BY departmentId
) AS d_max_salary
    ON d_max_salary.departmentId = e.departmentId
WHERE d_max_salary.max_sal = e.salary;

-- ==================================================
-- Problem 1280: Students and Examinations
-- Count how many times each student attended each exam.
-- ==================================================

-- --- Solution 1: CROSS JOIN + LEFT JOIN ---
SELECT
    st.student_id,
    st.student_name,
    sb.subject_name,
    IFNULL(exams.c, 0) AS attended_exams
FROM students st
CROSS JOIN subjects sb
LEFT JOIN (
    SELECT student_id, subject_name, COUNT(*) AS c
    FROM Examinations
    GROUP BY student_id, subject_name
) AS exams
    ON st.student_id = exams.student_id
    AND sb.subject_name = exams.subject_name
ORDER BY st.student_id, sb.subject_name;

-- --- Solution 2: Correlated subquery ---
SELECT
    st.student_id,
    st.student_name,
    sb.subject_name,
    (SELECT COUNT(*)
     FROM Examinations e
     WHERE e.student_id = st.student_id
       AND e.subject_name = sb.subject_name) AS attended_exams
FROM students st
CROSS JOIN subjects sb
ORDER BY st.student_id, sb.subject_name;

-- ==================================================
-- Problem 175: Combine Two Tables
-- Show name, city, and state for every person, even without an address.
-- ==================================================

SELECT
    p.firstName,
    p.lastName,
    a.city,
    a.state
FROM Person p
LEFT JOIN Address a ON p.personId = a.personId;

-- ==================================================
-- Problem 601: Human Traffic of Stadium
-- Find rows with 3+ consecutive ids where people > 100.
-- ==================================================

-- --- Solution 1: Self-join with UNION (original approach) ---
SELECT * FROM (
    SELECT s1.id, s1.visit_date, s1.people
    FROM Stadium s1, Stadium s2, Stadium s3
    WHERE s1.id = s2.id + 1
      AND s1.id = s3.id + 2
      AND s1.people > 100
      AND s2.people > 100
      AND s3.people > 100
    UNION
    SELECT s2.id, s2.visit_date, s2.people
    FROM Stadium s1, Stadium s2, Stadium s3
    WHERE s1.id = s2.id + 1
      AND s1.id = s3.id + 2
      AND s1.people > 100
      AND s2.people > 100
      AND s3.people > 100
    UNION
    SELECT s3.id, s3.visit_date, s3.people
    FROM Stadium s1, Stadium s2, Stadium s3
    WHERE s1.id = s2.id + 1
      AND s1.id = s3.id + 2
      AND s1.people > 100
      AND s2.people > 100
      AND s3.people > 100
) AS t
ORDER BY id;

-- --- Solution 2: Window functions (MySQL 8+) — gaps & islands ---
-- Groups consecutive rows (>100 people) into "islands" using
-- the difference of row numbers, then keeps islands of size >= 3.

WITH numbered AS (
    SELECT id, visit_date, people,
           ROW_NUMBER() OVER (ORDER BY id) AS full_rn
    FROM Stadium
),
islands AS (
    SELECT id, visit_date, people, full_rn,
           full_rn - ROW_NUMBER() OVER (ORDER BY full_rn) AS grp
    FROM numbered
    WHERE people > 100
)
SELECT id, visit_date, people
FROM islands
WHERE grp IN (
    SELECT grp
    FROM islands
    GROUP BY grp
    HAVING COUNT(*) >= 3
)
ORDER BY id;

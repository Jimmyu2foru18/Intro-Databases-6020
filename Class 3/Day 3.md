# Day 3: LeetCode SQL Problems - Advanced Queries

Today's class focused on solving LeetCode-style SQL problems, covering advanced techniques like CTEs, joins, subqueries, and window functions.

---

## Problem: Count Friends (from RequestAccepted table)

**Tables:** `RequestAccepted(requester_id, accepter_id)`

A person's total friends is the sum of:
- People they sent requests to (`requester_id` side)
- People who sent them requests (`accepter_id` side)

**Goal:** Find the person with the most friends and return their id and count.

### Solution 1: LEFT JOIN + RIGHT JOIN + UNION
Creates two CTEs:
- `t1` = count of outgoing requests per `requester_id`
- `t2` = count of incoming requests per `accepter_id`

Uses UNION of LEFT and RIGHT JOINs to simulate a FULL OUTER JOIN, summing both counts with `COALESCE` to handle NULLs.

```sql
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
```

### Solution 2: UNION ALL to normalize bidirectional pairs (preferred)
"Rotates" every request into two directed pairs:
- `(requester -> accepter)` and `(accepter -> requester)`

Then groups by id and counts. Cleaner and easier to understand.

```sql
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
```

### Key Takeaway:
- When a relationship is bidirectional, UNION the two directions into a single column, then aggregate.
- Use `COALESCE(col, 0)` to convert NULLs to 0 when summing.
- `UNION ALL` preserves duplicates (faster); `UNION` removes them (slower).
  - Here `UNION ALL` is correct because we WANT both directions counted.

---

## Problem 184: Department Highest Salary

**Tables:** `Employee(id, name, salary, departmentId)`, `Department(id, name)`

**Goal:** For each department, find the employee(s) with the highest salary.

### Solution 1: Subquery in WHERE
For each employee row, the subquery computes `MAX(salary)` within that employee's department. If the employee's salary matches, they are returned.

```sql
SELECT d.name AS Department, e.name AS Employee, e.salary
FROM Employee e
JOIN Department d ON d.id = e.departmentId
WHERE e.salary = (
    SELECT MAX(e2.salary)
    FROM Employee e2
    WHERE e2.departmentId = e.departmentId
);
```

### Solution 2: Subquery with GROUP BY + JOIN
First computes max salary per department in a derived table (`d_max_salary`), then joins back to Employee to get the matching row(s).

```sql
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
```

### Key Takeaway:
- Correlated subqueries (Solution 1) re-evaluate the subquery for each outer row — can be slower on large tables.
- Derived table joins (Solution 2) often perform better because the max is computed once per department.
- Both solutions correctly handle ties (multiple employees with the same max salary in a department).
- Fix applied: original used bare `salary` instead of `e.salary`, and lowercase `employee` table name. Now fully qualified.

---

## Problem 1280: Students and Examinations

**Tables:** 
- `Students(student_id, student_name)`
- `Subjects(subject_name)`
- `Examinations(student_id, subject_name)`

**Goal:** Return every student-subject combination with the count of exams the student attended for that subject (0 if they never attended).

### Solution 1: CROSS JOIN + LEFT JOIN
- `CROSS JOIN` pairs every student with every subject.
- `LEFT JOIN` brings in the exam counts from Examinations.
- `IFNULL(c, 0)` replaces NULL (no attendance) with 0.

```sql
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
```

### Solution 2: Correlated subquery
- `CROSS JOIN` pairs every student with every subject.
- A correlated subquery counts matching exam rows per pair.

```sql
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
```

### Key Takeaway:
- `CROSS JOIN` (without ON) creates the Cartesian product — every row from table A paired with every row from table B.
- `LEFT JOIN` ensures students with zero exams still appear.
- `IFNULL` / `COALESCE` converts NULL to a displayable default.
- Fix applied: added parentheses around the LEFT JOIN subquery for clearer join precedence.

---

## Problem 175: Combine Two Tables

**Tables:** `Person(personId, firstName, lastName, email)`, `Address(personId, city, state)`

**Goal:** Return first name, last name, city, and state for every person. People without an address should still appear (city/state = NULL).

### Solution: LEFT JOIN
`LEFT JOIN` ensures all Person rows are preserved; unmatched Address rows produce NULL for city and state.

```sql
SELECT
    p.firstName,
    p.lastName,
    a.city,
    a.state
FROM Person p
LEFT JOIN Address a ON p.personId = a.personId;
```

### Key Takeaway:
- `LEFT JOIN` is the RIGHT tool when you want ALL rows from the left table, regardless of whether the right table has a match.
- `RIGHT JOIN` would be used when you want ALL rows from the right table.
- The original Day 3.sql only had a comment ("Left outer join") with no SQL. This file adds the complete query.

---

## Problem 601: Human Traffic of Stadium

**Table:** `Stadium(id, visit_date, people)`

**Goal:** Return all rows where `people > 100` AND the id belongs to a group of 3 or more consecutive rows (by id) that all have `people > 100`.

### Solution 1: Self-join with UNION (original)
Joins Stadium to itself 3x to check consecutive ids. A UNION of 3 SELECTs returns whichever of the 3 ids satisfies the condition.

```sql
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
```

### Solution 2: Window functions (MySQL 8+) — gaps & islands
Groups consecutive rows (>100 people) into "islands" using the difference of row numbers, then keeps islands of size >= 3.

```sql
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
```

### Key Takeaway:
- Self-joins work in any SQL dialect but are verbose (O(n³) scans).
- Window functions (MySQL 8+) provide an elegant alternative using the gaps-and-islands pattern.
- Always `ORDER BY id` in the final SELECT for deterministic output.

---

## Review Notes

### 1. CTE (Common Table Expressions) with `WITH`
- Improves readability by breaking complex logic into named steps.
- Can be recursive (not covered today).
- CTEs are like temporary views that exist only for the query.

### 2. `UNION` vs `UNION ALL`
- `UNION` removes duplicate rows (slower — requires sort/distinct).
- `UNION ALL` keeps duplicates (faster).
- Use `UNION ALL` when you KNOW there are no duplicates or when duplicates are desired (e.g., bidirectional friend pairs).

### 3. `COALESCE`
- Returns the first non-NULL value in its argument list.
- Portable across MySQL, PostgreSQL, SQL Server.
- `IFNULL(col, default)` is MySQL-specific (only 2 args).

### 4. FULL OUTER JOIN workaround
- MySQL does not support `FULL OUTER JOIN`.
- Simulate with `LEFT JOIN UNION RIGHT JOIN`, or use `UNION ALL` after normalizing data into a single direction.

### 5. `CROSS JOIN`
- Produces the Cartesian product of two tables.
- No ON condition is needed (or allowed).
- Useful for creating all combinations (e.g., all students × all subjects).

### 6. Correlated vs uncorrelated subqueries
- Uncorrelated: runs once, independent of the outer query.
- Correlated: re-evaluates for each outer row (can be slow).
- Prefer derived table joins when performance matters.

### 7. Window functions (MySQL 8+)
- `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, `SUM() OVER()`, etc.
- Don't collapse rows (unlike `GROUP BY`).
- Powerful for running totals, ranking, gaps-and-islands.

### 8. Column qualification
- Always prefix columns with table aliases (e.g., `e.salary` not just `salary`).
- Prevents ambiguity errors and makes queries self-documenting.

### 9. Self-join pattern
- Alias the same table multiple times (e.g., `s1`, `s2`, `s3`).
- Useful for comparisons within a single table (consecutive rows, pairs).
## Assignment 3: Relational Algebra
### Instructions

For each problem:

1. Read the question carefully.
2. Determine which relational algebra operation(s) are needed.
3. What do each of the table look like from the relational algebra expressions?
4. Use the tables provided to get the answer.


## Relational Algebra Operators

| Symbol | Operation | Purpose |
|---|---|---|
| `σ` | Selection | Filters rows based on a condition |
| `π` | Projection | Selects specific columns |
| `⋈` | Join | Combines related tuples from two relations |
| `×` | Cartesian Product | Combines every tuple from one relation with every tuple from another |
| `÷` | Division | Finds tuples related to **all** tuples in another relation |
| `▷` | Semijoin | Returns tuples from the left relation that have a match in the right relation |

---

# Q1 — Product & Supplier

## Product

| id | pname | price | category | supplier_id |
|---:|---|---:|---|---:|
| 1 | A | 10.99 | Electronics | 101 |
| 2 | B | 20.00 | Clothing | 101 |
| 3 | C | 50.00 | Home | 102 |
| 4 | D | 25.50 | Clothing | 102 |
| 5 | E | 15.75 | Electronics | 102 |
| 6 | F | 15.00 | Beauty | 102 |
| 7 | G | 7.99 | Beauty | 103 |

## Supplier

| supplier_id | s_name | country |
|---:|---|---|
| 101 | AA | United States |
| 102 | BB | United Kingdom |
| 103 | CC | Mexico |
| 104 | DD | United States |

---

## Q1.1 — Selection

### Task

Find all products whose **price is greater than 10**.

### Instructions

Use **selection (`σ`)** to filter the `Product` relation. Your condition should compare the `price` attribute to `10`.

### Relational Algebra 

$`\sigma_{price > 10}(Product)`$

### What does the table look like from this relational algebra expression?







____________________________________________________________

---

## Q1.2 — Projection

### Task

Find all **countries** represented in the `Supplier` table.

### Instructions

Use **projection (`π`)** to return only the `country` attribute.

### Relational Algebra 

$`\pi_{country}(Supplier)`$

### What does the table look like from this relational algebra expression?








____________________________________________________________

---

## Q1.3 — Selection + Projection

### Task

Find the **categories of products supplied by supplier 102**.

### Instructions

1. First use **selection (`σ`)** to find products where `supplier_id = 102`.
2. Then use **projection (`π`)** to return only `category`.

### Relational Algebra 

$`\pi_{category}(\sigma_{supplier\_id = 102}(Product))`$

### What does the table look like from this relational algebra expression?







____________________________________________________________

---

## Q1.4 — Join + Projection

### Task

Find the following information for every product and its supplier:

- Supplier name
- Product name
- Product category
- Product price
- Supplier country

### Instructions

1. Join `Product` and `Supplier` using their common `supplier_id`.
2. Project only the five requested attributes.

### Relational Algebra 

$`\pi_{s\_name, pname, category, price, country}(Supplier \bowtie Product)`$

### What does the table look like from this relational algebra expression?







____________________________________________________________

---

## Q1.5 — Division

### Task

Find the suppliers that supply **every product category** represented in the `Product` relation.

### Instructions

1. Determine which relation should represent the suppliers.
2. Determine which relation should contain all product categories.
3. Use **division (`÷`)** to find suppliers associated with **all** categories.
4. Make sure the attributes needed for division are compatible.

### Relational Algebra 

$`Supplier \div \pi_{category}(Product)`$

### What does the table look like from this relational algebra expression?







____________________________________________________________

### What does division mean in this problem?

Division identifies the suppliers whose supplied categories include the complete set of all unique categories present in the Product relation.






____________________________________________________________

---

## Q1.6 — Selection + Join + Projection

### Task

Find the **product name (`pname`)** and **supplier name (`s_name`)** for products whose **price is greater than 20** and whose supplier is located in the **United States**.

### Instructions

1. Select products where `price > 20`.
2. Select suppliers where `country = 'United States'`.
3. Join the two relations using `supplier_id`.
4. Project `pname` and `s_name`.

### Relational Algebra 

$`\pi_{pname, s\_name}(\sigma_{price > 20}(Product) \bowtie \sigma_{country = 'United States'}(Supplier))`$

### What does the table look like from this relational algebra expression?







____________________________________________________________

---

## Q1.7 — Semijoin

### Task

Find the **names of suppliers that supply at least one Electronics product**.

### Instructions

1. Select products where `category = 'Electronics'`.
2. Use a **semijoin (`▷`)** with `Supplier`.
3. Return only the supplier names.

### Relational Algebra 

$`\pi_{s\_name}(Supplier \triangleright \sigma_{category = 'Electronics'}(Product))`$

### What does the table look like from this relational algebra expression?







____________________________________________________________

### Explain what the semijoin is accomplishing

The semijoin filters the Supplier relation to retain only the suppliers that match the condition in the Product relation without duplicating product attributes.







____________________________________________________________

---

## Q1.8 — Cartesian Product + Selection + Projection

### Task

Find the **product name, price, and supplier name** for products whose supplier is located in the **United Kingdom**.

### Instructions

1. Create the Cartesian product of `Product` and `Supplier` using `×`.
2. Select tuples where:
   - `Product.supplier_id = Supplier.supplier_id`
   - `country = 'United Kingdom'`
3. Project:
   - `pname`
   - `price`
   - `s_name`

### Relational Algebra 

$`\pi_{pname, price, s\_name}(\sigma_{country = 'United Kingdom' \land Product.supplier\_id = Supplier.supplier\_id}(Product \times Supplier))`$

### What does the table look like from this relational algebra expression?







____________________________________________________________

---

# Q2 — Employee & Department

## Employee

| emp_id | emp_name | dept_id | salary |
|---:|---|---:|---:|
| 1 | Alice | 10 | 60000 |
| 2 | Bob | 20 | 55000 |
| 3 | Carol | 10 | 62000 |
| 4 | Dave | 30 | 48000 |
| 5 | Eve | 20 | 52000 |

## Department

| dept_id | dept_name |
|---:|---|
| 10 | HR |
| 20 | IT |
| 30 | Sales |

---

## Q2.1 — Selection

### Task

Find all employees whose **salary is greater than 55,000**.

### Instructions

Use **selection (`σ`)** on the `Employee` relation.

### Relational Algebra 

$`\sigma_{salary > 55000}(Employee)`$

### What does the table look like from this relational algebra expression?









____________________________________________________________

---

## Q2.2 — Projection

### Task

Find all **department names**.

### Instructions

Use **projection (`π`)** on the `Department` relation to return only `dept_name`.

### Relational Algebra 

$`\pi_{dept\_name}(Department)`$

### What does the table look like from this relational algebra expression?









____________________________________________________________

---

## Q2.3 — Selection + Projection

### Task

Find the **names and salaries of employees who work in department 20**.

### Instructions

1. Select employees where `dept_id = 20`.
2. Project `emp_name` and `salary`.

### Relational Algebra 

$`\pi_{emp\_name, salary}(\sigma_{dept\_id = 20}(Employee))`$

### What does the table look like from this relational algebra expression?








____________________________________________________________

---

## Q2.4 — Join + Projection

### Task

Find each employee's **name** and their **department name**.

### Instructions

1. Join `Employee` and `Department` using `dept_id`.
2. Project `emp_name` and `dept_name`.

### Relational Algebra 

$`\pi_{emp\_name, dept\_name}(Employee \bowtie Department)`$

### What does the table look like from this relational algebra expression?








____________________________________________________________

---

## Q2.5 — Join + Selection + Projection

### Task

Find the **names and salaries of employees who work in the IT department and earn more than 50,000**.

### Instructions

1. Join `Employee` and `Department`.
2. Select tuples where:
   - `dept_name = 'IT'`
   - `salary > 50000`
3. Project `emp_name` and `salary`.

### Relational Algebra 

$`\pi_{emp\_name, salary}(\sigma_{dept\_name = 'IT' \land salary > 50000}(Employee \bowtie Department))`$

### What does the table look like from this relational algebra expression?






____________________________________________________________

---

## Q2.6 — Semijoin

### Task

Find the **department names that have at least one employee earning more than 60,000**.

### Instructions

1. Select employees where `salary > 60000`.
2. Use a **semijoin (`▷`)** with `Department`.
3. Project only `dept_name`.

### Relational Algebra 

$`\pi_{dept\_name}(Department \triangleright \sigma_{salary > 60000}(Employee))`$

### What does the table look like from this relational algebra expression?







____________________________________________________________

### Explain why a semijoin can be used here

A semijoin filters the Department relation based on a condition in the Employee relation and returns only department attributes without requiring a full join or keeping employee columns.






____________________________________________________________

---

## Q2.7 — Cartesian Product + Selection + Projection

### Task

Find the **employee names and department names** for employees who work in the **Sales** department.

### Instructions

1. Create the Cartesian product of `Employee` and `Department` using `×`.
2. Select tuples where:
   - `Employee.dept_id = Department.dept_id`
   - `dept_name = 'Sales'`
3. Project:
   - `emp_name`
   - `dept_name`

### Relational Algebra 

$`\pi_{emp\_name, dept\_name}(\sigma_{dept\_name = 'Sales' \land Employee.dept\_id = Department.dept\_id}(Employee \times Department))`$

### What does the table look like from this relational algebra expression?






____________________________________________________________

---

**main relational algebra operation** being used for each.

| Problem | Operation |
|---|---|
| Q1.1 | Selection |
| Q1.2 | Projection |
| Q1.3 | Selection + Projection |
| Q1.4 | Join + Projection |
| Q1.5 | Division |
| Q1.6 | Selection + Join + Projection |
| Q1.7 | Semijoin + Projection |
| Q1.8 | Cartesian Product + Selection + Projection |
| Q2.1 | Selection |
| Q2.2 | Projection |
| Q2.3 | Selection + Projection |
| Q2.4 | Join + Projection |
| Q2.5 | Join + Selection + Projection |
| Q2.6 | Semijoin + Projection |
| Q2.7 | Cartesian Product + Selection + Projection |


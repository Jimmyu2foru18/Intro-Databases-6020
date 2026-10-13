## Assignment 4 FD & Normal Forms
## Q1. Functional Dependencies & Transitive Closures

Given the set of functional dependencies:
| Functional Dependencies |
|-------------------------|
| $AB \to CD$              |
| $C \to EF$              |
| $A \to G$               |
| $B \to H$               |

Calculate the following closures:

| Given Set | Transitive Closure |
|---|---|
| $\{A\}^+$ | $\{A, G\}$ |
| $\{B\}^+$ | $\{B, H\}$ |
| $\{A, B\}^+$ | $\{A, B, C, D, E, F, G, H\}$ |
| $\{A, C\}^+$ | $\{A, C, E, F, G\}$ |

---

## Q2. Finding Candidate Keys

Given a relation $R$ with attributes $(A, B, C, D, E, F)$, find all the keys in each case:

| Case | Functional Dependencies | Candidate Key(s) |
|---|---|---|
| 1 | $AB \to C, CD \to E, E \to F$ | $\{A, B, D\}$ |
| 2 | $A \to BC, B \to DE, E \to F$ | $\{A\}$ |
| 3 | $AB \to C, A \to D, B \to E, D \to F$ | $\{A, B\}$ |
| 4 | $AB \to C, C \to DE, D \to A$ *(attributes $A, B, C, D, E$)* | $\{B, C\}$ and $\{B, D\}$ |

---

## Q3. Table Keys

Given the relation `APPEARS-IN(actor-name, age, sex, movie-title, year, director, studio, budget, salary)` and the functional dependencies:
* `actor-name` $\to$ `age, sex`
* `movie-title, year` $\to$ `director, studio, budget`
* `actor-name, movie-title` $\to$ `salary`

| Keys | Why these are Keys? |
|---|---|
| `{actor-name, movie-title, year}` | Any attributes absent from the right side of every functional dependency belong to the key, and their closure includes all attributes. |

---

## Q4. Normalization

Given the relation `CAR_SALE(Car#, Date_sold, Salesperson#, Commission%, Discount_amt)` with primary key `{Car#, Salesperson#}` and functional dependencies:
* `Date_sold` $\to$ `Discount_amt`
* `Salesperson#` $\to$ `Commission%`

### 1. Normal Form Assessment
The relation is in 1NF because all attributes contain atomic values. It is not in 2NF because a proper subset of the composite primary key determines non-prime attributes, which violates the requirement that every non-prime attribute must be fully functionally dependent on the primary key. Since it fails 2NF, it automatically fails 3NF.

### 2. Successive Normalization Steps

* **Step 1 (Achieve 2NF)**: Remove partial dependencies by splitting the relation into three tables:
  * `SALESPERSON(Salesperson#, Commission%)`
  * `SALE_DATE(Date_sold, Discount_amt)`
  * `CAR_SALE_MAIN(Car#, Salesperson#, Date_sold)`

* **Step 2 (Achieve 3NF and BCNF)**: Check for transitive dependencies among non-prime attributes in the new tables. No transitive dependencies exist because all non-prime attributes are fully functionally dependent only on candidate keys, meaning the decomposition satisfies 3NF and BCNF.

---

## Q5. Key Determination and Normalization

Given the relation `REFRIG(Model, Year, Price, Manuf_plant, Color)`, abbreviated as `REFRIG(M, Y, P, MP, C)`, and functional dependencies:
| Functional Dependencies |
|-------------------------|
| $M \to MP$              |
| $MY \to P$              |
| $MP \to C$              |

### a. Candidate Key Evaluation

| Set | Key or Not Key |
|---|---|
| $\{M\}$ | Not a key. It is $\{M\}^+$= $\{M, MP, C\}$, no $Y$ and no $P$. |
| $\{M, Y\}$ | Is a candidate key. Has all attributes. |
| $\{M, C\}$ | Not a key.|

### b. Normal Form Status
The relation is not in BCNF and not in 3NF. 
- The functional dependency $M \to MP$ violates BCNF because $M$ is not a superkey. 
- It also violates 3NF because $M$ is not a superkey and $MP$ is not a prime attribute.
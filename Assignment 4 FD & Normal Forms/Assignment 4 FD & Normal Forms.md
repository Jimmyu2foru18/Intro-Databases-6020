# Database Exercises

## Q1. Functional Dependencies and Transitive Closures

Given the set of functional dependencies:
$F = \{AB \to CD, C \to EF, A \to G, B \to H\}$

Calculate the following transitive closures:
* $\{A\}^+$
* $\{B\}^+$
* $\{A, B\}^+$
* $\{A, C\}^+$


## Q2. Finding Candidate Keys

Given a relation $R$ with attributes $(A, B, C, D, E, F)$, find all the keys of $R$ in each of the following cases, where the functional dependencies are given:

1. $AB \to C, CD \to E, E \to F$
2. $A \to BC, B \to DE, E \to F$
3. $AB \to C, A \to D, B \to E, D \to F$
4. $AB \to C, C \to DE, D \to A$ (for attributes $A, B, C, D, E$)


## Q3. Table Keys

We are given the table `APPEARS-IN(actor-name, age, sex, movie-title, year, director, studio, budget, salary)` and the following functional dependencies:
* `actor-name` $\to$ `age, sex`
* `movie-title, year` $\to$ `director, studio, budget`
* `actor-name, movie-title` $\to$ `salary`

Find all the keys of the `APPEARS-IN` table.


## Q4. Normalization

Consider the following relation:
`CAR_SALE(Car#, Date_sold, Salesperson#, Commission%, Discount_amt)`

Assume that a car may be sold by multiple salespeople, and hence `{Car#, Salesperson#}` is the primary key. The additional functional dependencies are:
* `Date_sold` $\to$ `Discount_amt`
* `Salesperson#` $\to$ `Commission%`

Based on the given primary key, answer the following:
* Is this relation in 1NF, 2NF, or 3NF? Why or why not?
* How would you successively normalize it completely?


## Q5. Key Determination and Normalization

Consider the relation `REFRIG(Model#, Year, Price, Manuf_plant, Color)`, which is abbreviated as `REFRIG(M, Y, P, MP, C)`, and the following set $F$ of functional dependencies:
$F = \{M \to MP, MY \to P, MP \to C\}$

### a.
Evaluate each of the following as a candidate key for `REFRIG`, giving reasons why it can or cannot be a key:
* $\{M\}$
* $\{M, Y\}$
* $\{M, C\}$

### b.
Based on the above key determination, state whether the relation `REFRIG` is in 3NF and in BCNF, providing proper reasons.
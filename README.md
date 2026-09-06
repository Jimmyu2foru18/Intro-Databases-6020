# Restaurant Datasets

I'm storing relational SQL datasets for local restaurants to use for later when i have a idea what to use them for. 
Ideas:
- Menu pricing analysis.
- Category distribution studies.
- Relational querying practice.

## Dataset Files

* `tai_feng_panda_house.sql`: 
* `big_bang_sushi_poke.sql`

## Import Data into SQLite

From `restaurants.db`.

```bash
sqlite3 restaurants.db < tai_feng_panda_house.sql
sqlite3 restaurants.db < big_bang_sushi_poke.sql
```

## Query Analysis
- Average prices by category:

```sql
SELECT c.name AS category_name, AVG(m.price) AS average_price
FROM categories c
JOIN menu_items m ON c.category_id = m.category_id
GROUP BY c.name
ORDER BY average_price DESC;
```

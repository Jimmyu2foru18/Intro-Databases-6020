-- Unnested (join-based) query catalog for IMDb schema
-- Generated via Gemini API as equivalents of nested_queries.sql.
--

-- Q01 (unnested): Movies rated above their year's average rating
WITH year_avg AS (
    SELECT
        m2.year,
        AVG(r2.rating) AS avg_rating
    FROM ratings r2
    JOIN movies m2 ON m2.id = r2.movie_id
    GROUP BY m2.year
)
SELECT
    m.title,
    m.year,
    r.rating
FROM movies m
JOIN ratings r ON r.movie_id = m.id
JOIN year_avg ya ON ya.year = m.year
WHERE r.rating > ya.avg_rating
ORDER BY m.year, r.rating DESC;

-- Q02 (unnested): Movies with director-actor overlap
WITH director_actors AS (
    SELECT DISTINCT d.movie_id
    FROM directors d
    JOIN stars s ON d.person_id = s.person_id
    WHERE d.movie_id <> s.movie_id
)
SELECT
    m.title,
    m.year
FROM movies m
JOIN director_actors da ON m.id = da.movie_id
ORDER BY m.year DESC, m.title;

-- Q03 (unnested): Actors who starred in more movies than the average per-movie cast size
WITH actor_counts AS (
    SELECT person_id, COUNT(*) AS movie_count
    FROM stars
    GROUP BY person_id
),
avg_cast_size AS (
    SELECT AVG(cast_size) AS avg_size
    FROM (
        SELECT COUNT(*) AS cast_size
        FROM stars
        GROUP BY movie_id
    ) t
)
SELECT
    p.name,
    p.birth,
    ac.movie_count
FROM people p
JOIN actor_counts ac ON p.id = ac.person_id
CROSS JOIN avg_cast_size acs
WHERE ac.movie_count > acs.avg_size
ORDER BY ac.movie_count DESC, p.name;

-- Q04 (unnested): Movies without ratings
SELECT
    m.title,
    m.year
FROM movies m
LEFT JOIN ratings r ON m.id = r.movie_id
WHERE r.movie_id IS NULL
ORDER BY m.year DESC, m.title;

-- Q05 (unnested): Highest-rated movie per year
WITH MaxRatings AS (
    SELECT 
        m.year, 
        MAX(r.rating) AS max_rating
    FROM movies m
    JOIN ratings r ON r.movie_id = m.id
    GROUP BY m.year
)
SELECT 
    m.title, 
    m.year, 
    r.rating
FROM movies m
JOIN ratings r ON r.movie_id = m.id
JOIN MaxRatings mr ON m.year = mr.year AND r.rating = mr.max_rating
ORDER BY m.year DESC;

-- Q06 (unnested): Movies sharing at least one director with a specific movie
WITH matrix_directors AS (
    SELECT DISTINCT d.person_id
    FROM directors d
    JOIN movies m ON m.id = d.movie_id
    WHERE m.title ILIKE '%Matrix%'
),
shared_director_movies AS (
    SELECT DISTINCT d.movie_id
    FROM directors d
    JOIN matrix_directors md ON d.person_id = md.person_id
    JOIN movies m_matrix ON m_matrix.title ILIKE '%Matrix%'
    WHERE d.movie_id <> m_matrix.id
)
SELECT
    m.title,
    m.year
FROM movies m
JOIN shared_director_movies sdm ON m.id = sdm.movie_id
ORDER BY m.year DESC, m.title;

-- Q07 (unnested): Movies with no directors
SELECT
    m.title,
    m.year
FROM movies m
LEFT JOIN directors d ON m.id = d.movie_id
WHERE d.movie_id IS NULL
ORDER BY m.year DESC, m.title;

-- Q08 (unnested): Actors who have also directed a movie
SELECT
    p.name,
    p.birth
FROM people p
INNER JOIN (
    SELECT DISTINCT person_id
    FROM stars
) s ON p.id = s.person_id
INNER JOIN (
    SELECT DISTINCT person_id
    FROM directors
) d ON p.id = d.person_id
ORDER BY p.name;

-- Q09 (unnested): Movies where every actor was born after 1950
WITH OldActors AS (
    SELECT DISTINCT s.movie_id
    FROM stars s
    JOIN people pp ON pp.id = s.person_id
    WHERE pp.birth <= 1950
)
SELECT
    m.title,
    m.year
FROM movies m
LEFT JOIN OldActors oa ON m.id = oa.movie_id
WHERE oa.movie_id IS NULL
ORDER BY m.year DESC, m.title;

-- Q10 (unnested): Movies in the top 75th percentile of rating per year
WITH year_percentiles AS (
    SELECT
        m.year,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY r.rating) AS threshold
    FROM movies m
    JOIN ratings r ON m.id = r.movie_id
    GROUP BY m.year
)
SELECT
    m.title,
    m.year,
    r.rating
FROM movies m
JOIN ratings r ON m.id = r.movie_id
JOIN year_percentiles yp ON m.year = yp.year
WHERE r.rating > yp.threshold
ORDER BY m.year DESC, r.rating DESC;

-- Q11 (unnested): Movies with above-average number of distinct directors
WITH MovieDirectorCounts AS (
    SELECT movie_id, COUNT(DISTINCT director_id) AS director_count
    FROM movie_directors
    GROUP BY movie_id
),
AverageDirectorCount AS (
    SELECT AVG(director_count::numeric) AS avg_count
    FROM MovieDirectorCounts
)
SELECT mdc.movie_id
FROM MovieDirectorCounts mdc, AverageDirectorCount adc
WHERE mdc.director_count > adc.avg_count
ORDER BY mdc.movie_id;

-- Q12 (unnested): Actors who worked with directors they also co-starred with
WITH actor_co_stars AS (
    SELECT DISTINCT
        s1.person_id AS actor_id,
        s2.person_id AS co_star_id,
        s1.movie_id
    FROM stars s1
    JOIN stars s2 ON s1.movie_id = s2.movie_id AND s1.person_id <> s2.person_id
),
director_co_star_pairs AS (
    SELECT DISTINCT
        d.person_id AS director_id,
        acs.actor_id
    FROM directors d
    JOIN actor_co_stars acs ON d.movie_id = acs.movie_id
)
SELECT DISTINCT
    m.title,
    p.name AS actor_name
FROM movies m
JOIN stars s ON s.movie_id = m.id
JOIN people p ON p.id = s.person_id
JOIN directors d ON d.movie_id = m.id
JOIN director_co_star_pairs dcsp ON dcsp.director_id = d.person_id AND dcsp.actor_id = s.person_id
ORDER BY m.year DESC, p.name;

-- Q13 (unnested): Movies rated higher than their director's average rating
WITH director_avg_ratings AS (
    SELECT
        d.movie_id,
        AVG(r_inner.rating) OVER (PARTITION BY d.person_id) as avg_rating
    FROM directors d
    JOIN ratings r_inner ON d.movie_id = r_inner.movie_id
)
SELECT
    m.title,
    m.year,
    r.rating
FROM movies m
JOIN ratings r ON r.movie_id = m.id
JOIN director_avg_ratings dar ON m.id = dar.movie_id
WHERE r.rating > dar.avg_rating
ORDER BY m.year DESC, r.rating DESC;

-- Q14 (unnested): Movies whose release year had a higher total vote count than the
WITH yearly_votes AS (
    SELECT 
        m.year, 
        SUM(r.votes) AS total_votes
    FROM movies m
    JOIN ratings r ON r.movie_id = m.id
    GROUP BY m.year
),
comparison AS (
    SELECT 
        curr.year
    FROM yearly_votes curr
    JOIN yearly_votes prev ON curr.year = prev.year + 1
    WHERE curr.total_votes > prev.total_votes
)
SELECT 
    m.title, 
    m.year
FROM movies m
JOIN comparison c ON m.year = c.year
ORDER BY m.year DESC, m.title;

-- Q15 (unnested): Movies outside the top-3 rated per year
WITH RankedMovies AS (
    SELECT 
        m.id,
        m.release_year,
        m.rating,
        DENSE_RANK() OVER (PARTITION BY m.release_year ORDER BY m.rating DESC) as rnk
    FROM movies m
)
SELECT id
FROM RankedMovies
WHERE rnk > 3
ORDER BY id;


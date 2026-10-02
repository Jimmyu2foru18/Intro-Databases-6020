-- IMDB Queries

-- Q1

SELECT title
FROM movies
WHERE year = 2008;


-- Q2

SELECT birth
FROM people
WHERE name = 'Emma Stone';

-- Q3

SELECT title
FROM movies
WHERE year >= 2018
ORDER BY title ASC;

-- Q4

SELECT title, year
FROM movies
WHERE title LIKE 'Harry Potter%'
ORDER BY year ASC;

-- Q5

SELECT COUNT(*)
FROM ratings
WHERE rating = 10.0;


-- Q6

SELECT AVG(rating)
FROM ratings
WHERE movie_id IN 
(
	SELECT id 
	FROM movies 
	WHERE year = 2012
);

-- Q7

SELECT title, rating
FROM movies
JOIN ratings ON movies.id = ratings.movie_id
WHERE year = 2010
ORDER BY rating DESC, title ASC;

-- Q8

SELECT people.name
FROM people
JOIN stars ON people.id = stars.person_id
JOIN movies ON stars.movie_id = movies.id
WHERE movies.title = 'Toy Story';

-- Q9

SELECT name
FROM people
WHERE id IN 
(
	SELECT person_id
	FROM stars
	WHERE movie_id IN 
	(
		SELECT id
		FROM movies
		WHERE year = 2004
	)
)
ORDER BY birth ASC;


-- Q10

SELECT name
FROM people
WHERE id IN 
(
	SELECT person_id
	FROM directors
	WHERE movie_id IN 
	(
		SELECT movie_id
		FROM ratings
		WHERE rating >= 9.0
	)
);

-- Q11

SELECT movies.title
FROM movies
JOIN ratings ON movies.id = ratings.movie_id
JOIN stars ON movies.id = stars.movie_id
JOIN people ON stars.person_id = people.id
WHERE people.name = 'Chadwick Boseman'
ORDER BY ratings.rating DESC
LIMIT 5;

-- Q12

SELECT m.title
FROM movies m
JOIN stars s1 ON m.id = s1.movie_id
JOIN people p1 ON s1.person_id = p1.id
JOIN stars s2 ON m.id = s2.movie_id
JOIN people p2 ON s2.person_id = p2.id
WHERE p1.name = 'Johnny Depp'
AND p2.name = 'Helena Bonham Carter';


-- Q13

SELECT DISTINCT p_costar.name
FROM people p_kb
JOIN stars s_kb ON p_kb.id = s_kb.person_id
JOIN stars s_costar ON s_kb.movie_id = s_costar.movie_id
JOIN people p_costar ON s_costar.person_id = p_costar.id
WHERE p_kb.name = 'Kevin Bacon'
AND p_kb.birth = 1958
AND p_costar.id != p_kb.id;

-- Q14

SELECT title, rating
FROM movies
JOIN ratings ON movies.id = ratings.movie_id
WHERE rating > 
(		--use average
	SELECT AVG(rating) 
	FROM ratings
);


-- Q15  Had to look this one up how to write it 

SELECT p1.name AS actor_1, p2.name AS actor_2, 
AVG(r.rating) AS avg_co_star_rating,
COUNT(r.movie_id) AS movies_together
FROM stars s1
JOIN stars s2 ON s1.movie_id = s2.movie_id AND s1.person_id < s2.person_id
JOIN people p1 ON s1.person_id = p1.id
JOIN people p2 ON s2.person_id = p2.id
JOIN ratings r ON s1.movie_id = r.movie_id
GROUP BY p1.id, p2.id, p1.name, p2.name
HAVING COUNT(r.movie_id) >= 2
ORDER BY avg_co_star_rating DESC;

-- Q16

SELECT name,
MAX(rating) AS highest_rating,
MIN(rating) AS lowest_rating,
MAX(rating) - MIN(rating) AS rating_difference
FROM people
JOIN stars ON people.id = stars.person_id
JOIN ratings ON stars.movie_id = ratings.movie_id
GROUP BY people.id
HAVING COUNT(ratings.movie_id) > 1
ORDER BY rating_difference DESC;

-- Q16 had to look this up to get title 

SELECT 
    p.name AS actor_name,
    (
        SELECT m.title 
        FROM movies m 
        JOIN stars s ON m.id = s.movie_id 
        JOIN ratings r ON m.id = r.movie_id 
        WHERE s.person_id = p.id AND r.rating = stats.highest_rating 
        LIMIT 1
    ) AS highest_rated_movie,
    stats.highest_rating,
    (
        SELECT m.title 
        FROM movies m 
        JOIN stars s ON m.id = s.movie_id 
        JOIN ratings r ON m.id = r.movie_id 
        WHERE s.person_id = p.id AND r.rating = stats.lowest_rating 
        LIMIT 1
    ) AS lowest_rated_movie,
    stats.lowest_rating,
    stats.rating_difference
FROM people p
JOIN (
    SELECT 
        s.person_id,
        MAX(r.rating) AS highest_rating,
        MIN(r.rating) AS lowest_rating,
        MAX(r.rating) - MIN(r.rating) AS rating_difference
    FROM stars s
    JOIN ratings r ON s.movie_id = r.movie_id
    GROUP BY s.person_id
    HAVING COUNT(r.rating) > 1
) stats ON p.id = stats.person_id
ORDER BY stats.rating_difference DESC;


-- Q17

SELECT name,
COUNT(movie_id) AS total_movies_directed,
ROUND(AVG(rating), 2) AS average_rating,
SUM(votes) AS total_votes
FROM people
JOIN directors ON people.id = directors.person_id
JOIN ratings ON directors.movie_id = ratings.movie_id
GROUP BY people.id
HAVING total_movies_directed >= 3 AND total_votes >= 10000
ORDER BY average_rating DESC, total_votes DESC;
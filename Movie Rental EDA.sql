-- LANGUAGE
CREATE TABLE language (
    language_id   SERIAL PRIMARY KEY,
    name          VARCHAR(20) NOT NULL,
    last_update   TIMESTAMP
);

-- CATEGORY
CREATE TABLE category (
    category_id   SERIAL PRIMARY KEY,
    name          VARCHAR(25) NOT NULL,
    last_update   TIMESTAMP
);

-- COUNTRY
CREATE TABLE country (
    country_id    SERIAL PRIMARY KEY,
    country       VARCHAR(50) NOT NULL,
    last_update   TIMESTAMP
);

-- CITY
CREATE TABLE city (
    city_id       SERIAL PRIMARY KEY,
    city          VARCHAR(50) NOT NULL,
    country_id    INT REFERENCES country(country_id),
    last_update   TIMESTAMP
);

-- ADDRESS
CREATE TABLE address (
    address_id    SERIAL PRIMARY KEY,
    address       VARCHAR(50),
    address2      VARCHAR(50),
    district      VARCHAR(20),
    city_id       INT REFERENCES city(city_id),
    postal_code   VARCHAR(10),
    phone         VARCHAR(20),
    last_update   TIMESTAMP
);

-- STORE
CREATE TABLE store (
    store_id          SERIAL PRIMARY KEY,
    manager_staff_id  INT,
    address_id        INT REFERENCES address(address_id),
    last_update       TIMESTAMP
);

-- STAFF
CREATE TABLE staff (
    staff_id      SERIAL PRIMARY KEY,
    first_name    VARCHAR(45),
    last_name     VARCHAR(45),
    address_id    INT REFERENCES address(address_id),
    email         VARCHAR(50),
    store_id      INT REFERENCES store(store_id),
    active        BOOLEAN,
    username      VARCHAR(16),
    password      VARCHAR(40),
    last_update   TIMESTAMP
);

-- CUSTOMER
CREATE TABLE customer (
    customer_id   SERIAL PRIMARY KEY,
    store_id      INT REFERENCES store(store_id),
    first_name    VARCHAR(45),
    last_name     VARCHAR(45),
    email         VARCHAR(50),
    address_id    INT REFERENCES address(address_id),
    active        BOOLEAN,
    create_date   TIMESTAMP,
    last_update   TIMESTAMP
);

-- FILM
CREATE TABLE film (
    film_id               SERIAL PRIMARY KEY,
    title                 VARCHAR(255),
    description           TEXT,
    release_year          INT,
    language_id           INT REFERENCES language(language_id),
    rental_duration       INT,
    rental_rate           NUMERIC(4,2),
    length                INT,
    replacement_cost      NUMERIC(5,2),
    rating                VARCHAR(10),
    special_features      TEXT,
    last_update           TIMESTAMP
);

-- ACTOR
CREATE TABLE actor (
    actor_id      SERIAL PRIMARY KEY,
    first_name    VARCHAR(45),
    last_name     VARCHAR(45),
    last_update   TIMESTAMP
);

-- FILM_ACTOR
CREATE TABLE film_actor (
    actor_id      INT REFERENCES actor(actor_id),
    film_id       INT REFERENCES film(film_id),
    last_update   TIMESTAMP,
    PRIMARY KEY (actor_id, film_id)
);

--FILM_TEXT
CREATE TABLE film_text (
    film_id      INT PRIMARY KEY,
    title        VARCHAR(255) NOT NULL,
    description  TEXT
);

-- FILM_CATEGORY
CREATE TABLE film_category (
    film_id       INT REFERENCES film(film_id),
    category_id   INT REFERENCES category(category_id),
    last_update   TIMESTAMP,
    PRIMARY KEY (film_id, category_id)
);

-- INVENTORY
CREATE TABLE inventory (
    inventory_id  SERIAL PRIMARY KEY,
    film_id       INT REFERENCES film(film_id),
    store_id      INT REFERENCES store(store_id),
    last_update   TIMESTAMP
);

-- RENTAL
CREATE TABLE rental (
    rental_id     SERIAL PRIMARY KEY,
    rental_date   TIMESTAMP,
    inventory_id  INT REFERENCES inventory(inventory_id),
    customer_id   INT REFERENCES customer(customer_id),
    return_date   TIMESTAMP,
    staff_id      INT REFERENCES staff(staff_id),
    last_update   TIMESTAMP
);

-- PAYMENT
CREATE TABLE payment (
    payment_id    SERIAL PRIMARY KEY,
    customer_id   INT REFERENCES customer(customer_id),
    staff_id      INT REFERENCES staff(staff_id),
    rental_id     INT REFERENCES rental(rental_id),
    amount        NUMERIC(5,2),
    payment_date  TIMESTAMP,
    last_update   TIMESTAMP
);


-- ============================================================
--   MOVIE RENTAL DATABASE
--   Power BI Capstone EDA — All 15 Questions
--   Database: Movie_Rental | PostgreSQL 18
-- ============================================================


-- ============================================================
-- Q1. What are the purchasing patterns of new vs repeat customers?
-- ============================================================

-- Step 1: Segment customers by rental frequency
WITH customer_rentals AS (
    SELECT
        customer_id,
        COUNT(rental_id)        AS total_rentals,
        MIN(rental_date)        AS first_rental,
        MAX(rental_date)        AS last_rental
    FROM rental
    GROUP BY customer_id
),
segmented AS (
    SELECT *,
        CASE
            WHEN total_rentals <= 20 THEN 'Low Frequency (1-20)'
            WHEN total_rentals <= 30 THEN 'Medium Frequency (21-30)'
            ELSE 'High Frequency (31+)'
        END AS customer_segment
    FROM customer_rentals
)
SELECT
    customer_segment,
    COUNT(*)                                        AS total_customers,
    ROUND(AVG(total_rentals), 2)                   AS avg_rentals,
    ROUND(AVG(total_rentals * 1.0 /
        GREATEST(
            EXTRACT(DAY FROM last_rental - first_rental) / 30.0, 1
        )), 2)                                      AS avg_rentals_per_month
FROM segmented
GROUP BY customer_segment
ORDER BY avg_rentals;

-- Step 2: Average spend per segment
WITH customer_segments AS (
    SELECT
        r.customer_id,
        CASE
            WHEN COUNT(r.rental_id) <= 20 THEN 'Low Frequency (1-20)'
            WHEN COUNT(r.rental_id) <= 30 THEN 'Medium Frequency (21-30)'
            ELSE 'High Frequency (31+)'
        END AS customer_segment
    FROM rental r
    GROUP BY r.customer_id
),
spend AS (
    SELECT customer_id, SUM(amount) AS total_spent
    FROM payment
    GROUP BY customer_id
)
SELECT
    cs.customer_segment,
    COUNT(*)                                            AS total_customers,
    ROUND(AVG(sp.total_spent), 2)                      AS avg_spend,
    ROUND(SUM(sp.total_spent), 2)                      AS total_revenue,
    ROUND(100.0 * SUM(sp.total_spent) /
        SUM(SUM(sp.total_spent)) OVER(), 2)            AS revenue_share_pct
FROM customer_segments cs
JOIN spend sp USING (customer_id)
GROUP BY cs.customer_segment
ORDER BY avg_spend;

-- Step 3: Average days between rentals
WITH ordered AS (
    SELECT
        customer_id,
        rental_date,
        LAG(rental_date) OVER (PARTITION BY customer_id ORDER BY rental_date) AS prev_date
    FROM rental
)
SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM rental_date - prev_date) / 86400), 2) AS avg_days_between_rentals
FROM ordered
WHERE prev_date IS NOT NULL;


-- ============================================================
-- Q2. Which films have the highest rental rates and are most in demand?
-- ============================================================

-- Top 10 most rented films
SELECT
    f.title,
    f.rental_rate,
    f.rating,
    COUNT(r.rental_id)              AS total_rentals,
    ROUND(SUM(p.amount), 2)        AS total_revenue
FROM film f
JOIN inventory i        ON f.film_id = i.film_id
JOIN rental r           ON i.inventory_id = r.inventory_id
JOIN payment p          ON r.rental_id = p.rental_id
GROUP BY f.film_id, f.title, f.rental_rate, f.rating
ORDER BY total_rentals DESC
LIMIT 10;

-- Films with highest rental rate vs demand
SELECT
    f.rental_rate,
    COUNT(DISTINCT f.film_id)       AS total_films,
    COUNT(r.rental_id)              AS total_rentals,
    ROUND(AVG(p.amount), 2)        AS avg_payment
FROM film f
JOIN inventory i        ON f.film_id = i.film_id
JOIN rental r           ON i.inventory_id = r.inventory_id
JOIN payment p          ON r.rental_id = p.rental_id
GROUP BY f.rental_rate
ORDER BY f.rental_rate DESC;

-- Most in-demand film categories
SELECT
    c.name                          AS category,
    COUNT(r.rental_id)              AS total_rentals,
    ROUND(SUM(p.amount), 2)        AS total_revenue,
    ROUND(AVG(f.rental_rate), 2)   AS avg_rental_rate
FROM category c
JOIN film_category fc   ON c.category_id = fc.category_id
JOIN film f             ON fc.film_id = f.film_id
JOIN inventory i        ON f.film_id = i.film_id
JOIN rental r           ON i.inventory_id = r.inventory_id
JOIN payment p          ON r.rental_id = p.rental_id
GROUP BY c.name
ORDER BY total_rentals DESC;


-- ============================================================
-- Q3. Are there correlations between staff performance and customer satisfaction?
-- ============================================================

-- Staff rental volume and revenue
SELECT
    s.staff_id,
    s.first_name || ' ' || s.last_name     AS staff_name,
    s.store_id,
    COUNT(r.rental_id)                      AS total_rentals_handled,
    ROUND(SUM(p.amount), 2)                AS total_revenue_collected,
    ROUND(AVG(p.amount), 2)                AS avg_transaction_value,
    COUNT(DISTINCT r.customer_id)           AS unique_customers_served
FROM staff s
JOIN rental r   ON s.staff_id = r.staff_id
JOIN payment p  ON r.rental_id = p.rental_id
GROUP BY s.staff_id, s.first_name, s.last_name, s.store_id
ORDER BY total_rentals_handled DESC;

-- Staff performance by month
SELECT
    s.first_name || ' ' || s.last_name     AS staff_name,
    TO_CHAR(r.rental_date, 'YYYY-MM')      AS month,
    COUNT(r.rental_id)                      AS rentals_handled,
    ROUND(SUM(p.amount), 2)                AS revenue_collected
FROM staff s
JOIN rental r   ON s.staff_id = r.staff_id
JOIN payment p  ON r.rental_id = p.rental_id
GROUP BY s.first_name, s.last_name, TO_CHAR(r.rental_date, 'YYYY-MM')
ORDER BY staff_name, month;

-- Repeat customers per staff (loyalty indicator)
SELECT
    s.first_name || ' ' || s.last_name     AS staff_name,
    COUNT(DISTINCT r.customer_id)           AS customers_served,
    COUNT(r.rental_id)                      AS total_rentals,
    ROUND(COUNT(r.rental_id) * 1.0 /
        COUNT(DISTINCT r.customer_id), 2)  AS avg_rentals_per_customer
FROM staff s
JOIN rental r ON s.staff_id = r.staff_id
GROUP BY s.staff_id, s.first_name, s.last_name;


-- ============================================================
-- Q4. Are there seasonal trends in customer behavior across different locations?
-- ============================================================

-- Monthly rental trends overall
SELECT
    TO_CHAR(rental_date, 'YYYY-MM')        AS month,
    TO_CHAR(rental_date, 'Month')          AS month_name,
    COUNT(rental_id)                        AS total_rentals,
    ROUND(SUM(p.amount), 2)               AS total_revenue
FROM rental r
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY TO_CHAR(rental_date, 'YYYY-MM'), TO_CHAR(rental_date, 'Month')
ORDER BY month;

-- Seasonal trends by store location
SELECT
    st.store_id,
    ci.city                                AS store_city,
    co.country                             AS store_country,
    TO_CHAR(r.rental_date, 'YYYY-MM')     AS month,
    COUNT(r.rental_id)                     AS total_rentals,
    ROUND(SUM(p.amount), 2)               AS revenue
FROM rental r
JOIN payment p          ON r.rental_id = p.rental_id
JOIN inventory i        ON r.inventory_id = i.inventory_id
JOIN store st           ON i.store_id = st.store_id
JOIN address a          ON st.address_id = a.address_id
JOIN city ci            ON a.city_id = ci.city_id
JOIN country co         ON ci.country_id = co.country_id
GROUP BY st.store_id, ci.city, co.country, TO_CHAR(r.rental_date, 'YYYY-MM')
ORDER BY st.store_id, month;

-- Day of week rental patterns
SELECT
    TO_CHAR(rental_date, 'Day')            AS day_of_week,
    EXTRACT(DOW FROM rental_date)          AS day_num,
    COUNT(rental_id)                        AS total_rentals
FROM rental
GROUP BY TO_CHAR(rental_date, 'Day'), EXTRACT(DOW FROM rental_date)
ORDER BY day_num;


-- ============================================================
-- Q5. Are certain language films more popular among specific customer segments?
-- ============================================================

-- Rentals by film language
SELECT
    l.name                                  AS language,
    COUNT(r.rental_id)                      AS total_rentals,
    ROUND(SUM(p.amount), 2)                AS total_revenue,
    COUNT(DISTINCT r.customer_id)           AS unique_customers
FROM language l
JOIN film f         ON l.language_id = f.language_id
JOIN inventory i    ON f.film_id = i.film_id
JOIN rental r       ON i.inventory_id = r.inventory_id
JOIN payment p      ON r.rental_id = p.rental_id
GROUP BY l.name
ORDER BY total_rentals DESC;

-- Language popularity by customer segment
WITH customer_segments AS (
    SELECT
        customer_id,
        CASE
            WHEN COUNT(*) <= 20 THEN 'Low Frequency'
            WHEN COUNT(*) <= 30 THEN 'Medium Frequency'
            ELSE 'High Frequency'
        END AS segment
    FROM rental
    GROUP BY customer_id
)
SELECT
    cs.segment,
    l.name                                  AS language,
    COUNT(r.rental_id)                      AS total_rentals
FROM rental r
JOIN customer_segments cs   ON r.customer_id = cs.customer_id
JOIN inventory i            ON r.inventory_id = i.inventory_id
JOIN film f                 ON i.film_id = f.film_id
JOIN language l             ON f.language_id = l.language_id
GROUP BY cs.segment, l.name
ORDER BY cs.segment, total_rentals DESC;


-- ============================================================
-- Q6. How does customer loyalty impact sales revenue over time?
-- ============================================================

-- Lifetime value by customer
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name     AS customer_name,
    COUNT(r.rental_id)                      AS total_rentals,
    ROUND(SUM(p.amount), 2)                AS lifetime_value,
    MIN(r.rental_date)                      AS first_rental_date,
    MAX(r.rental_date)                      AS last_rental_date,
    EXTRACT(DAY FROM MAX(r.rental_date)
        - MIN(r.rental_date))              AS days_active
FROM customer c
JOIN rental r   ON c.customer_id = r.customer_id
JOIN payment p  ON r.rental_id = p.rental_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY lifetime_value DESC
LIMIT 20;

-- Revenue by loyalty tier
WITH loyalty AS (
    SELECT
        r.customer_id,
        COUNT(r.rental_id)                  AS total_rentals,
        ROUND(SUM(p.amount), 2)            AS total_spent,
        CASE
            WHEN COUNT(r.rental_id) <= 20 THEN 'Bronze (1-20)'
            WHEN COUNT(r.rental_id) <= 30 THEN 'Silver (21-30)'
            ELSE 'Gold (31+)'
        END AS loyalty_tier
    FROM rental r
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY r.customer_id
)
SELECT
    loyalty_tier,
    COUNT(*)                                AS customers,
    ROUND(AVG(total_rentals), 2)           AS avg_rentals,
    ROUND(AVG(total_spent), 2)             AS avg_spent,
    ROUND(SUM(total_spent), 2)             AS total_revenue,
    ROUND(100.0 * SUM(total_spent) /
        SUM(SUM(total_spent)) OVER(), 2)   AS revenue_pct
FROM loyalty
GROUP BY loyalty_tier
ORDER BY avg_spent DESC;


-- ============================================================
-- Q7. Are certain film categories more popular in specific locations?
-- ============================================================

-- Category popularity by country
SELECT
    co.country,
    cat.name                                AS category,
    COUNT(r.rental_id)                      AS total_rentals
FROM rental r
JOIN customer cu        ON r.customer_id = cu.customer_id
JOIN address a          ON cu.address_id = a.address_id
JOIN city ci            ON a.city_id = ci.city_id
JOIN country co         ON ci.country_id = co.country_id
JOIN inventory i        ON r.inventory_id = i.inventory_id
JOIN film_category fc   ON i.film_id = fc.film_id
JOIN category cat       ON fc.category_id = cat.category_id
GROUP BY co.country, cat.name
ORDER BY co.country, total_rentals DESC;

-- Top category per store
SELECT
    i.store_id,
    cat.name                                AS top_category,
    COUNT(r.rental_id)                      AS total_rentals
FROM rental r
JOIN inventory i        ON r.inventory_id = i.inventory_id
JOIN film_category fc   ON i.film_id = fc.film_id
JOIN category cat       ON fc.category_id = cat.category_id
GROUP BY i.store_id, cat.name
ORDER BY i.store_id, total_rentals DESC;


-- ============================================================
-- Q8. How does staff knowledge affect customer ratings?
-- ============================================================
-- Note: No direct rating column exists; we use payment amount
-- and rental frequency as satisfaction proxies

-- Staff impact on customer return rate
SELECT
    s.first_name || ' ' || s.last_name     AS staff_name,
    COUNT(DISTINCT r.customer_id)           AS unique_customers,
    COUNT(r.rental_id)                      AS total_rentals,
    ROUND(COUNT(r.rental_id) * 1.0 /
        NULLIF(COUNT(DISTINCT r.customer_id), 0), 2) AS rentals_per_customer,
    ROUND(AVG(p.amount), 2)                AS avg_payment
FROM staff s
JOIN rental r   ON s.staff_id = r.staff_id
JOIN payment p  ON r.rental_id = p.rental_id
GROUP BY s.staff_id, s.first_name, s.last_name;

-- Film rating preference handled by each staff member
SELECT
    s.first_name || ' ' || s.last_name     AS staff_name,
    f.rating                                AS film_rating,
    COUNT(r.rental_id)                      AS rentals
FROM staff s
JOIN rental r       ON s.staff_id = r.staff_id
JOIN inventory i    ON r.inventory_id = i.inventory_id
JOIN film f         ON i.film_id = f.film_id
GROUP BY s.first_name, s.last_name, f.rating
ORDER BY staff_name, rentals DESC;


-- ============================================================
-- Q9. How does proximity of stores to customers impact rental frequency?
-- ============================================================

-- Customers renting from their home store vs other store
SELECT
    cu.customer_id,
    cu.first_name || ' ' || cu.last_name   AS customer_name,
    cu.store_id                             AS home_store,
    i.store_id                             AS rented_from_store,
    CASE
        WHEN cu.store_id = i.store_id THEN 'Home Store'
        ELSE 'Other Store'
    END                                     AS store_match,
    COUNT(r.rental_id)                      AS total_rentals
FROM customer cu
JOIN rental r       ON cu.customer_id = r.customer_id
JOIN inventory i    ON r.inventory_id = i.inventory_id
GROUP BY cu.customer_id, cu.first_name, cu.last_name, cu.store_id, i.store_id
ORDER BY cu.customer_id;

-- Summary: home store vs other store rentals
SELECT
    CASE
        WHEN cu.store_id = i.store_id THEN 'Home Store'
        ELSE 'Other Store'
    END                                     AS store_type,
    COUNT(r.rental_id)                      AS total_rentals,
    COUNT(DISTINCT r.customer_id)           AS unique_customers,
    ROUND(AVG(p.amount), 2)                AS avg_payment
FROM customer cu
JOIN rental r       ON cu.customer_id = r.customer_id
JOIN inventory i    ON r.inventory_id = i.inventory_id
JOIN payment p      ON r.rental_id = p.rental_id
GROUP BY store_type;


-- ============================================================
-- Q10. Do specific film categories attract different age groups?
-- ============================================================
-- Note: No age column in dataset; use customer_id ranges and
-- account creation date as a proxy for customer cohorts

-- Category rentals by customer cohort (store-based segmentation)
SELECT
    cu.store_id                             AS customer_store,
    cat.name                                AS category,
    COUNT(r.rental_id)                      AS total_rentals,
    ROUND(SUM(p.amount), 2)                AS total_spent
FROM customer cu
JOIN rental r           ON cu.customer_id = r.customer_id
JOIN payment p          ON r.rental_id = p.rental_id
JOIN inventory i        ON r.inventory_id = i.inventory_id
JOIN film_category fc   ON i.film_id = fc.film_id
JOIN category cat       ON fc.category_id = cat.category_id
GROUP BY cu.store_id, cat.name
ORDER BY cu.store_id, total_rentals DESC;

-- Film rating preference by store (rating as audience age proxy)
SELECT
    cu.store_id,
    f.rating,
    COUNT(r.rental_id)                      AS total_rentals,
    ROUND(100.0 * COUNT(r.rental_id) /
        SUM(COUNT(r.rental_id)) OVER
        (PARTITION BY cu.store_id), 2)      AS pct_of_store_rentals
FROM customer cu
JOIN rental r       ON cu.customer_id = r.customer_id
JOIN inventory i    ON r.inventory_id = i.inventory_id
JOIN film f         ON i.film_id = f.film_id
GROUP BY cu.store_id, f.rating
ORDER BY cu.store_id, total_rentals DESC;


-- ============================================================
-- Q11. What are the demographics and preferences of highest-spending customers?
-- ============================================================

-- Top 20 highest spending customers with preferences
WITH top_customers AS (
    SELECT
        p.customer_id,
        ROUND(SUM(p.amount), 2)            AS total_spent,
        COUNT(p.payment_id)                 AS total_transactions
    FROM payment p
    GROUP BY p.customer_id
    ORDER BY total_spent DESC
    LIMIT 20
)
SELECT
    tc.customer_id,
    cu.first_name || ' ' || cu.last_name   AS customer_name,
    ci.city,
    co.country,
    cu.store_id,
    tc.total_spent,
    tc.total_transactions,
    ROUND(tc.total_spent / tc.total_transactions, 2) AS avg_per_transaction
FROM top_customers tc
JOIN customer cu    ON tc.customer_id = cu.customer_id
JOIN address a      ON cu.address_id = a.address_id
JOIN city ci        ON a.city_id = ci.city_id
JOIN country co     ON ci.country_id = co.country_id
ORDER BY tc.total_spent DESC;

-- Favourite category of top spenders
WITH top_customers AS (
    SELECT customer_id
    FROM payment
    GROUP BY customer_id
    ORDER BY SUM(amount) DESC
    LIMIT 20
)
SELECT
    cat.name                                AS favourite_category,
    COUNT(r.rental_id)                      AS rentals_by_top_customers
FROM top_customers tc
JOIN rental r           ON tc.customer_id = r.customer_id
JOIN inventory i        ON r.inventory_id = i.inventory_id
JOIN film_category fc   ON i.film_id = fc.film_id
JOIN category cat       ON fc.category_id = cat.category_id
GROUP BY cat.name
ORDER BY rentals_by_top_customers DESC;


-- ============================================================
-- Q12. How does inventory availability impact customer satisfaction?
-- ============================================================

-- Films with most inventory copies vs rental demand
SELECT
    f.title,
    COUNT(DISTINCT i.inventory_id)          AS total_copies,
    COUNT(r.rental_id)                      AS total_rentals,
    ROUND(COUNT(r.rental_id) * 1.0 /
        NULLIF(COUNT(DISTINCT i.inventory_id), 0), 2) AS rentals_per_copy
FROM film f
JOIN inventory i    ON f.film_id = i.film_id
LEFT JOIN rental r  ON i.inventory_id = r.inventory_id
GROUP BY f.film_id, f.title
ORDER BY rentals_per_copy DESC
LIMIT 15;

-- Films with low inventory but high demand (stock-out risk)
SELECT
    f.title,
    COUNT(DISTINCT i.inventory_id)          AS stock,
    COUNT(r.rental_id)                      AS demand,
    ROUND(COUNT(r.rental_id) * 1.0 /
        NULLIF(COUNT(DISTINCT i.inventory_id), 0), 2) AS demand_per_copy
FROM film f
JOIN inventory i    ON f.film_id = i.film_id
JOIN rental r       ON i.inventory_id = r.inventory_id
GROUP BY f.film_id, f.title
HAVING COUNT(DISTINCT i.inventory_id) <= 3
ORDER BY demand_per_copy DESC
LIMIT 15;

-- Unreturned rentals (currently out / overdue)
SELECT
    COUNT(*)                                AS unreturned_rentals,
    COUNT(DISTINCT customer_id)             AS customers_with_unreturned
FROM rental
WHERE return_date IS NULL;


-- ============================================================
-- Q13. What are the busiest hours/days for each store?
-- ============================================================

-- Busiest hours by store
SELECT
    i.store_id,
    EXTRACT(HOUR FROM r.rental_date)        AS hour_of_day,
    COUNT(r.rental_id)                      AS total_rentals
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
GROUP BY i.store_id, EXTRACT(HOUR FROM r.rental_date)
ORDER BY i.store_id, total_rentals DESC;

-- Busiest days of week by store
SELECT
    i.store_id,
    TO_CHAR(r.rental_date, 'Day')          AS day_of_week,
    EXTRACT(DOW FROM r.rental_date)         AS day_num,
    COUNT(r.rental_id)                      AS total_rentals
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
GROUP BY i.store_id, TO_CHAR(r.rental_date, 'Day'), EXTRACT(DOW FROM r.rental_date)
ORDER BY i.store_id, total_rentals DESC;

-- Peak month per store
SELECT
    i.store_id,
    TO_CHAR(r.rental_date, 'YYYY-MM')      AS month,
    COUNT(r.rental_id)                      AS total_rentals,
    ROUND(SUM(p.amount), 2)                AS revenue
FROM rental r
JOIN payment p      ON r.rental_id = p.rental_id
JOIN inventory i    ON r.inventory_id = i.inventory_id
GROUP BY i.store_id, TO_CHAR(r.rental_date, 'YYYY-MM')
ORDER BY i.store_id, total_rentals DESC;


-- ============================================================
-- Q14. Cultural/demographic factors influencing customer preferences
-- ============================================================

-- Category preferences by country
SELECT
    co.country,
    cat.name                                AS category,
    COUNT(r.rental_id)                      AS total_rentals,
    ROUND(100.0 * COUNT(r.rental_id) /
        SUM(COUNT(r.rental_id)) OVER
        (PARTITION BY co.country), 2)       AS pct_of_country_rentals
FROM rental r
JOIN customer cu        ON r.customer_id = cu.customer_id
JOIN address a          ON cu.address_id = a.address_id
JOIN city ci            ON a.city_id = ci.city_id
JOIN country co         ON ci.country_id = co.country_id
JOIN inventory i        ON r.inventory_id = i.inventory_id
JOIN film_category fc   ON i.film_id = fc.film_id
JOIN category cat       ON fc.category_id = cat.category_id
GROUP BY co.country, cat.name
ORDER BY co.country, total_rentals DESC;

-- Top 10 countries by rental volume
SELECT
    co.country,
    COUNT(r.rental_id)                      AS total_rentals,
    COUNT(DISTINCT r.customer_id)           AS unique_customers,
    ROUND(SUM(p.amount), 2)                AS total_revenue
FROM rental r
JOIN payment p          ON r.rental_id = p.rental_id
JOIN customer cu        ON r.customer_id = cu.customer_id
JOIN address a          ON cu.address_id = a.address_id
JOIN city ci            ON a.city_id = ci.city_id
JOIN country co         ON ci.country_id = co.country_id
GROUP BY co.country
ORDER BY total_rentals DESC
LIMIT 10;


-- ============================================================
-- Q15. How does availability of films in different languages
--      impact customer satisfaction and rental frequency?
-- ============================================================

-- Language availability vs rental frequency
SELECT
    l.name                                  AS language,
    COUNT(DISTINCT f.film_id)               AS films_available,
    COUNT(DISTINCT i.inventory_id)          AS total_copies,
    COUNT(r.rental_id)                      AS total_rentals,
    COUNT(DISTINCT r.customer_id)           AS unique_customers,
    ROUND(SUM(p.amount), 2)                AS total_revenue,
    ROUND(COUNT(r.rental_id) * 1.0 /
        NULLIF(COUNT(DISTINCT f.film_id), 0), 2) AS rentals_per_film
FROM language l
JOIN film f         ON l.language_id = f.language_id
JOIN inventory i    ON f.film_id = i.film_id
LEFT JOIN rental r  ON i.inventory_id = r.inventory_id
LEFT JOIN payment p ON r.rental_id = p.rental_id
GROUP BY l.name
ORDER BY total_rentals DESC;

-- Customer retention by language preference
WITH customer_lang AS (
    SELECT
        r.customer_id,
        l.name                              AS preferred_language,
        COUNT(r.rental_id)                  AS rentals
    FROM rental r
    JOIN inventory i    ON r.inventory_id = i.inventory_id
    JOIN film f         ON i.film_id = f.film_id
    JOIN language l     ON f.language_id = l.language_id
    GROUP BY r.customer_id, l.name
)
SELECT
    preferred_language,
    COUNT(DISTINCT customer_id)             AS customers,
    ROUND(AVG(rentals), 2)                 AS avg_rentals_per_customer,
    SUM(rentals)                            AS total_rentals
FROM customer_lang
GROUP BY preferred_language
ORDER BY total_rentals DESC;


-- ============================================================
-- END OF ALL 15 EDA QUERIES
-- ============================================================













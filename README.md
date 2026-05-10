# 🎬 Movie Rental EDA — SQL Exploratory Data Analysis

> A comprehensive Exploratory Data Analysis (EDA) on a Movie Rental database using **PostgreSQL**, covering customer behavior, film performance, staff productivity, inventory health, and geographic trends.

---

## 📌 Project Overview

This project answers **14 business questions** using structured SQL queries on a relational movie rental dataset. The analysis explores customer purchasing patterns, loyalty segments, seasonal trends, staff performance, inventory management, and location-based preferences.

**Tools Used:** PostgreSQL 18 · Excel (source data) · SQL CTEs & Window Functions

---

## 🗂️ Repository Structure

```
movie_rental_eda/
│
├── data/
│   └── MOVIE_RENTAL_DATA.xlsx      # Raw dataset (all tables)
│
├── sql/
│   └── Movie_Rental_EDA.sql        # All EDA queries (DDL + 14 questions)
│
├── docs/
│   └── schema_diagram.md           # Database schema description
│
└── README.md
```

---

## 🗃️ Database Schema

The dataset consists of **15 relational tables**:

| Table | Description |
|---|---|
| `customer` | Customer info: name, email, store, address |
| `rental` | Rental transactions with dates and inventory IDs |
| `payment` | Payment amounts linked to rentals |
| `film` | Film metadata: title, rating, language, rental rate |
| `inventory` | Copies of films held at each store |
| `store` | Store location and manager info |
| `staff` | Staff members associated with stores |
| `category` | Film genre categories |
| `film_category` | Many-to-many: films ↔ categories |
| `film_actor` | Many-to-many: films ↔ actors |
| `actor` | Actor names |
| `language` | Film language reference |
| `address` | Address lookup table |
| `city` | City reference (linked to address) |
| `country` | Country reference (linked to city) |

---

## ❓ EDA Questions & Key Insights

### Q1 — Purchasing Patterns: New vs Repeat Customers
- Customers segmented into **Low (1–20)**, **Medium (21–30)**, and **High Frequency (31+)** tiers.
- High-frequency customers drive disproportionate revenue despite being fewer in number.
- Average days between rentals calculated using window functions (`LAG`).

### Q2 — Films with Highest Rental Rates & Demand
- Top 10 most rented films identified with revenue contribution.
- Rental rate tiers analyzed against total demand and average payment.
- Category-level demand ranking (e.g., Sports, Animation, Action).

### Q3 — Staff Performance vs Customer Satisfaction
- Staff compared on: rentals handled, revenue collected, unique customers served.
- Monthly performance trend tracked per staff member.
- Rentals-per-customer ratio used as a loyalty/satisfaction proxy.

### Q4 — Seasonal Trends by Location
- Monthly rental volume and revenue tracked overall and per store.
- Day-of-week patterns identified to understand peak traffic days.

### Q5 — Language Film Popularity by Customer Segment
- Rental volume and revenue broken down by film language.
- Language preference cross-tabulated with customer frequency segments.

### Q6 — Customer Loyalty Impact on Revenue
- Loyalty tiers: **Bronze (1–20)**, **Silver (21–30)**, **Gold (31+)** rentals.
- Lifetime value (LTV) calculated per customer with days-active span.
- Revenue share % calculated per loyalty tier using window functions.

### Q7 — Film Category Popularity by Location
- Category rentals grouped by customer country and store.
- Top category per store surfaced using ordered aggregation.

### Q8 — Staff Knowledge & Customer Ratings
- No direct rating column — proxied using payment amounts and repeat-rental frequency.
- Film rating preference (G, PG, R, etc.) tracked per staff member.

### Q9 — Store Proximity & Rental Frequency
- Customers classified as renting from **Home Store** vs **Other Store**.
- Summary shows rental volume, unique customer count, and avg payment by store type.

### Q10 — Film Categories & Age Group Preferences
- No age column — film MPAA **rating** (G/PG/PG-13/R/NC-17) used as audience age proxy.
- Category and rating breakdown by store and customer cohort.

### Q11 — Demographics of Highest-Spending Customers
- Top 20 spenders profiled with city, country, store, and average transaction value.
- Favourite film categories of top spenders identified.

### Q12 — Inventory Availability & Customer Satisfaction
- Rentals-per-copy ratio computed to find high-demand, low-stock films.
- Stock-out risk flagged for films with ≤ 3 copies but high demand.
- Unreturned/overdue rentals counted.

### Q13 — Busiest Hours & Days by Store
- Hour-of-day and day-of-week rental volumes broken down per store.
- Peak months identified to support staffing decisions.

### Q14 — Cultural/Demographic Factors in Customer Preferences
- Category preference percentage computed per country using `OVER (PARTITION BY)`.
- Top 10 countries by rental volume and revenue ranked.

---

## ⚙️ How to Run

1. **Set up PostgreSQL** (v13+ recommended, queries tested on v18).
2. **Create the database:**
   ```sql
   CREATE DATABASE movie_rental;
   ```
3. **Run the SQL file:**
   ```bash
   psql -U your_username -d movie_rental -f sql/Movie_Rental_EDA.sql
   ```
   This will:
   - Create all 15 tables (DDL at the top of the file)
   - Execute all 14 EDA question queries

4. **Load the data** from `data/MOVIE_RENTAL_DATA.xlsx` using your preferred ETL method (e.g., Python `pandas` + `SQLAlchemy`, or pgAdmin import).

---

## 🧠 SQL Techniques Used

- **CTEs** (`WITH` clauses) for multi-step logic
- **Window Functions** (`LAG`, `OVER PARTITION BY`, `SUM OVER`) for rankings and comparisons
- **CASE WHEN** segmentation for loyalty tiers and store matching
- **LEFT JOIN** for inventory availability analysis
- **EXTRACT / TO_CHAR** for time-based trend analysis
- **NULLIF / GREATEST** for safe division

---

## 📊 Sample Query — Loyalty Tier Revenue Breakdown

```sql
WITH loyalty AS (
    SELECT
        r.customer_id,
        COUNT(r.rental_id) AS total_rentals,
        ROUND(SUM(p.amount), 2) AS total_spent,
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
    COUNT(*) AS customers,
    ROUND(AVG(total_spent), 2) AS avg_spent,
    ROUND(SUM(total_spent), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_spent) / SUM(SUM(total_spent)) OVER(), 2) AS revenue_pct
FROM loyalty
GROUP BY loyalty_tier
ORDER BY avg_spent DESC;
```

---

## 👤 Author

**Rishabh Pandey**
- GitHub: [@rishabh8942](https://github.com/rishabh8942)
- LinkedIn: [rishabh-pandey2410](https://www.linkedin.com/in/rishabh-pandey2410)

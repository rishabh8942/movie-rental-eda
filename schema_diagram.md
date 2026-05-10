# Database Schema — Movie Rental EDA

## Entity Relationship Overview

```
country ──< city ──< address ──< customer ──< rental >── inventory >── film >── film_category >── category
                                                  │                               │
                                               payment                        film_actor
                                                  │                               │
                                               staff                           actor
                                               store
```

## Table Descriptions

### Core Tables
- **`film`** — Central table with title, rental_rate, rating, language_id, length, etc.
- **`inventory`** — Each physical copy of a film at a given store
- **`rental`** — Each rental transaction (customer borrows an inventory item)
- **`payment`** — Payment made for each rental

### People
- **`customer`** — Registered customers with home store and address
- **`staff`** — Store employees who handle rentals
- **`actor`** — Actors in films

### Location
- **`store`** — Physical store locations
- **`address`** — Street addresses for customers/stores/staff
- **`city`** — Cities
- **`country`** — Countries

### Classification
- **`category`** — Film genres (Action, Comedy, Horror, etc.)
- **`language`** — Film languages
- **`film_category`** — Junction table: film ↔ category (many-to-many)
- **`film_actor`** — Junction table: film ↔ actor (many-to-many)
- **`film_text`** — Full-text searchable title + description

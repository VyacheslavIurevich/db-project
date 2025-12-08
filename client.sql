-- 1. Отчет по клиентам с их общими расходами (GROUP BY с HAVING)
SELECT
    c.client_id,
    c.country_iso,
    CONCAT(c.first_name, ' ', c.last_name) AS client_name,
    COUNT(b.booking_id) AS total_bookings,
    SUM(b.total_amount) AS total_spent,
    MAX(b.check_in_date) AS last_visit,
    (
        SELECT COUNT(*) FROM booked_services AS bs
        INNER JOIN bookings AS b2 ON bs.booking_id = b2.booking_id
        WHERE b2.client_id = c.client_id
    ) AS total_services_ordered
FROM clients AS c
LEFT JOIN bookings AS b
    ON
        c.client_id = b.client_id
        AND b.booking_status IN ('confirmed', 'completed')
GROUP BY c.client_id, c.first_name, c.last_name, c.country_iso
HAVING total_spent > 20000
ORDER BY total_spent DESC;

-- 2. Анализ загруженности номеров по месяцам (сложная агрегация)
SELECT
    rc.category_name,
    MONTH(b.check_in_date) AS booking_month,
    YEAR(b.check_in_date) AS booking_year,
    COUNT(b.booking_id) AS bookings_count,
    SUM(DATEDIFF(b.check_out_date, b.check_in_date)) AS occupied_nights,
    ROUND(
        COUNT(b.booking_id)
        * 100.0
        / SUM(COUNT(b.booking_id)) OVER (PARTITION BY MONTH(b.check_in_date)),
        2
    ) AS monthly_percentage
FROM bookings AS b
INNER JOIN rooms AS r ON b.room_id = r.room_id
INNER JOIN room_categories AS rc ON r.category_id = rc.category_id
WHERE b.booking_status IN ('confirmed', 'completed')
GROUP BY rc.category_name, YEAR(b.check_in_date), MONTH(b.check_in_date)
ORDER BY booking_year DESC, booking_month DESC, occupied_nights DESC;

-- 3. Поиск сотрудников для назначения на услугу (использование UNION)
SELECT
    s.staff_id,
    CONCAT(s.first_name, ' ', s.last_name) AS staff_name,
    sp.position_name,
    'Основная должность' AS assignment_type,
    COUNT(bs.booking_service_id) AS completed_services
FROM staff AS s
INNER JOIN staff_positions AS sp ON s.position_id = sp.position_id
LEFT JOIN booked_services AS bs ON s.staff_id = bs.assigned_staff_id
WHERE
    sp.position_id
    = (
        SELECT responsible_position_id FROM services
        WHERE service_name = 'SPA-процедуры'
    )
    AND s.is_active = TRUE
GROUP BY s.staff_id, s.first_name, s.last_name, sp.position_name

UNION DISTINCT

SELECT
    s.staff_id,
    CONCAT(s.first_name, ' ', s.last_name) AS staff_name,
    sp.position_name,
    'Запасной' AS assignment_type,
    COUNT(bs.booking_service_id) AS completed_services
FROM staff AS s
INNER JOIN staff_positions AS sp ON s.position_id = sp.position_id
LEFT JOIN booked_services AS bs ON s.staff_id = bs.assigned_staff_id
WHERE
    sp.position_name IN ('Менеджер', 'Консьерж')
    AND s.is_active = TRUE
    AND s.staff_id NOT IN (
        SELECT staff_id FROM staff
        WHERE
            position_id = (
                SELECT responsible_position_id FROM services
                WHERE service_name = 'SPA-процедуры'
            )
    )
GROUP BY s.staff_id, s.first_name, s.last_name, sp.position_name
ORDER BY completed_services DESC;

-- 4. Отчет по услугам с детализацией (многоуровневая агрегация)
SELECT
    s.service_name,
    s.price,
    COUNT(bs.booking_service_id) AS total_orders,
    SUM(bs.quantity) AS total_quantity,
    SUM(bs.total_service_price) AS total_revenue,
    ROUND(AVG(bs.total_service_price), 2) AS avg_order_value,
    (
        SELECT CONCAT(first_name, ' ', last_name)
        FROM staff
        WHERE staff_id = (
            SELECT assigned_staff_id
            FROM booked_services AS bs2
            WHERE bs2.service_id = s.service_id
            GROUP BY assigned_staff_id
            ORDER BY COUNT(*) DESC
            LIMIT 1
        )
    ) AS most_active_staff
FROM services AS s
LEFT JOIN booked_services AS bs ON s.service_id = bs.service_id
GROUP BY s.service_id, s.service_name, s.price
HAVING total_orders > 0
ORDER BY total_revenue DESC;

-- 5. Анализ отмененных бронирований (LEFT JOIN с фильтрацией)
SELECT
    c.client_id,
    CONCAT(c.first_name, ' ', c.last_name) AS client_name,
    COUNT(b.booking_id) AS total_bookings,
    SUM(CASE WHEN b.booking_status = 'cancelled' THEN 1 ELSE 0 END)
        AS cancelled_count,
    ROUND(
        SUM(CASE WHEN b.booking_status = 'cancelled' THEN 1 ELSE 0 END)
        * 100.0
        / COUNT(b.booking_id),
        2
    ) AS cancellation_rate,
    GROUP_CONCAT(
        DISTINCT
        CASE
            WHEN b.booking_status = 'cancelled' THEN
                CONCAT('№', b.booking_id, ' (', b.check_in_date, ')')
        END
        SEPARATOR ', '
    ) AS cancelled_booking_ids
FROM clients AS c
LEFT JOIN bookings AS b ON c.client_id = b.client_id
WHERE b.booking_id IS NOT NULL
GROUP BY c.client_id, c.first_name, c.last_name
HAVING cancelled_count > 0
ORDER BY cancellation_rate DESC;

-- 6. Поиск дублирующихся контактов клиентов (самосоединение)
SELECT
    c1.client_id AS id1,
    c1.email AS email1,
    c1.phone AS phone1,
    c2.client_id AS id2,
    c2.email AS email2,
    c2.phone AS phone2,
    CONCAT(c1.first_name, ' ', c1.last_name) AS name1,
    CONCAT(c2.first_name, ' ', c2.last_name) AS name2,
    CASE
        WHEN c1.email = c2.email THEN 'Duplicate email'
        WHEN c1.phone = c2.phone THEN 'Duplicate phone'
        WHEN c1.passport_number = c2.passport_number THEN 'Duplicate passport'
    END AS duplicate_type
FROM clients AS c1
INNER JOIN clients AS c2
    ON
        (
            c1.email = c2.email
            OR c1.phone = c2.phone
            OR c1.passport_number = c2.passport_number
        )
        AND c1.client_id < c2.client_id
ORDER BY duplicate_type;

-- 7. Анализ сезонности (оконные функции)
SELECT
    month_year,
    total_bookings,
    total_revenue,
    ROUND(
        AVG(total_bookings)
            OVER (ORDER BY month_year ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
        1
    ) AS moving_avg_3months,
    ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER (), 2)
        AS revenue_percentage,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM (
    SELECT
        DATE_FORMAT(check_in_date, '%Y-%m') AS month_year,
        COUNT(*) AS total_bookings,
        SUM(total_amount) AS total_revenue
    FROM bookings
    WHERE booking_status IN ('confirmed', 'completed')
    GROUP BY DATE_FORMAT(check_in_date, '%Y-%m')
) AS monthly_stats
ORDER BY month_year;

-- 8. Поиск доступных номеров на заданные даты (с использованием подзапроса в SELECT)
SELECT
    r.room_id,
    r.room_number,
    rc.category_name,
    rc.base_price_per_night,
    rc.max_occupancy,
    r.floor,
    r.has_balcony,
    CALCULATEBOOKINGCOST(r.room_id, '2024-04-01', '2024-04-05') AS total_cost,
    (
        SELECT COUNT(*) FROM bookings AS b
        WHERE
            b.room_id = r.room_id
            AND b.booking_status IN ('confirmed', 'completed')
    ) AS previous_bookings
FROM rooms AS r
INNER JOIN room_categories AS rc ON r.category_id = rc.category_id
WHERE
    r.room_status = 'available'
    AND ISROOMAVAILABLE(r.room_id, '2024-04-01', '2024-04-05')
ORDER BY rc.base_price_per_night;

-- 9. Получение активных бронирований для клиента
SELECT
    b.*,
    r.room_number,
    rc.category_name
FROM bookings AS b
INNER JOIN rooms AS r ON b.room_id = r.room_id
INNER JOIN room_categories AS rc ON r.category_id = rc.category_id
WHERE
    b.client_id = 1
    AND b.booking_status = 'confirmed'
    AND b.check_in_date >= CURDATE()
ORDER BY b.check_in_date;

-- 10. Получение списка услуг для бронирования
SELECT
    s.*,
    sp.position_name AS responsible_position
FROM services AS s
INNER JOIN staff_positions AS sp ON s.responsible_position_id = sp.position_id
WHERE s.is_available = TRUE
ORDER BY s.price;

-- 11. Поиск свободных номеров по категориям
SELECT
    rc.category_name,
    COUNT(r.room_id) AS total_rooms,
    SUM(CASE WHEN r.room_status = 'available' THEN 1 ELSE 0 END)
        AS available_rooms,
    MIN(rc.base_price_per_night) AS min_price,
    MAX(rc.base_price_per_night) AS max_price
FROM room_categories AS rc
INNER JOIN rooms AS r ON rc.category_id = r.category_id
GROUP BY rc.category_id, rc.category_name
HAVING available_rooms > 0
ORDER BY min_price;

-- 12. Получение информации о бронировании для отображения клиенту
SELECT
    b.booking_id,
    b.booking_status,
    r.room_number,
    rc.category_name,
    b.total_amount,
    c.phone,
    c.email,
    DATE_FORMAT(b.check_in_date, '%d.%m.%Y') AS check_in,
    DATE_FORMAT(b.check_out_date, '%d.%m.%Y') AS check_out,
    DATEDIFF(b.check_out_date, b.check_in_date) AS nights,
    CONCAT(c.first_name, ' ', c.last_name) AS client_name,
    COALESCE((
        SELECT GROUP_CONCAT(CONCAT(s.service_name, ' (', bs.quantity, ')') SEPARATOR ', ')
        FROM booked_services AS bs
        INNER JOIN services AS s ON bs.service_id = s.service_id
        WHERE bs.booking_id = b.booking_id
    ), 'Нет услуг') AS services,
    b.total_amount + COALESCE((
        SELECT SUM(total_service_price)
        FROM booked_services
        WHERE booking_id = b.booking_id
    ), 0) AS total_with_services
FROM bookings AS b
INNER JOIN rooms AS r ON b.room_id = r.room_id
INNER JOIN room_categories AS rc ON r.category_id = rc.category_id
INNER JOIN clients AS c ON b.client_id = c.client_id
WHERE b.client_id = 1
ORDER BY b.check_in_date DESC;

-- ТЕСТИРОВАНИЕ ФУНКЦИЙ:

-- 1. Тестирование функции расчета стоимости бронирования
SELECT
    room_id,
    room_number,
    CALCULATEBOOKINGCOST(room_id, '2024-04-01', '2024-04-05') AS estimated_cost
FROM rooms
WHERE room_status = 'available'
LIMIT 5;

-- 2. Тестирование функции проверки доступности номера
SELECT
    room_id,
    room_number,
    room_status,
    ISROOMAVAILABLE(room_id, '2024-04-01', '2024-04-05') AS is_available
FROM rooms
WHERE room_id IN (1, 2, 5)
LIMIT 5;

-- ТЕСТИРОВАНИЕ ПРОЦЕДУР:

-- 3. Тестирование процедуры ежемесячной статистики
--  mysql -u phpmyadmin -p hotel_booking_system
-- CALL CalculateMonthlyStatistics(2024, 2);

-- 4. Тестирование процедуры обновления цен
-- CALL UpdateRoomPricesBasedOnPerformance(10, 5.0);

-- 5. Тестирование процедуры очистки отмененных бронирований
-- CALL CleanupCancelledBookings(3);

-- ТЕСТИРОВАНИЕ ТРИГГЕРОВ:

-- 6. Тестирование триггера проверки дат бронирования (должны быть ошибки)
-- INSERT INTO bookings (client_id, room_id, check_in_date, check_out_date, total_amount, payment_method) 
-- VALUES (1, 1, '2023-01-01', '2023-01-05', 10000, 'cash'); -- Ошибка: дата в прошлом

-- INSERT INTO bookings (client_id, room_id, check_in_date, check_out_date, total_amount, payment_method) 
-- VALUES (1, 1, '2024-04-01', '2024-03-01', 10000, 'cash'); -- Ошибка: дата выезда раньше заезда

-- 7. Тестирование триггера проверки нагрузки сотрудника
-- Сначала проверяем текущую нагрузку
SELECT
    assigned_staff_id,
    COUNT(*) AS services_count
FROM booked_services
WHERE
    assigned_staff_id = 6
    AND service_date = '2024-02-19'
GROUP BY assigned_staff_id;

-- 8. Тестирование триггера совместимости услуг и категорий номеров (должны быть ошибки)
-- INSERT INTO booked_services (booking_id, service_id, quantity, service_date, assigned_staff_id, total_service_price)
-- VALUES (1, 6, 1, '2024-02-18', 4, 5000.00); -- SPA в эконом - ошибка

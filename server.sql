DELIMITER //
CREATE FUNCTION CalculateBookingCost(
    p_room_id INT,
    p_check_in DATE,
    p_check_out DATE
) RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_nights INT;
    DECLARE v_base_price DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,2);
    
    SET v_nights = DATEDIFF(p_check_out, p_check_in);
    
    SELECT rc.base_price_per_night INTO v_base_price
    FROM rooms r
    JOIN room_categories rc ON r.category_id = rc.category_id
    WHERE r.room_id = p_room_id;
    
    SET v_total = v_base_price * v_nights;
    
    RETURN v_total;
END //
DELIMITER ;

DELIMITER //
CREATE FUNCTION IsRoomAvailable(
    p_room_id INT,
    p_check_in DATE,
    p_check_out DATE
) RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_conflict_count INT;
    
    SELECT room_status INTO v_status
    FROM rooms WHERE room_id = p_room_id;
    
    IF v_status != 'available' THEN
        RETURN FALSE;
    END IF;
    
    SELECT COUNT(*) INTO v_conflict_count
    FROM bookings 
    WHERE room_id = p_room_id 
    AND booking_status IN ('confirmed', 'completed')
    AND NOT (check_out_date <= p_check_in OR check_in_date >= p_check_out);
    
    RETURN v_conflict_count = 0;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE CalculateMonthlyStatistics(
    IN p_year INT,
    IN p_month INT
)
BEGIN
    DECLARE v_finished INT DEFAULT 0;
    DECLARE v_category_name VARCHAR(50);
    DECLARE v_total_revenue DECIMAL(12,2);
    DECLARE v_booking_count INT;
    DECLARE v_avg_occupancy DECIMAL(5,2);
    
    DECLARE category_cursor CURSOR FOR
        SELECT rc.category_name,
               SUM(b.total_amount) as total_revenue,
               COUNT(b.booking_id) as booking_count
        FROM room_categories rc
        LEFT JOIN rooms r ON rc.category_id = r.category_id
        LEFT JOIN bookings b ON r.room_id = b.room_id 
            AND YEAR(b.check_in_date) = p_year 
            AND MONTH(b.check_in_date) = p_month
            AND b.booking_status IN ('confirmed', 'completed')
        GROUP BY rc.category_id, rc.category_name
        ORDER BY total_revenue DESC;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_finished = 1;
    
    CREATE TEMPORARY TABLE IF NOT EXISTS monthly_stats_temp (
        category_name VARCHAR(50),
        total_revenue DECIMAL(12,2),
        booking_count INT,
        avg_occupancy DECIMAL(5,2)
    );
    
    DELETE FROM monthly_stats_temp;
    
    OPEN category_cursor;
    
    category_loop: LOOP
        FETCH category_cursor INTO v_category_name, v_total_revenue, v_booking_count;
        
        IF v_finished = 1 THEN
            LEAVE category_loop;
        END IF;
        
        SELECT 
            COALESCE(AVG(
                CASE 
                    WHEN b.booking_id IS NOT NULL THEN 1
                    ELSE 0
                END
            ), 0) * 100 INTO v_avg_occupancy
        FROM rooms r
        LEFT JOIN bookings b ON r.room_id = b.room_id 
            AND YEAR(b.check_in_date) = p_year 
            AND MONTH(b.check_in_date) = p_month
            AND b.booking_status IN ('confirmed', 'completed')
        WHERE EXISTS (
            SELECT 1 FROM room_categories rc2 
            WHERE rc2.category_id = r.category_id 
            AND rc2.category_name = v_category_name
        );
        
        INSERT INTO monthly_stats_temp 
        VALUES (v_category_name, v_total_revenue, v_booking_count, v_avg_occupancy);
    END LOOP;
    
    CLOSE category_cursor;
    
    SELECT * FROM monthly_stats_temp;
    
    SELECT 
        COUNT(*) as total_bookings,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_booking_amount
    FROM bookings
    WHERE YEAR(check_in_date) = p_year 
        AND MONTH(check_in_date) = p_month
        AND booking_status IN ('confirmed', 'completed');
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE UpdateRoomPricesBasedOnPerformance(
    IN p_performance_threshold INT,
    IN p_increase_percentage DECIMAL(5,2)
)
BEGIN
    UPDATE room_categories rc
    SET rc.base_price_per_night = rc.base_price_per_night * (1 + p_increase_percentage/100)
    WHERE rc.category_id IN (
        SELECT category_id
        FROM (
            SELECT rc2.category_id,
                   COUNT(b.booking_id) as booking_count,
                   SUM(b.total_amount) as total_revenue
            FROM room_categories rc2
            LEFT JOIN rooms r ON rc2.category_id = r.category_id
            LEFT JOIN bookings b ON r.room_id = b.room_id 
                AND b.booking_status IN ('confirmed', 'completed')
                AND YEAR(b.booking_date) = YEAR(CURDATE()) - 1
            GROUP BY rc2.category_id
            HAVING booking_count >= p_performance_threshold
        ) as high_performance_categories
    );
    
    SELECT CONCAT('Обновлены цены для ', ROW_COUNT(), ' категорий') as result_message;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE CleanupCancelledBookings(
    IN p_months_old INT
)
BEGIN
    DECLARE v_deleted_count INT;
    
    DELETE bs FROM booked_services bs
    WHERE bs.booking_id IN (
        SELECT b.booking_id
        FROM bookings b
        WHERE b.booking_status = 'cancelled'
        AND b.booking_date < DATE_SUB(CURDATE(), INTERVAL p_months_old MONTH)
    );
    
    SET v_deleted_count = ROW_COUNT();
    
    DELETE FROM bookings
    WHERE booking_status = 'cancelled'
    AND booking_date < DATE_SUB(CURDATE(), INTERVAL p_months_old MONTH);
    
    SET v_deleted_count = v_deleted_count + ROW_COUNT();
    
    SELECT CONCAT('Удалено ', v_deleted_count, ' записей отмененных бронирований старше ', 
                  p_months_old, ' месяцев') as cleanup_result;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_check_booking_dates
BEFORE INSERT ON bookings
FOR EACH ROW
BEGIN
    IF NEW.check_in_date < CURDATE() THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Дата заезда не может быть в прошлом';
    END IF;
    
    IF NEW.check_out_date <= NEW.check_in_date THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Дата выезда должна быть позже даты заезда';
    END IF;
    
    SET @nights := DATEDIFF(NEW.check_out_date, NEW.check_in_date);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_check_staff_workload
BEFORE INSERT ON booked_services
FOR EACH ROW
BEGIN
    DECLARE v_services_count INT;
    
    IF NEW.assigned_staff_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_services_count
        FROM booked_services
        WHERE assigned_staff_id = NEW.assigned_staff_id
        AND service_date = NEW.service_date;

        IF v_services_count >= 10 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Превышен дневной лимит услуг для сотрудника. Максимум: 10 услуг в день.';
        END IF;
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_check_service_room_compatibility
BEFORE INSERT ON booked_services
FOR EACH ROW
BEGIN
    DECLARE v_room_category_id INT;
    DECLARE v_room_category_name VARCHAR(50);
    DECLARE v_service_name VARCHAR(100);
    
    SELECT rc.category_id, rc.category_name INTO v_room_category_id, v_room_category_name
    FROM bookings b
    JOIN rooms r ON b.room_id = r.room_id
    JOIN room_categories rc ON r.category_id = rc.category_id
    WHERE b.booking_id = NEW.booking_id;
    
    SELECT service_name INTO v_service_name
    FROM services
    WHERE service_id = NEW.service_id;
    
    IF v_room_category_id = 1 THEN
        IF v_service_name IN ('SPA-процедуры', 'Аренда конференц-зала', 'Президентский ужин') THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Данная услуга недоступна для категории "Эконом".';
        END IF;
        
    ELSEIF v_room_category_id = 2 THEN
        IF v_service_name IN ('Аренда конференц-зала', 'Президентский ужин') THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Данная услуга недоступна для категории "Стандарт".';
        END IF;
        
    ELSEIF v_room_category_id IN (3, 4, 5) THEN 
        SET @debug = 'Все услуги доступны для этой категории';
        
    END IF;
END //
DELIMITER ;

CREATE VIEW staff_performance_view AS
SELECT 
    s.staff_id,
    CONCAT(s.first_name, ' ', s.last_name) as staff_name,
    sp.position_name,
    COUNT(DISTINCT bs.booking_id) as total_services_assigned,
    SUM(bs.total_service_price) as total_service_revenue,
    ROUND(AVG(bs.total_service_price), 2) as avg_service_value
FROM staff s
JOIN staff_positions sp ON s.position_id = sp.position_id
LEFT JOIN booked_services bs ON s.staff_id = bs.assigned_staff_id
WHERE s.is_active = TRUE
GROUP BY s.staff_id, s.first_name, s.last_name, sp.position_name;

CREATE VIEW category_popularity_view AS
SELECT 
    rc.category_id,
    rc.category_name,
    COUNT(b.booking_id) as total_bookings,
    SUM(b.total_amount) as total_revenue,
    ROUND(AVG(DATEDIFF(b.check_out_date, b.check_in_date)), 1) as avg_stay_length,
    ROUND((COUNT(b.booking_id) / (SELECT COUNT(*) FROM bookings WHERE booking_status IN ('confirmed', 'completed'))) * 100, 2) as market_share_percentage
FROM room_categories rc
LEFT JOIN rooms r ON rc.category_id = r.category_id
LEFT JOIN bookings b ON r.room_id = b.room_id AND b.booking_status IN ('confirmed', 'completed')
GROUP BY rc.category_id, rc.category_name
ORDER BY total_revenue DESC;

CREATE VIEW financial_report_view AS
SELECT 
    DATE_FORMAT(b.booking_date, '%Y-%m') as month,
    COUNT(b.booking_id) as total_bookings,
    SUM(b.total_amount) as total_revenue,
    SUM(bs.total_service_price) as service_revenue,
    SUM(b.total_amount + COALESCE(bs.total_service_price, 0)) as total_income,
    COUNT(DISTINCT b.client_id) as unique_clients,
    ROUND(AVG(b.total_amount), 2) as avg_booking_value
FROM bookings b
LEFT JOIN (
    SELECT booking_id, SUM(total_service_price) as total_service_price
    FROM booked_services
    GROUP BY booking_id
) bs ON b.booking_id = bs.booking_id
WHERE b.booking_status IN ('confirmed', 'completed')
GROUP BY DATE_FORMAT(b.booking_date, '%Y-%m')
ORDER BY month DESC;

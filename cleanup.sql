DROP VIEW IF EXISTS staff_performance_view;
DROP VIEW IF EXISTS category_popularity_view;
DROP VIEW IF EXISTS financial_report_view;

DROP TRIGGER IF EXISTS trg_check_booking_dates;
DROP TRIGGER IF EXISTS trg_check_staff_workload;
DROP TRIGGER IF EXISTS trg_check_service_room_compatibility;

DROP FUNCTION IF EXISTS CALCULATEBOOKINGCOST;
DROP FUNCTION IF EXISTS ISROOMAVAILABLE;

DROP PROCEDURE IF EXISTS calculatemonthlystatistics;
DROP PROCEDURE IF EXISTS updateroompricesbasedonperformance;
DROP PROCEDURE IF EXISTS cleanupcancelledbookings;

DROP TEMPORARY TABLE IF EXISTS monthly_stats_temp;

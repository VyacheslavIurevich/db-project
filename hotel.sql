CREATE DATABASE IF NOT EXISTS hotel_booking_system
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE hotel_booking_system;

CREATE TABLE staff_positions (
    position_id INT AUTO_INCREMENT PRIMARY KEY,
    position_name VARCHAR(50) NOT NULL UNIQUE,
    position_description TEXT,
    min_salary DECIMAL(10, 2) NOT NULL CHECK (min_salary > 0),
    max_salary DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_salary CHECK (max_salary >= min_salary)
);

CREATE TABLE room_categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    category_description TEXT,
    base_price_per_night DECIMAL(10, 2) NOT NULL CHECK (
        base_price_per_night > 0
    ),
    max_occupancy INT NOT NULL CHECK (max_occupancy > 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE rooms (
    room_id INT AUTO_INCREMENT PRIMARY KEY,
    room_number VARCHAR(10) NOT NULL UNIQUE,
    category_id INT NOT NULL,
    floor INT NOT NULL CHECK (floor BETWEEN 1 AND 100),
    room_status ENUM(
        'available', 'occupied', 'maintenance', 'cleaning'
    ) DEFAULT 'available',
    has_balcony BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (category_id) REFERENCES room_categories (
        category_id
    ) ON DELETE RESTRICT
);

CREATE TABLE staff (
    staff_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    position_id INT NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL CHECK (email LIKE '%@%.%'),
    phone VARCHAR(20) UNIQUE NOT NULL,
    hire_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (position_id) REFERENCES staff_positions (
        position_id
    ) ON DELETE RESTRICT
);

CREATE TABLE clients (
    client_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL CHECK (email LIKE '%@%.%'),
    phone VARCHAR(20) UNIQUE NOT NULL,
    passport_number VARCHAR(35) UNIQUE NOT NULL,
    country_iso VARCHAR(3) NOT NULL,
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE services (
    service_id INT AUTO_INCREMENT PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL UNIQUE,
    service_description TEXT,
    price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
    responsible_position_id INT NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (responsible_position_id) REFERENCES staff_positions (
        position_id
    ) ON DELETE RESTRICT
);

CREATE TABLE bookings (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    room_id INT NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    booking_status ENUM(
        'confirmed', 'cancelled', 'completed', 'no_show'
    ) DEFAULT 'confirmed',
    total_amount DECIMAL(10, 2) NOT NULL CHECK (total_amount > 0),
    payment_method ENUM('cash', 'card', 'online') NOT NULL,
    free_cancellation BOOLEAN DEFAULT TRUE,
    free_parking BOOLEAN DEFAULT FALSE,
    free_breakfast BOOLEAN DEFAULT FALSE,
    special_requests TEXT,
    FOREIGN KEY (client_id) REFERENCES clients (client_id) ON DELETE CASCADE,
    FOREIGN KEY (room_id) REFERENCES rooms (room_id) ON DELETE RESTRICT,
    CONSTRAINT chk_dates CHECK (check_out_date > check_in_date)
);

CREATE TABLE booked_services (
    booking_service_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    service_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    service_date DATE NOT NULL,
    assigned_staff_id INT,
    total_service_price DECIMAL(10, 2) NOT NULL CHECK (total_service_price > 0),
    FOREIGN KEY (booking_id) REFERENCES bookings (booking_id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services (
        service_id
    ) ON DELETE RESTRICT,
    FOREIGN KEY (assigned_staff_id) REFERENCES staff (
        staff_id
    ) ON DELETE SET NULL
);

CREATE INDEX idx_rooms_status ON rooms (room_status);
CREATE INDEX idx_bookings_client ON bookings (client_id);
CREATE INDEX idx_bookings_dates ON bookings (check_in_date, check_out_date);
CREATE INDEX idx_clients_email ON clients (email);
CREATE INDEX idx_staff_position ON staff (position_id, is_active);
CREATE INDEX idx_rooms_search ON rooms (
    room_status, category_id, floor, has_balcony
);
CREATE INDEX idx_bookings_operational ON bookings (
    booking_status, check_in_date, check_out_date, room_id
);
CREATE INDEX idx_bookings_financial ON bookings (
    total_amount, payment_method, booking_date
);
CREATE INDEX idx_clients_search ON clients (last_name, first_name, email);
CREATE INDEX idx_booked_services_operational ON booked_services (
    service_date, booking_id, assigned_staff_id
);

INSERT INTO staff_positions (
    position_name, position_description, min_salary, max_salary
) VALUES
(
    'Администратор',
    'Работа на ресепшене, прием гостей, бронирование',
    40000.00,
    60000.00
),
('Горничная', 'Уборка номеров и остальной гостиницы', 35000.00, 50000.00),
('Консьерж', 'Помощь гостям, организация услуг', 45000.00, 65000.00),
('Менеджер', 'Управление персоналом', 60000.00, 90000.00),
('Шеф-повар', 'Приготовление блюд, руководство кухней', 70000.00, 120000.00),
(
    'Официант',
    'Обслуживание в ресторане, доставка еды в номера',
    35000.00,
    55000.00
);

INSERT INTO room_categories (
    category_name, category_description, base_price_per_night, max_occupancy
) VALUES
('Эконом', 'Небольшой номер с базовыми удобствами', 2500.00, 2),
('Стандарт', 'Комфортабельный номер с современной мебелью', 4500.00, 2),
('Полулюкс', 'Просторный номер с дополнительной зоной отдыха', 7500.00, 3),
('Люкс', 'Роскошный номер с гостиной и улучшенным сервисом', 12000.00, 4),
('Президентский', 'Эксклюзивный номер высшего класса', 25000.00, 4);

INSERT INTO rooms (
    room_number, category_id, floor, room_status, has_balcony
) VALUES
('101', 1, 1, 'available', FALSE),
('102', 1, 1, 'available', FALSE),
('103', 1, 1, 'maintenance', FALSE),
('201', 2, 2, 'available', TRUE),
('202', 2, 2, 'occupied', TRUE),
('203', 2, 2, 'available', TRUE),
('204', 2, 2, 'available', TRUE),
('301', 3, 3, 'available', TRUE),
('302', 3, 3, 'cleaning', TRUE),
('303', 3, 3, 'available', TRUE),
('401', 4, 4, 'available', TRUE),
('402', 4, 4, 'available', TRUE),
('501', 5, 5, 'available', TRUE),
('502', 5, 5, 'available', TRUE);

INSERT INTO staff (
    first_name, last_name, position_id, email, phone, hire_date, is_active
) VALUES
(
    'Анна',
    'Иванова',
    1,
    'anna.ivanova@hotel.ru',
    '+79161234567',
    '2022-01-15',
    TRUE
),
(
    'Петр',
    'Смирнов',
    4,
    'petr.smirnov@hotel.ru',
    '+79162345678',
    '2021-03-10',
    TRUE
),
(
    'Мария',
    'Петрова',
    2,
    'maria.petrova@hotel.ru',
    '+79163456789',
    '2023-02-20',
    TRUE
),
(
    'Иван',
    'Кузнецов',
    3,
    'ivan.kuznetsov@hotel.ru',
    '+79164567890',
    '2022-11-05',
    TRUE
),
(
    'Ольга',
    'Сидорова',
    5,
    'olga.sidorova@hotel.ru',
    '+79165678901',
    '2021-07-12',
    TRUE
),
(
    'Сергей',
    'Васильев',
    6,
    'sergey.vasiliev@hotel.ru',
    '+79166789012',
    '2023-04-18',
    TRUE
),
(
    'Елена',
    'Попова',
    1,
    'elena.popova@hotel.ru',
    '+79167890123',
    '2022-09-30',
    TRUE
),
(
    'Дмитрий',
    'Соколов',
    3,
    'dmitry.sokolov@hotel.ru',
    '+79168901234',
    '2023-01-22',
    TRUE
);

INSERT INTO clients (
    first_name, last_name, email, phone, passport_number, country_iso
) VALUES
(
    'Александр',
    'Новиков',
    'alex.novikov@mail.ru',
    '+79031234567',
    '4510123456',
    '643'
),
(
    'Екатерина',
    'Волкова',
    'ekaterina.volkova@gmail.com',
    '+79032345678',
    '4510123457',
    '643'
),
(
    'Михаил',
    'Федоров',
    'mikhail.fedorov@yandex.ru',
    '+79033456789',
    '4510123458',
    '643'
),
(
    'Анна',
    'Морозова',
    'anna.morozova@mail.ru',
    '+79034567890',
    '4510123459',
    '643'
),
('Джон', 'Смит', 'john.smith@email.com', '+44123456789', 'AB123456', '826'),
(
    'Мария',
    'Гончарова',
    'maria.goncharova@gmail.com',
    '+79036789012',
    '4510123460',
    '643'
),
(
    'Алексей',
    'Белов',
    'alexey.belov@mail.ru',
    '+79037890123',
    '4510123461',
    '643'
),
(
    'София',
    'Крылова',
    'sofia.krylova@yandex.ru',
    '+79038901234',
    '4510123462',
    '643'
),
('Томас', 'Мюллер', 'thomas.muller@gmx.de', '+49123456789', 'C12345678', '276'),
(
    'Ирина',
    'Демидова',
    'irina.demidova@gmail.com',
    '+79031012345',
    '4510123463',
    '643'
);

INSERT INTO services (
    service_name, service_description, price, responsible_position_id
) VALUES
('Обед', 'Трехразовое питание - обед', 1500.00, 5),
('Ужин', 'Трехразовое питание - ужин', 1800.00, 5),
('Сауна', 'Посещение сауны на 2 часа', 3500.00, 3),
('Экскурсия по городу', 'Обзорная экскурсия по городу', 2500.00, 3),
('Трансфер', 'Трансфер из/в аэропорт', 2000.00, 3),
('SPA-процедуры', 'Базовый SPA-пакет', 5000.00, 3),
('Прачечная', 'Стирка и глажка одежды', 800.00, 2),
('Бизнес-ланч', 'Деловой обед с напитками', 2200.00, 5),
('Аренда конференц-зала', 'Аренда зала на 4 часа', 10000.00, 3),
('Фитнес-тренер', 'Персональная тренировка', 3000.00, 3);

INSERT INTO bookings (
    client_id,
    room_id,
    check_in_date,
    check_out_date,
    booking_status,
    total_amount,
    payment_method,
    free_cancellation,
    free_parking,
    free_breakfast,
    special_requests
) VALUES
(
    1,
    1,
    '2024-02-15',
    '2024-02-20',
    'completed',
    12500.00,
    'card',
    TRUE,
    FALSE,
    TRUE,
    'Просьба подготовить номер к 14:00'
),
(
    2,
    5,
    '2024-02-18',
    '2024-02-25',
    'confirmed',
    31500.00,
    'online',
    TRUE,
    TRUE,
    FALSE,
    'Номер на высоком этаже'
),
(
    3,
    7,
    '2024-03-01',
    '2024-03-05',
    'confirmed',
    30000.00,
    'cash',
    FALSE,
    TRUE,
    TRUE,
    'Юбилей - украсить номер'
),

(
    4,
    4,
    '2024-02-20',
    '2024-02-22',
    'cancelled',
    9000.00,
    'online',
    TRUE,
    FALSE,
    FALSE,
    NULL
),
(
    4,
    8,
    '2024-02-20',
    '2024-02-22',
    'cancelled',
    15000.00,
    'online',
    TRUE,
    FALSE,
    FALSE,
    NULL
),

(
    5,
    9,
    '2024-03-10',
    '2024-03-15',
    'confirmed',
    60000.00,
    'card',
    TRUE,
    TRUE,
    TRUE,
    'Требуется англоговорящий персонал'
),
(
    5,
    10,
    '2024-03-10',
    '2024-03-15',
    'confirmed',
    60000.00,
    'card',
    TRUE,
    TRUE,
    TRUE,
    'Требуется англоговорящий персонал'
),

(
    6,
    11,
    '2024-02-25',
    '2024-02-28',
    'completed',
    36000.00,
    'cash',
    TRUE,
    FALSE,
    TRUE,
    NULL
),
(
    7,
    12,
    '2024-03-03',
    '2024-03-08',
    'confirmed',
    60000.00,
    'online',
    FALSE,
    TRUE,
    FALSE,
    'Аллергия на пуховые подушки'
),

(
    8,
    13,
    '2024-03-12',
    '2024-03-14',
    'confirmed',
    50000.00,
    'card',
    TRUE,
    FALSE,
    TRUE,
    'Романтический ужин в номер'
),
(
    8,
    14,
    '2024-03-12',
    '2024-03-14',
    'confirmed',
    50000.00,
    'card',
    TRUE,
    FALSE,
    TRUE,
    'Романтический ужин в номер'
),

(
    9,
    2,
    '2024-03-20',
    '2024-03-25',
    'confirmed',
    125000.00,
    'card',
    TRUE,
    TRUE,
    TRUE,
    'Деловые встречи - требуется переговорная'
),
(
    10,
    3,
    '2024-04-01',
    '2024-04-05',
    'confirmed',
    10000.00,
    'online',
    TRUE,
    FALSE,
    FALSE,
    NULL
);

INSERT INTO booked_services (
    booking_id,
    service_id,
    quantity,
    service_date,
    assigned_staff_id,
    total_service_price
) VALUES
(1, 1, 2, '2024-02-16', 6, 3000.00),
(1, 3, 1, '2024-02-17', 4, 3500.00),
(2, 2, 3, '2024-02-19', 6, 5400.00),
(2, 4, 1, '2024-02-20', 8, 2500.00),
(3, 5, 2, '2024-03-02', 4, 4000.00),
(5, 6, 1, '2024-03-11', 4, 5000.00),
(5, 7, 3, '2024-03-12', 3, 2400.00),
(7, 1, 4, '2024-03-04', 6, 6000.00),
(8, 2, 2, '2024-03-13', 6, 3600.00),
(8, 3, 1, '2024-03-13', 4, 3500.00),
(9, 4, 2, '2024-03-21', 8, 5000.00),
(9, 5, 1, '2024-03-20', 4, 2000.00),
(9, 9, 1, '2024-03-21', 4, 10000.00);

INSERT INTO booked_services (
    booking_id,
    service_id,
    quantity,
    service_date,
    assigned_staff_id,
    total_service_price
) VALUES
(2, 2, 3, '2024-02-19', 6, 5400.00),
(2, 2, 3, '2024-02-19', 6, 5400.00),
(2, 2, 3, '2024-02-19', 6, 5400.00),
(2, 2, 3, '2024-02-19', 6, 5400.00),
(2, 2, 3, '2024-02-19', 6, 5400.00),
(2, 2, 3, '2024-02-19', 6, 5400.00),
(2, 2, 3, '2024-02-19', 6, 5400.00),
(2, 2, 3, '2024-02-19', 6, 5400.00),
(2, 2, 3, '2024-02-19', 6, 5400.00);

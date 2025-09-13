-- Создание тестовых таблиц и данных для PostgreSQL
-- Этот скрипт выполняется автоматически при первом запуске контейнера

-- Функция для генерации случайных данных
CREATE OR REPLACE FUNCTION test_schema.generate_random_string(length INTEGER)
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    result TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..length LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::INTEGER, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Создание схемы для тестовых данных
CREATE SCHEMA IF NOT EXISTS test_schema;

-- Создание таблицы пользователей
CREATE TABLE IF NOT EXISTS test_schema.users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Создание таблицы заказов
CREATE TABLE IF NOT EXISTS test_schema.orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES test_schema.users(id),
    order_number VARCHAR(20) NOT NULL UNIQUE,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы товаров
CREATE TABLE IF NOT EXISTS test_schema.products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category VARCHAR(50),
    stock_quantity INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы позиций заказа
CREATE TABLE IF NOT EXISTS test_schema.order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES test_schema.orders(id),
    product_id INTEGER REFERENCES test_schema.products(id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL
);

-- Создание индексов для улучшения производительности
CREATE INDEX IF NOT EXISTS idx_users_email ON test_schema.users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON test_schema.users(username);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON test_schema.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON test_schema.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON test_schema.orders(created_at);
CREATE INDEX IF NOT EXISTS idx_products_category ON test_schema.products(category);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON test_schema.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON test_schema.order_items(product_id);

-- Вставка тестовых данных

-- Вставка пользователей
INSERT INTO test_schema.users (username, email, first_name, last_name, is_active) VALUES
('john_doe', 'john.doe@example.com', 'John', 'Doe', TRUE),
('jane_smith', 'jane.smith@example.com', 'Jane', 'Smith', TRUE),
('bob_wilson', 'bob.wilson@example.com', 'Bob', 'Wilson', TRUE),
('alice_brown', 'alice.brown@example.com', 'Alice', 'Brown', TRUE),
('charlie_davis', 'charlie.davis@example.com', 'Charlie', 'Davis', FALSE),
('diana_miller', 'diana.miller@example.com', 'Diana', 'Miller', TRUE),
('eve_jones', 'eve.jones@example.com', 'Eve', 'Jones', TRUE),
('frank_garcia', 'frank.garcia@example.com', 'Frank', 'Garcia', TRUE),
('grace_lee', 'grace.lee@example.com', 'Grace', 'Lee', TRUE),
('henry_taylor', 'henry.taylor@example.com', 'Henry', 'Taylor', FALSE)
ON CONFLICT (username) DO NOTHING;

-- Вставка товаров
INSERT INTO test_schema.products (name, description, price, category, stock_quantity) VALUES
('Laptop Pro 15"', 'High-performance laptop with 16GB RAM and 512GB SSD', 1299.99, 'Electronics', 50),
('Wireless Mouse', 'Ergonomic wireless mouse with USB receiver', 29.99, 'Electronics', 200),
('Mechanical Keyboard', 'RGB mechanical keyboard with blue switches', 89.99, 'Electronics', 75),
('Monitor 27"', '4K Ultra HD monitor with HDR support', 399.99, 'Electronics', 30),
('Office Chair', 'Ergonomic office chair with lumbar support', 199.99, 'Furniture', 25),
('Desk Lamp', 'LED desk lamp with adjustable brightness', 49.99, 'Furniture', 100),
('Coffee Mug', 'Ceramic coffee mug with company logo', 12.99, 'Accessories', 500),
('Notebook Set', 'Set of 3 premium notebooks', 24.99, 'Office Supplies', 150),
('Pen Set', 'Set of 5 gel pens in different colors', 9.99, 'Office Supplies', 300),
('Backpack', 'Waterproof backpack with laptop compartment', 79.99, 'Accessories', 80)
ON CONFLICT DO NOTHING;

-- Вставка заказов
INSERT INTO test_schema.orders (user_id, order_number, total_amount, status) VALUES
(1, 'ORD-2024-001', 1329.98, 'completed'),
(2, 'ORD-2024-002', 119.98, 'completed'),
(3, 'ORD-2024-003', 489.98, 'pending'),
(4, 'ORD-2024-004', 199.99, 'completed'),
(5, 'ORD-2024-005', 62.98, 'cancelled'),
(6, 'ORD-2024-006', 34.98, 'completed'),
(7, 'ORD-2024-007', 79.99, 'pending'),
(8, 'ORD-2024-008', 199.99, 'completed'),
(9, 'ORD-2024-009', 89.99, 'completed'),
(10, 'ORD-2024-010', 12.99, 'completed')
ON CONFLICT (order_number) DO NOTHING;

-- Вставка позиций заказов
INSERT INTO test_schema.order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(1, 1, 1, 1299.99, 1299.99),
(1, 2, 1, 29.99, 29.99),
(2, 3, 1, 89.99, 89.99),
(2, 2, 1, 29.99, 29.99),
(3, 4, 1, 399.99, 399.99),
(3, 3, 1, 89.99, 89.99),
(4, 5, 1, 199.99, 199.99),
(5, 6, 1, 49.99, 49.99),
(5, 7, 1, 12.99, 12.99),
(6, 8, 1, 24.99, 24.99),
(6, 9, 1, 9.99, 9.99),
(7, 10, 1, 79.99, 79.99),
(8, 5, 1, 199.99, 199.99),
(9, 3, 1, 89.99, 89.99),
(10, 7, 1, 12.99, 12.99)
ON CONFLICT DO NOTHING;

-- Создание представления для аналитики
CREATE OR REPLACE VIEW test_schema.order_summary AS
SELECT 
    o.id as order_id,
    o.order_number,
    u.username,
    u.email,
    o.total_amount,
    o.status,
    o.created_at,
    COUNT(oi.id) as item_count
FROM test_schema.orders o
JOIN test_schema.users u ON o.user_id = u.id
LEFT JOIN test_schema.order_items oi ON o.id = oi.order_id
GROUP BY o.id, o.order_number, u.username, u.email, o.total_amount, o.status, o.created_at;

-- Создание функции для обновления updated_at
CREATE OR REPLACE FUNCTION test_schema.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Создание триггеров для автоматического обновления updated_at
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON test_schema.users 
    FOR EACH ROW EXECUTE FUNCTION test_schema.update_updated_at_column();

CREATE TRIGGER update_orders_updated_at 
    BEFORE UPDATE ON test_schema.orders 
    FOR EACH ROW EXECUTE FUNCTION test_schema.update_updated_at_column();

CREATE TRIGGER update_products_updated_at 
    BEFORE UPDATE ON test_schema.products 
    FOR EACH ROW EXECUTE FUNCTION test_schema.update_updated_at_column();

-- Создание дополнительной таблицы для логирования изменений
CREATE TABLE IF NOT EXISTS test_schema.audit_log (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INTEGER NOT NULL,
    action VARCHAR(10) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(50),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание функции для аудита
CREATE OR REPLACE FUNCTION test_schema.audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO test_schema.audit_log (table_name, record_id, action, old_values)
        VALUES (TG_TABLE_NAME, OLD.id, TG_OP, row_to_json(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO test_schema.audit_log (table_name, record_id, action, old_values, new_values)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO test_schema.audit_log (table_name, record_id, action, new_values)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, row_to_json(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Создание триггеров аудита для основных таблиц
CREATE TRIGGER audit_users_trigger
    AFTER INSERT OR UPDATE OR DELETE ON test_schema.users
    FOR EACH ROW EXECUTE FUNCTION test_schema.audit_trigger_function();

CREATE TRIGGER audit_orders_trigger
    AFTER INSERT OR UPDATE OR DELETE ON test_schema.orders
    FOR EACH ROW EXECUTE FUNCTION test_schema.audit_trigger_function();

-- Вывод информации о созданных объектах
DO $$
BEGIN
    RAISE NOTICE 'Тестовые данные успешно созданы!';
    RAISE NOTICE 'Создано пользователей: %', (SELECT COUNT(*) FROM test_schema.users);
    RAISE NOTICE 'Создано товаров: %', (SELECT COUNT(*) FROM test_schema.products);
    RAISE NOTICE 'Создано заказов: %', (SELECT COUNT(*) FROM test_schema.orders);
    RAISE NOTICE 'Создано позиций заказов: %', (SELECT COUNT(*) FROM test_schema.order_items);
END $$;

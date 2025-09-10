-- Дополнительная генерация тестовых данных
-- Этот скрипт добавляет больше данных для более реалистичного тестирования backup
-- Функция generate_random_string уже создана в 01-create-test-data.sql

-- Генерация дополнительных пользователей
INSERT INTO test_schema.users (username, email, first_name, last_name, is_active)
SELECT 
    'user_' || test_schema.generate_random_string(8),
    'user_' || test_schema.generate_random_string(8) || '@example.com',
    'FirstName_' || i,
    'LastName_' || i,
    CASE WHEN random() > 0.1 THEN TRUE ELSE FALSE END
FROM generate_series(11, 100) AS i
ON CONFLICT (username) DO NOTHING;

-- Генерация дополнительных товаров
INSERT INTO test_schema.products (name, description, price, category, stock_quantity)
SELECT 
    'Product ' || i,
    'Description for product ' || i || ' - ' || test_schema.generate_random_string(50),
    (random() * 1000 + 10)::DECIMAL(10,2),
    CASE (i % 5)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Furniture'
        WHEN 2 THEN 'Accessories'
        WHEN 3 THEN 'Office Supplies'
        ELSE 'Books'
    END,
    floor(random() * 1000)::INTEGER
FROM generate_series(11, 200) AS i
ON CONFLICT DO NOTHING;

-- Генерация дополнительных заказов
INSERT INTO test_schema.orders (user_id, order_number, total_amount, status)
SELECT 
    (random() * 100 + 1)::INTEGER,
    'ORD-2024-' || LPAD(i::TEXT, 6, '0'),
    (random() * 2000 + 10)::DECIMAL(10,2),
    CASE (i % 4)
        WHEN 0 THEN 'completed'
        WHEN 1 THEN 'pending'
        WHEN 2 THEN 'processing'
        ELSE 'cancelled'
    END
FROM generate_series(11, 500) AS i
ON CONFLICT (order_number) DO NOTHING;

-- Генерация позиций заказов
INSERT INTO test_schema.order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT 
    o.id,
    p.id,
    (random() * 5 + 1)::INTEGER,
    p.price,
    p.price * (random() * 5 + 1)::INTEGER
FROM test_schema.orders o
CROSS JOIN test_schema.products p
WHERE o.id > 10  -- Только для новых заказов
    AND random() < 0.3  -- 30% вероятность добавления товара в заказ
ON CONFLICT DO NOTHING;

-- Обновление общей суммы заказов на основе позиций
UPDATE test_schema.orders 
SET total_amount = (
    SELECT COALESCE(SUM(total_price), 0)
    FROM test_schema.order_items 
    WHERE order_id = orders.id
)
WHERE id > 10;

-- Создание таблицы для тестирования больших данных
CREATE TABLE IF NOT EXISTS test_schema.large_data_table (
    id SERIAL PRIMARY KEY,
    data_text TEXT,
    data_json JSONB,
    data_array INTEGER[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Генерация данных в большой таблице
INSERT INTO test_schema.large_data_table (data_text, data_json, data_array)
SELECT 
    'Large data entry ' || i || ' - ' || test_schema.generate_random_string(100),
    json_build_object(
        'id', i,
        'name', 'Item ' || i,
        'value', (random() * 1000)::INTEGER,
        'metadata', json_build_object(
            'category', CASE (i % 10) WHEN 0 THEN 'A' WHEN 1 THEN 'B' ELSE 'C' END,
            'priority', (random() * 5 + 1)::INTEGER,
            'tags', ARRAY['tag' || (random() * 10 + 1)::INTEGER, 'tag' || (random() * 10 + 1)::INTEGER]
        )
    ),
    ARRAY[
        (random() * 1000)::INTEGER,
        (random() * 1000)::INTEGER,
        (random() * 1000)::INTEGER,
        (random() * 1000)::INTEGER,
        (random() * 1000)::INTEGER
    ]
FROM generate_series(1, 10000) AS i;

-- Создание индексов для большой таблицы
CREATE INDEX IF NOT EXISTS idx_large_data_created_at ON test_schema.large_data_table(created_at);
CREATE INDEX IF NOT EXISTS idx_large_data_json_gin ON test_schema.large_data_table USING GIN (data_json);
CREATE INDEX IF NOT EXISTS idx_large_data_array_gin ON test_schema.large_data_table USING GIN (data_array);

-- Создание таблицы для тестирования BLOB данных
CREATE TABLE IF NOT EXISTS test_schema.binary_data (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255),
    file_data BYTEA,
    file_size INTEGER,
    mime_type VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Генерация бинарных данных (симуляция файлов)
INSERT INTO test_schema.binary_data (filename, file_data, file_size, mime_type)
SELECT 
    'test_file_' || i || '.txt',
    ('Test file content ' || i || ' - ' || test_schema.generate_random_string(1000))::BYTEA,
    length('Test file content ' || i || ' - ' || test_schema.generate_random_string(1000)),
    CASE (i % 4)
        WHEN 0 THEN 'text/plain'
        WHEN 1 THEN 'application/json'
        WHEN 2 THEN 'text/csv'
        ELSE 'application/octet-stream'
    END
FROM generate_series(1, 100) AS i;

-- Создание таблицы для тестирования временных рядов
CREATE TABLE IF NOT EXISTS test_schema.time_series_data (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100),
    metric_value DECIMAL(10,4),
    timestamp TIMESTAMP,
    tags JSONB
);

-- Генерация временных рядов данных
INSERT INTO test_schema.time_series_data (metric_name, metric_value, timestamp, tags)
SELECT 
    CASE (i % 5)
        WHEN 0 THEN 'cpu_usage'
        WHEN 1 THEN 'memory_usage'
        WHEN 2 THEN 'disk_usage'
        WHEN 3 THEN 'network_io'
        ELSE 'response_time'
    END,
    (random() * 100)::DECIMAL(10,4),
    CURRENT_TIMESTAMP - (random() * INTERVAL '30 days'),
    json_build_object(
        'host', 'server_' || (i % 10 + 1),
        'environment', CASE (i % 3) WHEN 0 THEN 'prod' WHEN 1 THEN 'test' ELSE 'dev' END,
        'region', CASE (i % 4) WHEN 0 THEN 'us-east' WHEN 1 THEN 'us-west' WHEN 2 THEN 'eu-west' ELSE 'asia-pacific' END
    )
FROM generate_series(1, 50000) AS i;

-- Создание индексов для временных рядов
CREATE INDEX IF NOT EXISTS idx_time_series_metric_timestamp ON test_schema.time_series_data(metric_name, timestamp);
CREATE INDEX IF NOT EXISTS idx_time_series_timestamp ON test_schema.time_series_data(timestamp);
CREATE INDEX IF NOT EXISTS idx_time_series_tags_gin ON test_schema.time_series_data USING GIN (tags);

-- Создание материализованного представления для аналитики
CREATE MATERIALIZED VIEW IF NOT EXISTS test_schema.daily_sales_summary AS
SELECT 
    DATE(created_at) as sale_date,
    COUNT(*) as total_orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_orders,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_orders
FROM test_schema.orders
GROUP BY DATE(created_at)
ORDER BY sale_date;

-- Создание индекса для материализованного представления
CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_sales_summary_date ON test_schema.daily_sales_summary(sale_date);

-- Функция для обновления материализованного представления
CREATE OR REPLACE FUNCTION test_schema.refresh_daily_sales_summary()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY test_schema.daily_sales_summary;
END;
$$ LANGUAGE plpgsql;

-- Вывод статистики
DO $$
DECLARE
    user_count INTEGER;
    product_count INTEGER;
    order_count INTEGER;
    order_item_count INTEGER;
    large_data_count INTEGER;
    binary_data_count INTEGER;
    time_series_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM test_schema.users;
    SELECT COUNT(*) INTO product_count FROM test_schema.products;
    SELECT COUNT(*) INTO order_count FROM test_schema.orders;
    SELECT COUNT(*) INTO order_item_count FROM test_schema.order_items;
    SELECT COUNT(*) INTO large_data_count FROM test_schema.large_data_table;
    SELECT COUNT(*) INTO binary_data_count FROM test_schema.binary_data;
    SELECT COUNT(*) INTO time_series_count FROM test_schema.time_series_data;
    
    RAISE NOTICE '=== СТАТИСТИКА ТЕСТОВЫХ ДАННЫХ ===';
    RAISE NOTICE 'Пользователей: %', user_count;
    RAISE NOTICE 'Товаров: %', product_count;
    RAISE NOTICE 'Заказов: %', order_count;
    RAISE NOTICE 'Позиций заказов: %', order_item_count;
    RAISE NOTICE 'Записей в большой таблице: %', large_data_count;
    RAISE NOTICE 'Бинарных файлов: %', binary_data_count;
    RAISE NOTICE 'Записей временных рядов: %', time_series_count;
    RAISE NOTICE '================================';
END $$;

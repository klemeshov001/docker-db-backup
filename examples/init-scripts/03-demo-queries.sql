-- Демонстрационные запросы для проверки тестовых данных
-- Этот скрипт содержит примеры запросов для демонстрации функциональности

-- 1. Статистика по пользователям
SELECT 
    'Пользователи' as category,
    COUNT(*) as total_count,
    COUNT(CASE WHEN is_active THEN 1 END) as active_count,
    COUNT(CASE WHEN NOT is_active THEN 1 END) as inactive_count
FROM test_schema.users

UNION ALL

-- 2. Статистика по товарам
SELECT 
    'Товары' as category,
    COUNT(*) as total_count,
    COUNT(CASE WHEN stock_quantity > 0 THEN 1 END) as in_stock_count,
    COUNT(CASE WHEN stock_quantity = 0 THEN 1 END) as out_of_stock_count
FROM test_schema.products

UNION ALL

-- 3. Статистика по заказам
SELECT 
    'Заказы' as category,
    COUNT(*) as total_count,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_count,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count
FROM test_schema.orders;

-- 4. Топ-10 пользователей по сумме заказов
SELECT 
    u.username,
    u.email,
    COUNT(o.id) as order_count,
    SUM(o.total_amount) as total_spent,
    AVG(o.total_amount) as avg_order_value
FROM test_schema.users u
JOIN test_schema.orders o ON u.id = o.user_id
WHERE o.status = 'completed'
GROUP BY u.id, u.username, u.email
ORDER BY total_spent DESC
LIMIT 10;

-- 5. Топ-10 товаров по количеству продаж
SELECT 
    p.name,
    p.category,
    SUM(oi.quantity) as total_sold,
    SUM(oi.total_price) as total_revenue,
    COUNT(DISTINCT oi.order_id) as order_count
FROM test_schema.products p
JOIN test_schema.order_items oi ON p.id = oi.product_id
JOIN test_schema.orders o ON oi.order_id = o.id
WHERE o.status = 'completed'
GROUP BY p.id, p.name, p.category
ORDER BY total_sold DESC
LIMIT 10;

-- 6. Ежедневная статистика продаж (последние 30 дней)
SELECT 
    DATE(created_at) as sale_date,
    COUNT(*) as orders_count,
    SUM(total_amount) as daily_revenue,
    AVG(total_amount) as avg_order_value,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_orders,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_orders
FROM test_schema.orders
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY sale_date DESC;

-- 7. Анализ по категориям товаров
SELECT 
    p.category,
    COUNT(DISTINCT p.id) as products_count,
    SUM(oi.quantity) as total_sold,
    SUM(oi.total_price) as total_revenue,
    AVG(p.price) as avg_price,
    MIN(p.price) as min_price,
    MAX(p.price) as max_price
FROM test_schema.products p
LEFT JOIN test_schema.order_items oi ON p.id = oi.product_id
LEFT JOIN test_schema.orders o ON oi.order_id = o.id AND o.status = 'completed'
GROUP BY p.category
ORDER BY total_revenue DESC;

-- 8. Пользователи с наибольшим количеством заказов
SELECT 
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    COUNT(o.id) as total_orders,
    SUM(CASE WHEN o.status = 'completed' THEN o.total_amount ELSE 0 END) as total_spent,
    MAX(o.created_at) as last_order_date,
    MIN(o.created_at) as first_order_date
FROM test_schema.users u
LEFT JOIN test_schema.orders o ON u.id = o.user_id
GROUP BY u.id, u.username, u.email, u.first_name, u.last_name
HAVING COUNT(o.id) > 0
ORDER BY total_orders DESC, total_spent DESC
LIMIT 20;

-- 9. Анализ больших данных - топ метрики
SELECT 
    metric_name,
    COUNT(*) as data_points,
    MIN(metric_value) as min_value,
    MAX(metric_value) as max_value,
    AVG(metric_value) as avg_value,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY metric_value) as median_value,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY metric_value) as p95_value
FROM test_schema.time_series_data
GROUP BY metric_name
ORDER BY data_points DESC;

-- 10. Анализ по регионам (из временных рядов)
SELECT 
    tags->>'region' as region,
    tags->>'environment' as environment,
    COUNT(*) as data_points,
    AVG(metric_value) as avg_value
FROM test_schema.time_series_data
WHERE tags->>'region' IS NOT NULL
GROUP BY tags->>'region', tags->>'environment'
ORDER BY region, environment;

-- 11. Размеры таблиц
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'test_schema'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- 12. Статистика по индексам
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes 
WHERE schemaname = 'test_schema'
ORDER BY pg_relation_size(indexrelid) DESC;

-- 13. Проверка целостности данных
SELECT 
    'Проверка целостности' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'ERROR: ' || COUNT(*) || ' заказов без пользователей'
    END as result
FROM test_schema.orders o
LEFT JOIN test_schema.users u ON o.user_id = u.id
WHERE u.id IS NULL

UNION ALL

SELECT 
    'Проверка целостности' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'ERROR: ' || COUNT(*) || ' позиций заказов без заказов'
    END as result
FROM test_schema.order_items oi
LEFT JOIN test_schema.orders o ON oi.order_id = o.id
WHERE o.id IS NULL

UNION ALL

SELECT 
    'Проверка целостности' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'ERROR: ' || COUNT(*) || ' позиций заказов без товаров'
    END as result
FROM test_schema.order_items oi
LEFT JOIN test_schema.products p ON oi.product_id = p.id
WHERE p.id IS NULL;

-- 14. Обновление материализованного представления
SELECT test_schema.refresh_daily_sales_summary();

-- 15. Просмотр материализованного представления
SELECT * FROM test_schema.daily_sales_summary 
ORDER BY sale_date DESC 
LIMIT 10;

-- 16. Пример сложного аналитического запроса
WITH user_metrics AS (
    SELECT 
        u.id,
        u.username,
        COUNT(o.id) as order_count,
        SUM(CASE WHEN o.status = 'completed' THEN o.total_amount ELSE 0 END) as total_spent,
        AVG(CASE WHEN o.status = 'completed' THEN o.total_amount ELSE NULL END) as avg_order_value,
        MAX(o.created_at) as last_order_date
    FROM test_schema.users u
    LEFT JOIN test_schema.orders o ON u.id = o.user_id
    GROUP BY u.id, u.username
),
product_metrics AS (
    SELECT 
        p.id,
        p.name,
        p.category,
        COUNT(oi.id) as times_ordered,
        SUM(oi.quantity) as total_quantity_sold,
        SUM(oi.total_price) as total_revenue
    FROM test_schema.products p
    LEFT JOIN test_schema.order_items oi ON p.id = oi.product_id
    LEFT JOIN test_schema.orders o ON oi.order_id = o.id AND o.status = 'completed'
    GROUP BY p.id, p.name, p.category
)
SELECT 
    'Аналитика' as report_type,
    'Пользователи' as category,
    COUNT(*) as total_count,
    COUNT(CASE WHEN order_count > 0 THEN 1 END) as active_users,
    AVG(total_spent) as avg_spent_per_user,
    MAX(total_spent) as max_spent_by_user
FROM user_metrics

UNION ALL

SELECT 
    'Аналитика' as report_type,
    'Товары' as category,
    COUNT(*) as total_count,
    COUNT(CASE WHEN times_ordered > 0 THEN 1 END) as sold_products,
    AVG(total_revenue) as avg_revenue_per_product,
    MAX(total_revenue) as max_revenue_by_product
FROM product_metrics;

-- Вывод финальной статистики
DO $$
DECLARE
    total_size TEXT;
BEGIN
    SELECT pg_size_pretty(pg_database_size(current_database())) INTO total_size;
    RAISE NOTICE '=== ФИНАЛЬНАЯ СТАТИСТИКА ===';
    RAISE NOTICE 'Общий размер базы данных: %', total_size;
    RAISE NOTICE 'Тестовые данные успешно созданы и проверены!';
    RAISE NOTICE '========================';
END $$;


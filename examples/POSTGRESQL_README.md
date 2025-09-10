# PostgreSQL Example with Test Data Generation

Этот пример демонстрирует использование docker-db-backup с PostgreSQL и автоматической генерацией тестовых данных.

## Структура примера

```
examples/
├── init-scripts/
│   ├── 01-create-test-data.sql      # Основные таблицы и базовые данные
│   ├── 02-generate-more-data.sql    # Дополнительные данные для тестирования
│   └── 03-demo-queries.sql          # Демонстрационные запросы
├── postgres-data/                   # Данные PostgreSQL (создается автоматически)
└── backup-data (Docker volume)      # Backup файлы (создается автоматически)
```

## Запуск примера

### 1. Локальный запуск

```bash
# Запуск локального окружения с PostgreSQL
./project.sh -a start -e local

# Просмотр логов
./project.sh -a logs -e local

# Проверка статуса
./project.sh -a info -e local
```

### 2. Подключение к базе данных

```bash
# Подключение к PostgreSQL контейнеру
docker exec -it postgres-db psql -U testuser -d testdb

# Или через docker-compose
docker-compose -f docker-compose.local.yml exec postgres-db psql -U testuser -d testdb
```

## Структура тестовых данных

### Основные таблицы

1. **users** - Пользователи системы
   - 100 записей (10 базовых + 90 сгенерированных)
   - Поля: id, username, email, first_name, last_name, created_at, updated_at, is_active

2. **products** - Товары
   - 200 записей (10 базовых + 190 сгенерированных)
   - Поля: id, name, description, price, category, stock_quantity, created_at, updated_at

3. **orders** - Заказы
   - 500 записей (10 базовых + 490 сгенерированных)
   - Поля: id, user_id, order_number, total_amount, status, created_at, updated_at

4. **order_items** - Позиции заказов
   - Связывает заказы с товарами
   - Поля: id, order_id, product_id, quantity, unit_price, total_price

### Дополнительные таблицы для тестирования

5. **large_data_table** - Большая таблица
   - 10,000 записей с JSON данными и массивами
   - Тестирование производительности backup больших объемов данных

6. **binary_data** - Бинарные данные
   - 100 записей с симуляцией файлов
   - Тестирование backup BLOB данных

7. **time_series_data** - Временные ряды
   - 50,000 записей с метриками
   - Тестирование backup временных данных

8. **audit_log** - Лог изменений
   - Автоматическое логирование изменений в основных таблицах

### Представления и функции

- **order_summary** - Сводка по заказам
- **daily_sales_summary** - Материализованное представление ежедневных продаж
- **update_updated_at_column()** - Функция для автоматического обновления timestamp
- **audit_trigger_function()** - Функция для аудита изменений

## Тестирование backup

### 1. Автоматический backup

Backup запускается автоматически каждые 30 минут в локальном окружении.

### 2. Ручной запуск backup

```bash
# Запуск backup вручную
./project.sh -a backup -e local

# Просмотр логов backup
./project.sh -a logs -e local -s db-backup
```

### 3. Проверка backup файлов

```bash
# Просмотр созданных backup файлов в Docker volume
docker volume ls | grep backup-data
docker run --rm -v backup-data:/backup alpine ls -la /backup/

# Проверка содержимого backup
docker exec -it db-backup-local ls -la /backup/
```

## Демонстрационные запросы

### Подключение к базе и выполнение запросов

```bash
# Подключение к PostgreSQL
docker exec -it postgres-db psql -U testuser -d testdb

# Выполнение демонстрационных запросов
\i /docker-entrypoint-initdb.d/03-demo-queries.sql
```

### Основные запросы для проверки

```sql
-- Статистика по данным
SELECT 
    'users' as table_name, COUNT(*) as count FROM test_schema.users
UNION ALL
SELECT 
    'products' as table_name, COUNT(*) as count FROM test_schema.products
UNION ALL
SELECT 
    'orders' as table_name, COUNT(*) as count FROM test_schema.orders;

-- Топ пользователей по тратам
SELECT 
    u.username,
    SUM(o.total_amount) as total_spent
FROM test_schema.users u
JOIN test_schema.orders o ON u.id = o.user_id
WHERE o.status = 'completed'
GROUP BY u.id, u.username
ORDER BY total_spent DESC
LIMIT 5;

-- Размеры таблиц
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('test_schema.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'test_schema'
ORDER BY pg_total_relation_size('test_schema.'||tablename) DESC;
```

## Мониторинг и метрики

### Prometheus метрики

В локальном окружении включен Prometheus для мониторинга:

```bash
# Проверка метрик Prometheus
curl http://localhost:8080/metrics
```

### Логи backup

```bash
# Просмотр логов backup сервиса
docker-compose -f docker-compose.local.yml logs db-backup

# Фильтрация логов по backup операциям
docker-compose -f docker-compose.local.yml logs db-backup | grep -i backup
```

## Настройка для продакшена

### Переменные окружения

Для продакшена настройте следующие переменные:

```bash
# В .env файле или переменных окружения
DB01_TYPE=postgres
DB01_HOST=your-prod-postgres-host
DB01_NAME=your-prod-database
DB01_USER=your-prod-user
# DB01_PASS будет загружен из Yandex Lockbox

# Yandex Lockbox настройки
YANDEX_LOCKBOX_SECRET_IDS=your-secret-id
YANDEX_LOCKBOX_AUTH_TYPE=metadata
```

### Backup настройки

```bash
# Настройки backup для продакшена
DEFAULT_BACKUP_INTERVAL=1440      # Каждые 24 часа
DEFAULT_BACKUP_BEGIN=0200         # Начинать в 2:00
DEFAULT_CLEANUP_TIME=43200        # Хранить 30 дней
DEFAULT_COMPRESSION=ZSTD          # Сжатие ZSTD
DEFAULT_CHECKSUM=SHA1             # Проверка целостности
```

## Устранение неполадок

### Проблемы с подключением к PostgreSQL

```bash
# Проверка статуса контейнера
docker-compose -f docker-compose.local.yml ps

# Проверка логов PostgreSQL
docker-compose -f docker-compose.local.yml logs postgres-db

# Проверка подключения
docker-compose -f docker-compose.local.yml exec postgres-db pg_isready -U testuser
```

### Проблемы с backup

```bash
# Проверка логов backup
docker-compose -f docker-compose.local.yml logs db-backup

# Ручной запуск backup
docker-compose -f docker-compose.local.yml exec db-backup /assets/functions/backup

# Проверка прав доступа к папке backup
docker-compose -f docker-compose.local.yml exec db-backup ls -la /backup/
```

### Очистка и перезапуск

```bash
# Остановка и удаление контейнеров
./project.sh -a clear -e local

# Удаление данных PostgreSQL (ОСТОРОЖНО!)
sudo rm -rf examples/postgres-data/

# Перезапуск с чистыми данными
./project.sh -a start -e local
```

## Производительность

### Размеры данных

- **users**: ~100 записей
- **products**: ~200 записей  
- **orders**: ~500 записей
- **order_items**: ~1000 записей
- **large_data_table**: ~10,000 записей
- **binary_data**: ~100 записей
- **time_series_data**: ~50,000 записей

**Общий размер базы данных**: ~50-100 MB

### Время backup

- Полный backup: ~30-60 секунд
- Инкрементальный backup: ~5-10 секунд
- Сжатие: ~10-20 секунд

## Дополнительные возможности

### Кастомные скрипты

Добавьте свои скрипты в папку `examples/init-scripts/` с префиксом номера (например, `04-custom-data.sql`).

### Расширение данных

Измените скрипт `02-generate-more-data.sql` для генерации большего количества данных:

```sql
-- Изменить количество записей
FROM generate_series(1, 100000) AS i  -- Вместо 10000
```

### Добавление новых таблиц

Создайте новый скрипт инициализации для добавления специфичных для вашего проекта таблиц.


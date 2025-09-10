# Quick Start Guide - Docker DB Backup

Быстрый старт с PostgreSQL и автоматической генерацией тестовых данных.

## Быстрый запуск

### 1. Запуск локального окружения

```bash
# Клонируйте репозиторий (если еще не сделано)
git clone <repository-url>
cd docker-db-backup

# Запуск локального окружения с PostgreSQL
./project.sh -a start -e local
```

### 2. Проверка работы

```bash
# Проверка статуса сервисов
./project.sh -a info -e local

# Просмотр логов
./project.sh -a logs -e local

# Подключение к PostgreSQL
docker exec -it postgres-db psql -U testuser -d testdb
```

### 3. Тестирование backup

```bash
# Ручной запуск backup
./project.sh -a backup -e local

# Проверка backup файлов (теперь в Docker volume)
docker volume ls | grep backup-data
docker run --rm -v backup-data:/backup alpine ls -la /backup
```

## Что происходит при запуске

1. **PostgreSQL контейнер** запускается с автоматической инициализацией
2. **Создаются тестовые таблицы** с реалистичными данными:
   - 100 пользователей
   - 200 товаров  
   - 500 заказов
   - 10,000 записей в большой таблице
   - 50,000 записей временных рядов
3. **DB Backup сервис** запускается и начинает автоматический backup каждые 30 минут
4. **Prometheus метрики** доступны на порту 8080

## Основные команды

```bash
# Запуск
./project.sh -a start -e local

# Остановка
./project.sh -a stop -e local

# Перезапуск
./project.sh -a restart -e local

# Просмотр логов
./project.sh -a logs -e local

# Backup
./project.sh -a backup -e local

# Информация о сервисах
./project.sh -a info -e local

# Полная очистка
./project.sh -a clear -e local
```

## Проверка данных

### Подключение к PostgreSQL

```bash
docker exec -it postgres-db psql -U testuser -d testdb
```

### Основные запросы

```sql
-- Статистика данных
SELECT 
    'users' as table_name, COUNT(*) as count FROM test_schema.users
UNION ALL
SELECT 'products' as table_name, COUNT(*) as count FROM test_schema.products
UNION ALL
SELECT 'orders' as table_name, COUNT(*) as count FROM test_schema.orders;

-- Топ пользователей
SELECT username, COUNT(*) as order_count 
FROM test_schema.users u
JOIN test_schema.orders o ON u.id = o.user_id
GROUP BY u.id, username
ORDER BY order_count DESC
LIMIT 5;

-- Размеры таблиц
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('test_schema.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'test_schema'
ORDER BY pg_total_relation_size('test_schema.'||tablename) DESC;
```

## Мониторинг

### Prometheus метрики

```bash
# Проверка метрик
curl http://localhost:8080/metrics
```

### Логи backup

```bash
# Логи backup сервиса
docker-compose -f docker-compose.local.yml logs db-backup | grep -i backup
```

## Структура файлов

```
docker-db-backup/
├── project.sh                    # Основной скрипт управления
├── docker-compose.local.yml      # Конфигурация для локального окружения
├── examples/
│   ├── init-scripts/             # SQL скрипты инициализации
│   │   ├── 01-create-test-data.sql
│   │   ├── 02-generate-more-data.sql
│   │   └── 03-demo-queries.sql
│   └── postgres-data/            # Данные PostgreSQL (создается автоматически)
└── backup-data (Docker volume)   # Backup файлы (создается автоматически)
└── POSTGRESQL_README.md          # Подробная документация
```

## Следующие шаги

1. **Изучите подробную документацию**: `POSTGRESQL_README.md`
2. **Настройте продакшн окружение**: используйте `docker-compose.prod.yml`
3. **Интегрируйте с Yandex Lockbox**: для безопасного хранения секретов
4. **Настройте мониторинг**: Prometheus + Grafana
5. **Добавьте уведомления**: email/Slack при ошибках backup

## Устранение неполадок

### Проблемы с запуском

```bash
# Проверка статуса
docker-compose -f docker-compose.local.yml ps

# Проверка логов
docker-compose -f docker-compose.local.yml logs

# Полная перезагрузка
./project.sh -a clear -e local
./project.sh -a start -e local
```

### Проблемы с backup

```bash
# Ручной запуск backup
docker-compose -f docker-compose.local.yml exec db-backup /assets/functions/backup

# Проверка прав доступа
docker run --rm -v backup-data:/backup alpine ls -la /backup/
```

### Очистка данных

```bash
# Остановка сервисов
./project.sh -a clear -e local

# Удаление данных PostgreSQL (ОСТОРОЖНО!)
sudo rm -rf examples/postgres-data/

# Перезапуск с чистыми данными
./project.sh -a start -e local
```

## Поддержка

- **Документация**: `POSTGRESQL_README.md`
- **Примеры**: папка `examples/`
- **Логи**: используйте `./project.sh -a logs -e local`


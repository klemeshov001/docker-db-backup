#!/bin/bash

# Скрипт для тестирования конфигурации S3 + Yandex Lockbox + Prometheus

set -e

echo "🔍 Тестирование конфигурации S3 + Yandex Lockbox + Prometheus"
echo "=========================================================="

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose не установлен"
    exit 1
fi

echo "✅ Docker и Docker Compose установлены"

# Проверка файлов конфигурации
if [ ! -f "compose.yml" ]; then
    echo "❌ Файл compose.yml не найден"
    exit 1
fi

if [ ! -f "compose-key-auth.yml" ]; then
    echo "❌ Файл compose-key-auth.yml не найден"
    exit 1
fi

echo "✅ Файлы конфигурации найдены"

# Проверка переменных окружения в compose.yml
echo ""
echo "📋 Проверка переменных в compose.yml:"

# Проверка обязательных переменных
required_vars=(
    "YANDEX_LOCKBOX_SECRET_IDS"
    "DEFAULT_BACKUP_LOCATION"
    "DEFAULT_S3_BUCKET"
    "DEFAULT_S3_REGION"
    "DEFAULT_S3_HOST"
    "DB01_TYPE"
    "DB01_HOST"
    "DB01_NAME"
    "DB01_USER"
    "CONTAINER_ENABLE_MONITORING"
    "CONTAINER_MONITORING_BACKEND"
    "PROMETHEUS_PORT"
)

for var in "${required_vars[@]}"; do
    if grep -q "${var}=" compose.yml; then
        echo "✅ ${var} - настроена"
    else
        echo "❌ ${var} - не найдена"
    fi
done

# Проверка S3 конфигурации
echo ""
echo "🔐 Проверка S3 конфигурации:"
if grep -q "DEFAULT_BACKUP_LOCATION=S3" compose.yml; then
    echo "✅ S3 как место назначения бекапа"
else
    echo "❌ S3 не настроен как место назначения"
fi

if grep -q "storage.yandexcloud.net" compose.yml; then
    echo "✅ Yandex Object Storage настроен"
else
    echo "⚠️  Проверьте настройку S3_HOST для Yandex Object Storage"
fi

# Проверка Yandex Lockbox конфигурации
echo ""
echo "🔑 Проверка Yandex Lockbox конфигурации:"
if grep -q "YANDEX_LOCKBOX_AUTH_TYPE=metadata" compose.yml; then
    echo "✅ Metadata аутентификация настроена"
elif grep -q "YANDEX_LOCKBOX_AUTH_TYPE=key" compose.yml; then
    echo "✅ Key аутентификация настроена"
else
    echo "❌ Тип аутентификации не указан"
fi

if grep -q "YANDEX_LOCKBOX_SECRET_IDS=" compose.yml; then
    echo "✅ ID секретов указаны"
else
    echo "❌ ID секретов не указаны"
fi

# Проверка Prometheus конфигурации
echo ""
echo "📊 Проверка Prometheus конфигурации:"
if grep -q "CONTAINER_MONITORING_BACKEND=prometheus" compose.yml; then
    echo "✅ Prometheus как бэкенд мониторинга"
else
    echo "❌ Prometheus не настроен как бэкенд"
fi

if grep -q "PROMETHEUS_PORT=9090" compose.yml; then
    echo "✅ Порт Prometheus настроен"
else
    echo "❌ Порт Prometheus не настроен"
fi

if grep -q "9090:9090" compose.yml; then
    echo "✅ Порт 9090 проброшен"
else
    echo "❌ Порт 9090 не проброшен"
fi

# Проверка конфигурации базы данных
echo ""
echo "🗄️  Проверка конфигурации базы данных:"
if grep -q "DB01_TYPE=mariadb" compose.yml; then
    echo "✅ MariaDB как тип базы данных"
else
    echo "⚠️  Проверьте тип базы данных"
fi

if grep -q "DB01_HOST=example-db-host" compose.yml; then
    echo "✅ Хост базы данных настроен"
else
    echo "⚠️  Проверьте хост базы данных"
fi

# Проверка настроек бекапа
echo ""
echo "💾 Проверка настроек бекапа:"
if grep -q "DEFAULT_COMPRESSION=ZSTD" compose.yml; then
    echo "✅ ZSTD сжатие настроено"
else
    echo "⚠️  Проверьте настройки сжатия"
fi

if grep -q "DEFAULT_CHECKSUM=SHA1" compose.yml; then
    echo "✅ SHA1 контрольная сумма настроена"
else
    echo "⚠️  Проверьте настройки контрольной суммы"
fi

# Проверка расписания
echo ""
echo "⏰ Проверка расписания:"
if grep -q "DEFAULT_BACKUP_INTERVAL=1440" compose.yml; then
    echo "✅ Интервал бекапа: 24 часа (1440 минут)"
else
    echo "⚠️  Проверьте интервал бекапа"
fi

if grep -q "DEFAULT_CLEANUP_TIME=10080" compose.yml; then
    echo "✅ Время хранения: 7 дней (10080 минут)"
else
    echo "⚠️  Проверьте время хранения"
fi

echo ""
echo "🎯 Рекомендации по настройке:"
echo "1. Замените ID секретов на реальные: e1q2w3e4r5t6y7u8i9o0p, a1s2d3f4g5h6j7k8l9z0x"
echo "2. Обновите имя бакета: DEFAULT_S3_BUCKET=my-backup-bucket"
echo "3. При необходимости измените регион: DEFAULT_S3_REGION=ru-central1"
echo "4. Проверьте права доступа Service Account к Lockbox и Object Storage"
echo "5. Убедитесь, что секреты в Lockbox содержат правильные ключи"

echo ""
echo "🚀 Для запуска используйте:"
echo "docker-compose -f compose.yml up -d"
echo ""
echo "📊 Для проверки метрик:"
echo "curl http://localhost:9090"
echo ""
echo "📝 Для просмотра логов:"
echo "docker-compose logs -f example-db-backup"

echo ""
echo "✅ Тестирование конфигурации завершено"

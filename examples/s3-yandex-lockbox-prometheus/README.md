
Этот пример демонстрирует настройку системы бекапа базы данных с использованием:
- **S3-совместимого хранилища** (Yandex Object Storage) для хранения бекапов
- **Yandex Lockbox** для безопасного хранения секретов (пароли, ключи доступа)
- **Prometheus** для мониторинга процесса бекапа

## Архитектура

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   MariaDB DB    │    │  Backup Service  │    │  Yandex Cloud   │
│                 │    │                  │    │                 │
│ - example-db    │◄──►│ - example-db-    │◄──►│ - Lockbox       │
│ - Port 3306     │    │   backup         │    │ - Object Storage│
│                 │    │ - Prometheus     │    │                 │
└─────────────────┘    │   metrics        │    └─────────────────┘
                       │ - Port 9090      │
                       └──────────────────┘
```

## Требования

1. **Yandex Cloud аккаунт** с настроенными сервисами:
   - Object Storage (S3-совместимое хранилище)
   - Lockbox (для хранения секретов)
   - Compute Instance (если используется metadata аутентификация)

2. **Docker и Docker Compose**

3. **Созданные секреты в Yandex Lockbox** (см. раздел "Настройка секретов")

## Настройка секретов в Yandex Lockbox

### 1. Секрет для пароля базы данных

Создайте секрет с ID `e1q2w3e4r5t6y7u8i9o0p` и содержимым:

```json
{
  "entries": [
    {
      "key": "DB01_PASS",
      "textValue": "your_database_password"
    }
  ]
}
```

### 2. Секрет для S3 ключей доступа

Создайте секрет с ID `a1s2d3f4g5h6j7k8l9z0x` и содержимым:

```json
{
  "entries": [
    {
      "key": "DEFAULT_S3_KEY_ID",
      "textValue": "your_s3_access_key"
    },
    {
      "key": "DEFAULT_S3_KEY_SECRET",
      "textValue": "your_s3_secret_key"
    }
  ]
}
```

## Настройка аутентификации

### Метод 1: Metadata аутентификация (рекомендуется для Yandex Cloud)

Используйте файл `compose.yml`. Система автоматически получит IAM токен из сервиса метаданных.

**Требования:**
- Запуск на Compute Instance в Yandex Cloud
- Назначенная IAM роль с правами на доступ к Lockbox

### Метод 2: Key аутентификация

Используйте файл `compose-key-auth.yml` и настройте Service Account ключ.

**Шаги:**
1. Создайте Service Account в Yandex Cloud
2. Назначьте роли: `lockbox.payloadViewer`, `storage.editor`
3. Создайте авторизованный ключ
4. Вставьте JSON ключа в переменную `YANDEX_LOCKBOX_SERVICE_ACCOUNT_KEY`

## Настройка S3 хранилища

### Yandex Object Storage

1. Создайте бакет в Object Storage
2. Получите ключи доступа (Static Access Key)
3. Обновите переменные в compose файле:

```yaml
- DEFAULT_S3_BUCKET=your-bucket-name
- DEFAULT_S3_REGION=ru-central1
- DEFAULT_S3_HOST=storage.yandexcloud.net
```

## Запуск

### 1. Клонируйте репозиторий

```bash
git clone https://github.com/tiredofit/docker-db-backup.git
cd docker-db-backup/examples/s3-yandex-lockbox-prometheus
```

### 2. Настройте переменные

Отредактируйте `compose.yml` или `compose-key-auth.yml`:

- Замените `e1q2w3e4r5t6y7u8i9o0p, a1s2d3f4g5h6j7k8l9z0x` на ваши реальные ID секретов
- Обновите `DEFAULT_S3_BUCKET` на имя вашего бакета

### 3. Запустите сервисы

```bash
# Для metadata аутентификации
docker-compose -f compose.yml up -d

# Для key аутентификации
docker-compose -f compose-key-auth.yml up -d
```

### 4. Проверьте статус

```bash
# Проверьте логи
docker-compose logs -f example-db-backup

# Проверьте метрики Prometheus
curl http://localhost:9090
```

## Мониторинг с Prometheus

### Доступные метрики

Система предоставляет следующие метрики на порту 9090:

- `dbbackup_backup_status` - статус бекапа (0=успех, 1=ошибка)
- `dbbackup_backup_duration_seconds` - время выполнения бекапа
- `dbbackup_backup_size_bytes` - размер файла бекапа
- `dbbackup_backup_timestamp` - временная метка завершения
- `dbbackup_jobs_total` - общее количество задач
- `dbbackup_jobs_failed_total` - количество неудачных задач
- `dbbackup_jobs_success_total` - количество успешных задач

### Настройка Prometheus

Добавьте в `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'db-backup'
    static_configs:
      - targets: ['localhost:9090']
```

## Конфигурация бекапа

### Расписание

- **Интервал**: 1440 минут (24 часа)
- **Начало**: сразу после запуска (`+0`)
- **Очистка**: 10080 минут (7 дней)

### Сжатие и проверки

- **Сжатие**: ZSTD (высокая степень сжатия)
- **Контрольная сумма**: SHA1
- **Параллельность**: 1 задача одновременно

## Отладка

### Включение отладочных логов

```yaml
- DEBUG_MODE=TRUE
- DEBUG_YANDEX_LOCKBOX=TRUE
- DEBUG_PROMETHEUS=TRUE
```

### Проверка секретов

```bash
# Проверьте загрузку секретов
docker-compose exec example-db-backup env | grep -E "(DB01_PASS|S3_KEY)"

# Проверьте логи Lockbox
docker-compose logs example-db-backup | grep -i lockbox
```

## Безопасность

### Рекомендации

1. **Используйте metadata аутентификацию** в Yandex Cloud
2. **Ограничьте права** Service Account минимально необходимыми
3. **Шифруйте бекапы** при необходимости
4. **Мониторьте доступ** к секретам через Cloud Audit Logs
5. **Регулярно ротируйте** ключи доступа

### Шифрование бекапов

Добавьте в секрет Lockbox:

```json
{
  "entries": [
    {
      "key": "DB01_ENCRYPT_PASSPHRASE",
      "textValue": "your_encryption_passphrase"
    }
  ]
}
```

И настройте в compose файле:

```yaml
- DB01_ENCRYPTION=TRUE
- DB01_ENCRYPTION_ALGORITHM=AES256
```

## Поддержка

- [Документация проекта](https://github.com/tiredofit/docker-db-backup)
- [Issues на GitHub](https://github.com/tiredofit/docker-db-backup/issues)
- [Yandex Cloud документация](https://cloud.yandex.ru/docs/)
# Пример бекапа с S3, Yandex Lockbox и Prometheus


# Yandex Lockbox Integration

Этот пример демонстрирует, как интегрировать Yandex Cloud Lockbox с docker-db-backup для безопасного хранения и получения секретов (паролей, ключей и т.д.).

## Что такое Yandex Lockbox?

Yandex Lockbox - это сервис для безопасного хранения секретов в Yandex Cloud. Он позволяет:
- Хранить пароли, ключи API, сертификаты и другие секретные данные
- Автоматически ротировать секреты
- Контролировать доступ к секретам через IAM
- Интегрироваться с другими сервисами Yandex Cloud

## Настройка Yandex Lockbox

### 1. Создание секрета в Lockbox

1. Откройте консоль Yandex Cloud
2. Перейдите в раздел "Lockbox"
3. Создайте новый секрет
4. Добавьте ключи и значения (например):
   ```
   DB01_PASS=your_database_password
   S3_KEY_SECRET=your_s3_secret_key
   ENCRYPT_PASSPHRASE=your_encryption_key
   ```

### 2. Настройка аутентификации

#### Вариант A: Автоматическая аутентификация через metadata (в Yandex Cloud)

Если контейнер запускается в Yandex Cloud (Compute Instance, Kubernetes, etc.), используется автоматическая аутентификация:

```bash
# Создание роли для доступа к Lockbox
yc iam role create --name lockbox-reader

# Привязка роли к сервисному аккаунту
yc iam service-account add-binding \
  --name your-service-account \
  --role-id lockbox-reader \
  --service-account-id your-service-account-id
```

#### Вариант B: Аутентификация по ключу (для внешних сред)

Для запуска вне Yandex Cloud или с пользовательским сервисным аккаунтом:

1. Создайте сервисный аккаунт:
```bash
yc iam service-account create --name lockbox-access
```

2. Создайте ключ для сервисного аккаунта:
```bash
yc iam key create --service-account-name lockbox-access --output key.json
```

3. Назначьте права на чтение секретов:
```bash
yc resource-manager folder add-access-binding <folder-id> \
  --role lockbox.payloadViewer \
  --subject serviceAccount:<service-account-id>
```

4. Используйте ключ в конфигурации:
```yaml
environment:
  - YANDEX_LOCKBOX_AUTH_TYPE=key
  - YANDEX_LOCKBOX_SERVICE_ACCOUNT_KEY={"id":"aje...","service_account_id":"aje...","private_key":"-----BEGIN PRIVATE KEY-----\n..."}
```

## Конфигурация

### Переменные окружения

| Переменная | Описание | Пример |
|------------|----------|--------|
| `YANDEX_LOCKBOX_SECRET_IDS` | Список ID секретов через запятую | `e1q2w3e4r5t6y7u8i9o0p, a1s2d3f4g5h6j7k8l9z0x` |
| `YANDEX_LOCKBOX_AUTH_TYPE` | Тип аутентификации | `metadata`, `key`, `service-account-key` |
| `YANDEX_LOCKBOX_SERVICE_ACCOUNT_KEY` | JSON ключ сервисного аккаунта | `{"id":"aje...","service_account_id":"aje...","private_key":"-----BEGIN PRIVATE KEY-----\n..."}` |
| `YANDEX_LOCKBOX_SERVICE_ACCOUNT_ID` | ID сервисного аккаунта | `aje...` |
| `YANDEX_LOCKBOX_METADATA_URL` | URL сервиса метаданных | `http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token` |
| `YANDEX_LOCKBOX_API_URL` | URL API Lockbox | `https://payload.lockbox.api.cloud.yandex.net/lockbox/v1/secrets` |
| `DEBUG_YANDEX_LOCKBOX` | Включить отладочные логи | `TRUE` или `FALSE` |

### Примеры использования

#### Metadata аутентификация (в Yandex Cloud)

```yaml
version: '3.8'

services:
  db-backup:
    image: tiredofit/db-backup
    environment:
      # Yandex Lockbox configuration
      - YANDEX_LOCKBOX_SECRET_IDS=e1q2w3e4r5t6y7u8i9o0p, a1s2d3f4g5h6j7k8l9z0x
      - YANDEX_LOCKBOX_AUTH_TYPE=metadata
      - DEBUG_YANDEX_LOCKBOX=FALSE
      
      # Database configuration (пароль будет загружен из Lockbox)
      - DB01_TYPE=mariadb
      - DB01_HOST=db-host
      - DB01_NAME=example
      - DB01_USER=example
      # DB01_PASS будет автоматически загружен из Lockbox
```

#### Key аутентификация (вне Yandex Cloud)

```yaml
version: '3.8'

services:
  db-backup:
    image: tiredofit/db-backup
    environment:
      # Yandex Lockbox configuration
      - YANDEX_LOCKBOX_SECRET_IDS=e1q2w3e4r5t6y7u8i9o0p
      - YANDEX_LOCKBOX_AUTH_TYPE=key
      - YANDEX_LOCKBOX_SERVICE_ACCOUNT_KEY={"id":"aje...","service_account_id":"aje...","private_key":"-----BEGIN PRIVATE KEY-----\n..."}
      - DEBUG_YANDEX_LOCKBOX=FALSE
      
      # Database configuration
      - DB01_TYPE=mariadb
      - DB01_HOST=db-host
      - DB01_NAME=example
      - DB01_USER=example
      # DB01_PASS будет автоматически загружен из Lockbox
```

## Структура секретов в Lockbox

### Пример секрета для базы данных

```json
{
  "entries": [
    {
      "key": "DB01_PASS",
      "textValue": "your_secure_password"
    },
    {
      "key": "DB02_PASS", 
      "textValue": "another_secure_password"
    }
  ]
}
```

### Пример секрета для S3

```json
{
  "entries": [
    {
      "key": "S3_KEY_ID",
      "textValue": "your_s3_access_key"
    },
    {
      "key": "S3_KEY_SECRET",
      "textValue": "your_s3_secret_key"
    }
  ]
}
```

### Пример секрета для шифрования

```json
{
  "entries": [
    {
      "key": "ENCRYPT_PASSPHRASE",
      "textValue": "your_encryption_passphrase"
    }
  ]
}
```

## Как это работает

1. **Инициализация**: При запуске контейнера система проверяет наличие переменной `YANDEX_LOCKBOX_SECRET_IDS`
2. **Получение токена**: Система получает IAM токен из сервиса метаданных Yandex Cloud
3. **Загрузка секретов**: Для каждого ID секрета система:
   - Вызывает API Lockbox для получения содержимого секрета
   - Парсит JSON ответ и извлекает ключи и значения
   - Создает временный файл с переменными окружения
   - Загружает переменные в текущую сессию
4. **Использование**: Все загруженные секреты становятся доступны как обычные переменные окружения

## Безопасность

- **IAM токены**: Автоматически получаются из сервиса метаданных
- **Временные файлы**: Создаются в `/tmp` и автоматически удаляются
- **Логирование**: Секретные значения не записываются в логи
- **Права доступа**: Контролируются через IAM роли Yandex Cloud

## Отладка

Для включения отладочных логов установите:

```bash
DEBUG_YANDEX_LOCKBOX=TRUE
```

Это включит подробное логирование операций с Lockbox (без вывода секретных значений).

## Обработка ошибок

Система обрабатывает следующие ошибки:
- Недоступность сервиса метаданных
- Неверные IAM токены
- Отсутствие прав доступа к секретам
- Неверные ID секретов
- Ошибки API Lockbox

При ошибках система продолжает работу, но выводит предупреждения в логи.

## Примеры использования

### База данных с паролем из Lockbox

```yaml
environment:
  - YANDEX_LOCKBOX_SECRET_IDS=db-secrets-id
  - DB01_TYPE=mariadb
  - DB01_HOST=db-host
  - DB01_NAME=example
  - DB01_USER=example
  # DB01_PASS будет загружен из Lockbox
```

### S3 с ключами из Lockbox

```yaml
environment:
  - YANDEX_LOCKBOX_SECRET_IDS=s3-secrets-id
  - DB01_TYPE=mariadb
  - DB01_BACKUP_LOCATION=S3
  - DB01_S3_BUCKET=my-backup-bucket
  # S3_KEY_ID и S3_KEY_SECRET будут загружены из Lockbox
```

### Шифрование с ключом из Lockbox

```yaml
environment:
  - YANDEX_LOCKBOX_SECRET_IDS=encryption-secrets-id
  - DB01_ENCRYPT=TRUE
  # ENCRYPT_PASSPHRASE будет загружен из Lockbox
```

## Совместимость

Yandex Lockbox интеграция совместима со всеми существующими функциями:
- Все типы баз данных
- Все методы хранения (файловая система, S3, Azure)
- Шифрование и сжатие
- Мониторинг (Prometheus, Zabbix)
- Уведомления

## Требования

- Контейнер должен запускаться в Yandex Cloud (Compute Instance, Kubernetes, etc.)
- Сервисный аккаунт должен иметь права на чтение секретов Lockbox
- Доступ к сервису метаданных Yandex Cloud

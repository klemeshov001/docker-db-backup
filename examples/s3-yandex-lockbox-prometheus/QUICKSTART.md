# Быстрый старт: S3 + Yandex Lockbox + Prometheus

## 🚀 Быстрый запуск

### 1. Подготовка Yandex Cloud

1. **Создайте бакет в Object Storage:**
   ```bash
   yc storage bucket create --name my-backup-bucket
   ```

2. **Создайте секреты в Lockbox:**
   ```bash
   # Секрет для пароля БД
   yc lockbox secret create --name db-password --payload '{"entries":[{"key":"DB01_PASS","textValue":"your_password"}]}'
   
   # Секрет для S3 ключей
   yc lockbox secret create --name s3-credentials --payload '{"entries":[{"key":"DEFAULT_S3_KEY_ID","textValue":"your_access_key"},{"key":"DEFAULT_S3_KEY_SECRET","textValue":"your_secret_key"}]}'
   ```

3. **Получите ID секретов:**
   ```bash
   yc lockbox secret list
   ```

### 2. Настройка конфигурации

1. **Отредактируйте `compose.yml`:**
   ```yaml
   # Замените на ваши ID секретов
   - YANDEX_LOCKBOX_SECRET_IDS=e1q2w3e4r5t6y7u8i9o0p, a1s2d3f4g5h6j7k8l9z0x
   
   # Замените на имя вашего бакета
   - DEFAULT_S3_BUCKET=my-backup-bucket
   ```

### 3. Запуск

```bash
# Запустите сервисы
docker-compose -f compose.yml up -d

# Проверьте статус
docker-compose ps

# Посмотрите логи
docker-compose logs -f example-db-backup
```

### 4. Проверка

```bash
# Проверьте метрики Prometheus
curl http://localhost:9090

# Проверьте загрузку секретов
docker-compose exec example-db-backup env | grep -E "(DB01_PASS|S3_KEY)"
```

## 📊 Мониторинг

### Prometheus
- **URL:** http://localhost:9090
- **Метрики:** Все метрики бекапа доступны по умолчанию

### Grafana (опционально)
1. Импортируйте `grafana-dashboard.json`
2. Настройте источник данных Prometheus
3. Наслаждайтесь дашбордом!

## 🔧 Отладка

```bash
# Включите отладочные логи
export DEBUG_MODE=TRUE
export DEBUG_YANDEX_LOCKBOX=TRUE
export DEBUG_PROMETHEUS=TRUE

# Перезапустите контейнер
docker-compose restart example-db-backup
```

## 📝 Полезные команды

```bash
# Проверка конфигурации
./test-config.sh

# Принудительный запуск бекапа
docker-compose exec example-db-backup /usr/local/bin/backup.sh

# Просмотр файлов бекапа в S3
aws s3 ls s3://my-backup-bucket/backups/ --endpoint-url https://storage.yandexcloud.net
```

## ⚠️ Важные замечания

1. **Безопасность:** Используйте metadata аутентификацию в Yandex Cloud
2. **Права доступа:** Убедитесь, что Service Account имеет права на Lockbox и Object Storage
3. **Секреты:** Никогда не храните секреты в коде
4. **Мониторинг:** Настройте алерты в Prometheus/Grafana

## 🆘 Поддержка

- [Полная документация](README.md)
- [Issues на GitHub](https://github.com/tiredofit/docker-db-backup/issues)
- [Yandex Cloud документация](https://cloud.yandex.ru/docs/)

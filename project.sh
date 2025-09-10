#!/bin/bash

PROJECT_NAME=db-backup
LOG_LEVEL=critical

variables_to_check=("PROJECT_NAME" "TAG" "ENVIRONMENT" "LOG_LEVEL")

# ANSI escape codes for colors
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Подсветка вывода в консоль основных этапов
highlight() {
    local current_time
    current_time=$(date "+%Y-%m-%d %H:%M:%S") # Получение текущей даты и времени
    printf "\033[33m%s - %s\033[0m\n" "$current_time" "$*"
}

redlight() {
    local current_time
    current_time=$(date "+%Y-%m-%d %H:%M:%S") # Получение текущей даты и времени
    printf "\033[1m\033[38;5;196m%s - %s\033[0m\n" "$current_time" "!!!! $*"
}

while getopts "t:a:e:v:s:" opt; do
  case $opt in
    t) TAG=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]');;
    a) ACTION=$OPTARG;;    
    e) ENVIRONMENT=$OPTARG;;
    v) LOG_LEVEL=$OPTARG;;
    s) SERVICE=$OPTARG;;
    \?) echo "Invalid option -$OPTARG" >&2
        exit 1;;
  esac
done

env_check() {
    field_width=20
    echo -e "${GREEN}===============================================${RESET}"

    if [[ "$ACTION" == "restart" ]]; then
        variables_to_check=("PROJECT_NAME" "ENVIRONMENT" "LOG_LEVEL")
    fi

    for variable in "${variables_to_check[@]}"; do
        if [ -z "${!variable}" ]; then
            redlight "Ошибка: обязательный параметр $variable не задан." >&2
        else
            export $variable
            printf "${YELLOW}%-${field_width}s: ${!variable}${RESET}\n" "$variable"
        fi
    done
    printf "${YELLOW}%-${field_width}s: $(date "+%Y-%m-%d %H:%M:%S")${RESET}\n" "TIME"
    echo -e "${GREEN}===============================================${RESET}"

    # Проверьте, установлен ли ENVIRONMENT
    if [ "$ENVIRONMENT" = "prod" ] || [ "$ENVIRONMENT" = "test" ]; then
        # Проверка наличия файла
        if [ ! -f "yandex-cloud.key.json" ]; then
            redlight "Ошибка: файл yandex-cloud.key.json не найден. Нужен для авторизации в Yandex Cloud"
            exit 1
        fi
    fi
}

visual_delay() {
    local seconds=$1
    while [ $seconds -gt 0 ]; do
        echo -ne "\r       "
        echo -ne "${YELLOW}... \r$seconds${RESET}"
        sleep 1
        ((seconds--))
    done
    # Очищаем текущую строку и переводим на новую
    echo -ne "\r       \n"
}

git_update() {
    highlight "....обновление кода"
    local CURRENT_BRANCH
    
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    highlight "....текущая ветка "$CURRENT_BRANCH" окружения "$ENVIRONMENT""
    if [ "$ENVIRONMENT" = "prod" ]; then
        # Проверяем, находимся ли мы на ветке master
        if [ "$CURRENT_BRANCH" != "master" ]; then
            highlight "....Переключаемся на ветку master"
            git checkout master
            if [ $? -ne 0 ]; then
                redlight "Ошибка: переключение на ветку master не успешно."
                return 1
            fi
        fi
        highlight "....скачиваем код с ветки origin master..."
        git pull origin master || exit 1

    elif [ "$ENVIRONMENT" = "test" ] && [[ ! "$TAG" =~ dev ]]; then
        highlight "....проверяем, находимся ли мы на ветке test"
        if [ "$CURRENT_BRANCH" != "test" ]; then
            highlight "....переключаемся на ветку test"
            git checkout test || {
                redlight "Ошибка: переключение на ветку test не успешно."
                return 1
            }
            highlight "....скачиваем код с ветки origin test"
            git reset --hard origin/test
            git pull origin test || exit 1
        else
            highlight "....уже на ветке test, переключение не требуется."
        fi
    elif [ "$ENVIRONMENT" = "test" ] && [[ "$TAG" =~ dev ]]; then
        highlight "....TAG содержит 'dev', переключение на test пропускаем."
    fi

    return 0
}

docker_login() {
    highlight "....авторизация в cr.yandex"
    cat yandex-cloud.key.json | docker login -u json_key --password-stdin cr.yandex || { 
        redlight "Ошибка: авторизация докер не успешна"; 
        exit 1; 
    }
}

docker_pull() {
    highlight "....загрузка образов Docker"
    if [ "$ENVIRONMENT" = "local" ]; then
        # Для локального окружения - сборка образов
        highlight "....сборка образов для локального окружения"
        docker compose -f docker-compose.$ENVIRONMENT.yml build || { 
            redlight "Ошибка: Сборка образов не успешна"; 
            exit 1;
        }
    else
        # Для prod/test окружений - загрузка образов из registry
        docker compose -f docker-compose.$ENVIRONMENT.yml pull || { 
            redlight "Ошибка: Скачивание образа не успешно"; 
            exit 1;
        }
    fi
}

create_or_inspect_network() {
    highlight "....проверка сетей Docker"
    # Создаем сеть для проекта если её нет
    if ! docker network ls | grep -q "$PROJECT_NAME-$ENVIRONMENT"; then
        highlight "....создание сети $PROJECT_NAME-$ENVIRONMENT"
        docker network create $PROJECT_NAME-$ENVIRONMENT || {
            redlight "Ошибка: не удалось создать сеть $PROJECT_NAME-$ENVIRONMENT"
            exit 1
        }
    else
        highlight "....сеть $PROJECT_NAME-$ENVIRONMENT уже существует"
    fi
}

init() {
    highlight "Инициализация проекта...."
    if [ "$ENVIRONMENT" = "prod" ] || [ "$ENVIRONMENT" = "test" ]; then
            highlight "....окружение $ENVIRONMENT"  
            highlight "....проверка сетей Docker"     
            create_or_inspect_network
            sleep 2
            git_update
            sleep 2
            docker_login
    else
        if [ "$ENVIRONMENT" = "local" ]; then
            highlight "....локальный запуск"
            # Сборка образов будет выполнена в docker_pull()
        fi
    fi
}

start_commands() {
    highlight "Деплой стека..."
    sleep 2
    if [ "$ENVIRONMENT" = "prod" ]; then
        if ! docker stack ls | grep -q "$PROJECT_NAME-$ENVIRONMENT"; then
            highlight "....приложение"
            docker stack deploy -c docker-compose.$ENVIRONMENT.yml --with-registry-auth --prune $PROJECT_NAME-$ENVIRONMENT
        else
            highlight "Стек $PROJECT_NAME-$ENVIRONMENT уже запущен. Пропускаем."
        fi
    elif [ "$ENVIRONMENT" = "test" ]; then
        if ! docker stack ls | grep -q "$PROJECT_NAME-$ENVIRONMENT"; then
            highlight "....приложение"
            docker stack deploy -c docker-compose.$ENVIRONMENT.yml --with-registry-auth --prune $PROJECT_NAME-$ENVIRONMENT
        else
            highlight "Стек $PROJECT_NAME-$ENVIRONMENT уже запущен. Пропускаем."
        fi
    elif [ "$ENVIRONMENT" = "local" ]; then
        highlight "....локальное окружение"
        if ! docker compose -f docker-compose.$ENVIRONMENT.yml ps --services --filter "status=running" | grep -q "postgres-db\|db-backup"; then
            highlight "....запуск контейнеров"
            docker compose -f docker-compose.$ENVIRONMENT.yml up -d
        else
            highlight "Контейнеры локального окружения уже запущены. Пропускаем."
        fi
    fi
}

info() {
    if [ -z "$ENVIRONMENT" ]; then
        redlight "Ошибка: Укажите окружение -e"
        exit 1
    fi
    highlight "Вывод информации о запущенном стеке"           
    
    if [ "$ENVIRONMENT" = "local" ]; then
        # Для локального окружения используем docker compose
        docker compose -f docker-compose.$ENVIRONMENT.yml ps
        highlight "Логи контейнеров:"
        docker compose -f docker-compose.$ENVIRONMENT.yml logs --tail=20
    else
        # Для prod/test используем docker stack
        docker stack services $PROJECT_NAME-$ENVIRONMENT

        # Получаем список сервисов, фильтруя по маске имени
        services=$(docker service ls --format '{{.Name}}' | grep "^$PROJECT_NAME-$ENVIRONMENT")
        images=$(docker image ls --format '{{.Repository}}' | grep "$PROJECT_NAME" | head -n 1)

        # Проверяем, что список сервисов не пуст
        if [ -z "$services" ]; then
            redlight "Ошибка: Сервисы не найдены по маске: $PROJECT_NAME-$ENVIRONMENT"
            exit 1
        fi
        highlight "Образы проекта $PROJECT_NAME"
        docker image ls $images
        # Для каждого сервиса получаем информацию о его задаче
        for service in $services; do
            highlight "Информация о сервисе: $service"
            docker service ps "$service" \
                --no-trunc \
                --format '{{.Name}}: {{.CurrentState}} {{.Error}}' \
                --filter "desired-state=running" \
                --filter "desired-state=pending"
        done
    fi
}

restart_service() {
    highlight "Перезапуск сервиса..."
    
    if [ "$ENVIRONMENT" = "local" ]; then
        # Для локального окружения используем docker compose
        if [ -n "$SERVICE" ]; then
            highlight "Перезапуск сервиса $SERVICE в локальном окружении"
            docker compose -f docker-compose.$ENVIRONMENT.yml restart $SERVICE
        else
            highlight "Перезапуск всех сервисов в локальном окружении"
            docker compose -f docker-compose.$ENVIRONMENT.yml restart
        fi
        return 0
    fi
    
    highlight "Доступные сервисы в стеке $PROJECT_NAME-$ENVIRONMENT:"

    # Получаем список запущенных сервисов в стеке
    services=$(docker stack services --format '{{.Name}}' $PROJECT_NAME-$ENVIRONMENT)

    # Выводим значение переменной services
    echo "$services"

    # Проверяем, что есть доступные сервисы
    if [ -z "$services" ]; then
        redlight "Ошибка: Нет доступных сервисов для перезапуска."
        exit 1
    fi

    # Если переменная SERVICE установлена, используем её
    if [[ -n "$SERVICE" ]]; then
        service="${PROJECT_NAME}-${ENVIRONMENT}_${SERVICE}"
        # Выводим значение переменной service
        echo "$service"
        
        if [[ ! "$services" =~ "$service" ]]; then
            redlight "Ошибка: Сервис $service не найден в стеке."
            exit 1
        fi
        highlight "Вы выбрали сервис: $service"
    else
        # Выводим список сервисов и запрашиваем пользователя о выборе
        select service in $services; do
            if [ -n "$service" ]; then
                highlight "Вы выбрали сервис: $service"                
                break
            else
                redlight "Ошибка: Пожалуйста, выберите действительный сервис."
            fi
        done
    fi

    # Вытащим тег образа сервиса и уберем все после @
    TAG=$(docker service inspect "$service" --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' | awk -F':' '{print $2}' | awk -F'@' '{print $1}')
    
    if [ -z "$TAG" ]; then
        redlight "Ошибка: Не удается получить тег образа сервиса $service."
        exit 1
    fi

    echo "TAG=$TAG"
    export TAG

    highlight "Тег образа для сервиса $service: $TAG"

    # Ждем, чтобы убедиться, что сервис удален
    docker service rm "$service" || { redlight "Ошибка: не удалось удалить сервис $service"; exit 1; }

    sleep 5

    # Запускаем удаленный сервис
    highlight "Запускаем удаленный сервис $service..."
    docker stack deploy -c docker-compose.$ENVIRONMENT.yml --with-registry-auth --prune $PROJECT_NAME-$ENVIRONMENT

    # Проверка, что сервис доступен
    highlight "Проверка доступности сервиса $service..."
    for i in {1..30}; do
        sleep 5  # Проверяем каждые 5 секунд
        status=$(docker service ps "$service" --format '{{.CurrentState}}' | grep -E 'Running|Pending')

        if [[ "$status" == *"Running"* ]]; then
            highlight "Сервис $service успешно перезапущен и доступен."
            return
        fi

        if [[ "$status" == *"Failed"* ]]; then
            redlight "Ошибка: Сервис $service не запустился корректно."
            return
        fi

        highlight "Сервис $service еще в процессе запуска... Проверяем статус снова."
    done

    redlight "Ошибка: Сервис $service по-прежнему недоступен через 150 секунд."
}

clear_commands() {
    if [ "$ENVIRONMENT" = "local" ]; then
        highlight "Остановка локального окружения"
        docker compose -f docker-compose.$ENVIRONMENT.yml down
    else
        highlight "Удаление стека $PROJECT_NAME-$ENVIRONMENT"
        docker stack rm $PROJECT_NAME-$ENVIRONMENT
    fi
}

start() { 
    if [ "$ENVIRONMENT" = "prod" ]; then
            start_commands
    elif [ "$ENVIRONMENT" = "test" ]; then
            start_commands
    else
        if [ "$ENVIRONMENT" = "local" ]; then
            highlight "Запуск локального окружения"
            docker compose -f docker-compose.$ENVIRONMENT.yml up -d
        fi
    fi
}

update() { 
    echo "Release $ENVIRONMENT $TAG"
    if [ "$ENVIRONMENT" = "prod" ]; then
            update_stack
    elif [ "$ENVIRONMENT" = "test" ]; then
            LOG_LEVEL=debug
            update_stack
    else
        if [ "$ENVIRONMENT" = "local" ]; then
            TAG=latest
            LOG_LEVEL=debug
            highlight "Обновление локального окружения"
            # Сборка образов будет выполнена в docker_pull()
            docker compose -f docker-compose.$ENVIRONMENT.yml up -d
        fi
    fi
}

update_stack() {
    highlight "Обновление стека..."
    docker stack deploy -c docker-compose.$ENVIRONMENT.yml --with-registry-auth --prune $PROJECT_NAME-$ENVIRONMENT
}

stop() {
    if [ "$ENVIRONMENT" = "local" ]; then
        highlight "Остановка локального окружения"
        docker compose -f docker-compose.$ENVIRONMENT.yml stop
    else
        highlight "Остановка стека $PROJECT_NAME-$ENVIRONMENT"
        docker stack rm $PROJECT_NAME-$ENVIRONMENT
    fi
}

backup() {
    highlight "Выполнение backup операций..."
    
    if [ "$ENVIRONMENT" = "local" ]; then
        # Для локального окружения - запуск backup вручную
        highlight "Запуск backup в локальном контейнере"
        docker compose -f docker-compose.$ENVIRONMENT.yml exec db-backup /assets/functions/backup
    else
        # Для prod/test - запуск backup через docker service
        local backup_service="${PROJECT_NAME}-${ENVIRONMENT}_db-backup"
        highlight "Запуск backup в сервисе $backup_service"
        
        # Проверяем, что сервис существует
        if ! docker service ls --format '{{.Name}}' | grep -q "$backup_service"; then
            redlight "Ошибка: Сервис $backup_service не найден"
            exit 1
        fi
        
        # Запускаем backup команду в контейнере
        docker service exec "$backup_service" /assets/functions/backup || {
            redlight "Ошибка: Не удалось выполнить backup"
            exit 1
        }
    fi
    
    highlight "Backup операции завершены"
}

logs() {
    if [ -z "$ENVIRONMENT" ]; then
        redlight "Ошибка: Укажите окружение -e"
        exit 1
    fi
    
    if [ "$ENVIRONMENT" = "local" ]; then
        if [ -n "$SERVICE" ]; then
            highlight "Логи сервиса $SERVICE в локальном окружении"
            docker compose -f docker-compose.$ENVIRONMENT.yml logs -f $SERVICE
        else
            highlight "Логи всех сервисов в локальном окружении"
            docker compose -f docker-compose.$ENVIRONMENT.yml logs -f
        fi
    else
        local service_name="${PROJECT_NAME}-${ENVIRONMENT}_db-backup"
        highlight "Логи сервиса $service_name"
        docker service logs -f "$service_name"
    fi
}

case $ACTION in
    start)
        env_check
        init
        docker_pull
        start
        visual_delay 60
        info
        ;;
    update)
        env_check
        init
        docker_pull
        update
        visual_delay 30
        info
        ;;        
    clear)
        clear_commands
        ;;
    backup)
        env_check
        backup
        ;;
    info)
        info
        ;;
    restart)
        env_check    
        restart_service
        info
        ;;
    stop)
        env_check
        stop
        ;;
    logs)
        logs
        ;;
    *)
        echo "Использование: $0 -a ACTION -e ENVIRONMENT [-t TAG] [-v LOG_LEVEL] [-s SERVICE]"
        echo ""
        echo "Доступные действия (ACTION):"
        echo "  start     - Запуск проекта"
        echo "  update    - Обновление проекта"
        echo "  stop      - Остановка проекта"
        echo "  restart   - Перезапуск сервиса"
        echo "  clear     - Удаление стека/контейнеров"
        echo "  backup    - Выполнение backup операций"
        echo "  info      - Информация о запущенных сервисах"
        echo "  logs      - Просмотр логов"
        echo ""
        echo "Окружения (ENVIRONMENT):"
        echo "  local     - Локальное окружение (docker-compose)"
        echo "  test      - Тестовое окружение (docker stack)"
        echo "  prod      - Продуктовое окружение (docker stack)"
        echo ""
        echo "Примеры:"
        echo "  $0 -a start -e local"
        echo "  $0 -a update -e test -t v1.2.3"
        echo "  $0 -a restart -e prod -s db-backup"
        echo "  $0 -a backup -e test"
        echo "  $0 -a logs -e local -s db-backup"
        ;;
esac

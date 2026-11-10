#!/bin/bash

# Заставляет скрипт немедленно завершать работу
# при возникновении любой ошибки или использовании пустой переменной
set -euo pipefail

# Дефис перед значением обязателен, иначе значение после ":" воспринимается как арифметическое смещение
# ${VAR:-default} - default, если VAR не задана или пуста
# ${VAR-default} - default, только если VAR не задана (пустая строка остаётся)
# ${VAR:=default} - как :-, но ещё и присваивает значение переменной

ARCHIVE_NAME="${ARCHIVE_NAME:-backup.tar.gz}"
DB_NAME="${DB_NAME:-your_db_name}"
DB_USER="${DB_USER:-your_db_user}"
DB_PASSWORD="${DB_PASSWORD:-${PGPASSWORD:-your_db_password}}"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_ROLE="${DB_ROLE:-$DB_USER}"

if [[ ! -f "$ARCHIVE_NAME" ]]; then
    printf 'Ошибка: архив не найден: %s\n' "$ARCHIVE_NAME" >&2
    exit 1
fi

# Проверяем архив до распаковки, чтобы не восстановить оставшийся старый дамп
archive_contents=$(tar -tzf "$ARCHIVE_NAME")
case $'\n'"$archive_contents"$'\n' in
    *$'\n'./db/db_dump.sql$'\n'*|*$'\n'db/db_dump.sql$'\n'*) ;;
    *)
        printf 'Ошибка: в архиве отсутствует db/db_dump.sql\n' >&2
        exit 1
        ;;
esac

# Функция считывается целиком до распаковки: архив может содержать сам скрипт
restore_project() {
    tar -xzf "$ARCHIVE_NAME"

    # Без --create используется DB_NAME, а не имя базы из дампа
    # При ошибке вся транзакция, включая очистку объектов, откатывается
    PGPASSWORD="$DB_PASSWORD" pg_restore \
        -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        --no-owner --no-acl --role="$DB_ROLE" \
        --clean --if-exists --exit-on-error --single-transaction \
        db/db_dump.sql

    unset PGPASSWORD
    rm -rf db "$ARCHIVE_NAME" "$(basename "$0")"

    printf 'Восстановление завершено: %s\n' "$ARCHIVE_NAME"
}

restore_project

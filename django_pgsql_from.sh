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

# Архивируется текущая директория проекта, а не директория скрипта
archive_dir=$(cd -- "$(dirname -- "$ARCHIVE_NAME")" && pwd)
archive_basename=$(basename -- "$ARCHIVE_NAME")
archive_path="$archive_dir/$archive_basename"

mkdir -p db
dump_tmp=$(mktemp db/.db_dump.XXXXXX)
archive_tmp=""
trap 'rm -f -- "$dump_tmp" "$archive_tmp"' EXIT

# Для формата custom параметр --no-owner применяется при восстановлении
# ACL не переносим, чтобы дамп не зависел от ролей исходного сервера
PGPASSWORD="$DB_PASSWORD" pg_dump \
    -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
    --role="$DB_ROLE" --no-acl --format=custom \
    --file="$dump_tmp" --dbname="$DB_NAME"

mv -f -- "$dump_tmp" db/db_dump.sql

# Готовый архив заменяем только после успешного завершения tar
archive_tmp=$(mktemp "$archive_dir/.${archive_basename}.XXXXXX")
tar -czf "$archive_tmp" \
    --exclude="venv" --exclude=".venv" \
    --exclude="$archive_basename" \
    --exclude="$(basename -- "$archive_tmp")" .
mv -f -- "$archive_tmp" "$archive_path"

unset PGPASSWORD
rm -rf db "$(basename "$0")"

printf 'Резервная копия создана: %s\n' "$ARCHIVE_NAME"

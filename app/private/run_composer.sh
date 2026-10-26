#! /bin/bash

# Скрипт для работы с пакетами composer, когда он не установлен на хосте. 
# Предназначен для установки, удаления пакетов и обновления версий зависимостей.
# Меняются только файлы composer.json и composer.lock, каталог vendor не затрагивается.

# Пример запуска: 
# ./run_composer.sh require vendor/package --dev

set -e

docker run --rm -t -u $(id -u):$(id -g) -v $(pwd)/composer.json:/app/composer.json -v $(pwd)/composer.lock:/app/composer.lock -w /app composer:lts "$@" --no-install

exit 0

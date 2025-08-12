#!/bin/bash

mkdir -p /app/bootstrap /app/storage

chmod -R 777 /app/bootstrap /app/storage 2>/dev/null || true

exec php-fpm

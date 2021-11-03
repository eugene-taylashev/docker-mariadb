#!/bin/bash
set -e

#-- Check architecture
[[ $(uname -m) =~ ^armv7 ]] && ARCH="armv7-" || ARCH=""


docker build --no-cache --rm \
  -t etaylashev/mariadb:${ARCH}latest .

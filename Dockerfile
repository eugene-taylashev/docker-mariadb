FROM alpine:latest

ARG BUILD_DATE
ENV USER=mysql
ENV UID=1002
ENV VERBOSE=0 

LABEL maintainer="Eugene Taylashev" \
    architecture="amd64/x86_64" \
    mariadb-version="10.5.8" \
    alpine-version="3.13.2" \
    build="2021-03-06" \
    org.opencontainers.image.title="alpine-mariadb" \
    org.opencontainers.image.description="MariaDB Docker image running on Alpine Linux" \
    org.opencontainers.image.authors="Eugene Taylashev" \
    org.opencontainers.image.version="v10.5.8" \
    org.opencontainers.image.url="https://hub.docker.com/r/etaylashev/mariadb" \
    org.opencontainers.image.source="https://github.com/eugene-taylashev/docker-mariadb" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.created=$BUILD_DATE

#-- Create a user for MariaDB
RUN addgroup "$USER" && adduser \
    --disabled-password \
    --ingroup "$USER" \
    --no-create-home \
    --shell /sbin/nologin \
    --uid "$UID" \
    "$USER"

RUN apk add --no-cache mariadb mariadb-client mariadb-server-utils pwgen && \
    rm -f /var/cache/apk/*

COPY ./entrypoint.sh /

EXPOSE 3306
VOLUME ["/var/lib/mysql"]

ENTRYPOINT ["/entrypoint.sh"]

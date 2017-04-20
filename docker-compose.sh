#!/bin/bash
cat <<EOF
version: '2.1'
services:

  ${SERVICE_NAME}:
    image: ${BUILD_IMAGE}
    restart: always
    volumes:
      - .:/$PWD
      - $HOME/.cache:/home/$UNAME/.cache
    working_dir: /$PWD
    command: /sbin/init
    depends_on:
      hellgate:
        condition: service_started
      cds:
        condition: service_healthy
      magista:
        condition: service_started
      starter:
        condition: service_started
      dominant:
        condition: service_started
      keycloak:
        condition: service_healthy
      columbus:
        condition: service_started
      pimp:
        condition: service_started
      hooker:
        condition: service_healthy

  hellgate:
    image: dr.rbkmoney.com/rbkmoney/hellgate:6dae29bfab8ce09c26beaf8d9c2d5c8a678864e0
    restart: always
    command: /opt/hellgate/bin/hellgate foreground
    depends_on:
      machinegun:
        condition: service_healthy
      shumway:
        condition: service_healthy

  cds:
    image: dr.rbkmoney.com/rbkmoney/cds:1992157ed725cdc08ad3736370eee7a591e5edf9
    restart: always
    command: /opt/cds/bin/cds foreground
    healthcheck:
      test: "curl http://localhost:8022/"
      interval: 5s
      timeout: 1s
      retries: 12

  machinegun:
    image: dr.rbkmoney.com/rbkmoney/machinegun:138c13579dfc64e68695e6f69f1757b3c1160c83
    restart: always
    command: /opt/machinegun/bin/machinegun foreground
    volumes:
      - ./test/machinegun/sys.config:/opt/machinegun/releases/0.1.0/sys.config
    healthcheck:
      test: "curl http://localhost:8022/"
      interval: 5s
      timeout: 1s
      retries: 12

  magista:
    image: dr.rbkmoney.com/rbkmoney/magista:2e0c7fb4d21ebc277e608a75a8c384505cfc711a
    restart: always
    entrypoint:
      - java
      - -Xmx512m
      - -jar
      - /opt/magista/magista.jar
      - --spring.datasource.url=jdbc:postgresql://magista-db:5432/magista
      - --spring.datasource.username=postgres
      - --spring.datasource.password=postgres
      - --bm.pooling.url=http://bustermaze:8022/repo
    depends_on:
      - magista-db
      - bustermaze

  magista-db:
    image: dr.rbkmoney.com/rbkmoney/postgres:9.6
    environment:
      - POSTGRES_DB=magista
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    entrypoint:
     - /docker-entrypoint.sh
     - postgres

  bustermaze:
    image: dr.rbkmoney.com/rbkmoney/bustermaze:57c4cf3f9950b6ee46f67ffca286ebe8267bedde
    restart: always
    entrypoint:
      - java
      - -Xmx512m
      - -jar
      - /opt/bustermaze/bustermaze.jar
      - --spring.datasource.url=jdbc:postgresql://bustermaze-db:5432/bustermaze
      - --spring.datasource.username=postgres
      - --spring.datasource.password=postgres
      - --hg.pooling.url=http://hellgate:8022/v1/processing/eventsink
      - --flyway.url=jdbc:postgresql://bustermaze-db:5432/bustermaze
      - --flyway.user=postgres
      - --flyway.password=postgres
      - --flyway.schemas=bm
    depends_on:
      - hellgate
      - bustermaze-db

  bustermaze-db:
    image: dr.rbkmoney.com/rbkmoney/postgres:9.6
    environment:
      - POSTGRES_DB=bustermaze
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    entrypoint:
     - /docker-entrypoint.sh
     - postgres

  shumway:
    image: dr.rbkmoney.com/rbkmoney/shumway:94e25fd3a3e7af4c73925fb051d999d7f38c271d
    restart: always
    entrypoint:
      - java
      - -Xmx512m
      - -jar
      - /opt/shumway/shumway.jar
      - --spring.datasource.url=jdbc:postgresql://shumway-db:5432/shumway
      - --spring.datasource.username=postgres
      - --spring.datasource.password=postgres
    healthcheck:
      test: "curl http://localhost:8022/"
      interval: 5s
      timeout: 2s
      retries: 30
    depends_on:
      - shumway-db

  shumway-db:
    image: dr.rbkmoney.com/rbkmoney/postgres:9.6
    environment:
      - POSTGRES_DB=shumway
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    entrypoint:
     - /docker-entrypoint.sh
     - postgres

  dominant:
    image: dr.rbkmoney.com/rbkmoney/dominant:6d5a84327094016644ae470cdeb74aa6162c08b3
    restart: always
    command: /opt/dominant/bin/dominant foreground
    depends_on:
      machinegun:
        condition: service_healthy

  starter:
    image: ${BUILD_IMAGE}
    volumes:
      - .:/code
    environment:
      - CDS_HOST=cds
      - SCHEMA_DIR=/code/apps/cp_proto/damsel/proto
    command:
      /code/script/cds_test_init
    depends_on:
      cds:
        condition: service_healthy

  columbus:
    image:  dr.rbkmoney.com/rbkmoney/columbus:9abcea7f6833c91524604595507800588f81ef31
    links:
     - columbus-db
    entrypoint:
       - java
       - -jar
       - /opt/columbus/columbus.jar
       - --spring.datasource.url=jdbc:postgresql://columbus-db:5432/columbus
       - --geo.db.file.path=file:/maxmind.mmdb
       - --logging.level.ROOT=warn
       - --logging.level.com.rbkmoney=warn

  columbus-db:
    image: dr.rbkmoney.com/rbkmoney/postgres-geodata:8b8df081f3f23c10079e9a41b13ce7ca2f39cd3c
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: columbus
    entrypoint:
     - /docker-entrypoint.sh
     - postgres

  pimp:
    image: dr.rbkmoney.com/rbkmoney/pimp:ba9807b0d6b38ec2d65078af171c52713b5257e2
    entrypoint:
      - java
    command:
      -Xmx512m
      -jar /opt/pimp/pimp.jar

  hooker:
    image: dr.rbkmoney.com/rbkmoney/hooker:ba90c93b9fff182b4228f02f6dd3130d87761165
    healthcheck:
      test: "curl -sS -o /dev/null http://localhost:8022/"
      interval: 5s
      timeout: 2s
      retries: 10
    entrypoint:
      - java
      - -jar
      - /opt/hooker/hooker.jar
      - --spring.datasource.url=jdbc:postgresql://hooker-db:5432/hook
      - --spring.datasource.username=postgres
      - --spring.datasource.password=postgres
      - --flyway.url=jdbc:postgresql://hooker-db:5432/hook
      - --flyway.user=postgres
      - --flyway.password=postgres
      - --flyway.schemas=hook
      - --bm.pooling.url=http://bustermaze:8022/repo
    depends_on:
      - hooker-db

  hooker-db:
    image: dr.rbkmoney.com/rbkmoney/postgres:9.6
    environment:
      - POSTGRES_DB=hook
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres

  keycloak:
    image: dr.rbkmoney.com/rbkmoney/keycloak:585b792c57103eb90271dc86e92290d3891fdb07
    healthcheck:
      test: curl --silent --show-error --output /dev/null localhost:8080/auth/realms/external
      interval: 10s
      timeout: 1s
      retries: 15
    environment:
        SERVICE_NAME: keycloak
        POSTGRES_PASSWORD: keycloak
        POSTGRES_USER: keycloak
        POSTGRES_DATABASE: keycloak
        POSTGRES_PORT_5432_TCP_ADDR: keycloak-db
    depends_on:
      - keycloak-db

  keycloak-db:
    image: dr.rbkmoney.com/rbkmoney/postgres:9.6
    environment:
        POSTGRES_PASSWORD: keycloak
        POSTGRES_USER: keycloak
        POSTGRES_DB: keycloak
    entrypoint:
     - /docker-entrypoint.sh
     - postgres

networks:
  default:
    driver: bridge
    driver_opts:
      com.docker.network.enable_ipv6: "true"
      com.docker.network.bridge.enable_ip_masquerade: "false"
EOF

#!/bin/bash
cat <<EOF
version: '2'

services:
  ${SERVICE_NAME}:
    image: ${BUILD_IMAGE}
    volumes:
      - .:/code
    working_dir: /code
    command: /sbin/init
    links:
      - hellgate
      - cds
      - starter
      - machinegun
  hellgate:
    image: dr.rbkmoney.com/rbkmoney/hellgate:02e8d2b8f6091db6a3272b43d862248213dbd27a
    command: /opt/hellgate/bin/hellgate foreground
    depends_on:
      - machinegun
  cds:
    image: rbkmoney/cds:latest
    command: /opt/cds/bin/cds foreground
  machinegun:
    image: dr.rbkmoney.com/rbkmoney/mg_prototype:3455e7b
    command: /opt/mgun/bin/mgun foreground
  starter:
    image: dr.rbkmoney.com/rbkmoney/build:latest
    volumes:
      - .:/code
    environment:
      - CDS_HOST=cds
      - SCHEMA_DIR=/code/apps/cp_proto/damsel/proto
    command:
      /code/script/cds_test_init
    depends_on:
      - cds

networks:
  default:
    driver: bridge
    driver_opts:
      com.docker.network.enable_ipv6: "true"
      com.docker.network.bridge.enable_ip_masquerade: "false"
EOF

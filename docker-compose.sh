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

networks:
  default:
    driver: bridge
    driver_opts:
      com.docker.network.enable_ipv6: "true"
      com.docker.network.bridge.enable_ip_masquerade: "false"
EOF

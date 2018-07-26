#!/usr/bin/env bash

__dir=$(dirname $(readlink -f $0))

su -c "python3 ${__dir}/server.py" -s "${SHELL}" - www-data

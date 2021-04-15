#!/usr/bin/env bash

set -oxue pipefail

docker build -t python-scratch .
docker run --rm -it python-scratch

#!/usr/bin/env bash
set -e

cd repos
cd pizzamaker-fe && git pull && cd ..
cd recipe-manager && git pull && cd ..
cd ingredients-balancer && git pull && cd ..
cd ..

docker-compose up -d --build

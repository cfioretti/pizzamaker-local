#!/usr/bin/env bash
set -e
changes_detected=0

cd repos
check_pull_output() {
    if ! git pull | grep -q "Already up to date"; then
        changes_detected=1
    fi
}

cd pizzamaker-fe && check_pull_output && cd ..
cd recipe-manager && check_pull_output && cd ..
cd ingredients-balancer && check_pull_output && cd ..

docker-compose up -d --build
if [ $changes_detected -eq 1 ]; then
    docker-compose up -d --build
fi

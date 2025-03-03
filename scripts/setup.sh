#!/usr/bin/env bash
set -e

cd ..
git clone https://github.com/cfioretti/pizzamaker-fe || echo "pizzamaker-fe repo already exists"
git clone https://github.com/cfioretti/recipe-manager.git || echo "recipe-manager repo already exists"
git clone https://github.com/cfioretti/ingredients-balancer || echo "ingredients-balancer repo already exists"
cd pizzamaker-local

docker-compose up -d --build

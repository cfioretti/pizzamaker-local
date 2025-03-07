#!/usr/bin/env bash
set -e

mkdir "repos" || echo "repos directory already exists"
cd repos

git clone https://github.com/cfioretti/pizzamaker-fe || echo "pizzamaker-fe repo already exists"
git clone https://github.com/cfioretti/recipe-manager.git || echo "recipe-manager repo already exists"
git clone https://github.com/cfioretti/ingredients-balancer || echo "ingredients-balancer repo already exists"
git clone https://github.com/cfioretti/calculator || echo "calculator repo already exists"
cd ..

docker-compose up -d --build

set -e

cd .. && git clone https://github.com/cfioretti/pizzamaker-fe || echo "Repo already exists" && \
git clone https://github.com/cfioretti/recipe-manager.git || echo "Repo already exists" && \
git clone https://github.com/cfioretti/ingredients-balancer || echo "Repo already exists" && \
cd pizzamaker-local

docker-compose up -d --build

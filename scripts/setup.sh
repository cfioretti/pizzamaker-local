#!/usr/bin/env bash
set -e

ROOT_DIR=$(git rev-parse --show-toplevel)
mkdir -p "$ROOT_DIR/repos" || echo "repos directory already exists"
cd "$ROOT_DIR/repos"

echo "Setting up repositories..."

REPOS=(
    "https://github.com/cfioretti/pizzamaker-fe"
    "https://github.com/cfioretti/recipe-manager.git"
    "https://github.com/cfioretti/ingredients-balancer"
    "https://github.com/cfioretti/calculator"
)

for repo in "${REPOS[@]}"; do
    (
        repo_name=$(basename "$repo" .git)
        if [ -d "$repo_name" ]; then
            echo "$repo_name repo already exists"
        else
            echo "Cloning $repo_name..."
            git clone "$repo" && echo "$repo_name cloned successfully"
        fi
    ) &
done

# Wait for all background processes to complete
wait

echo "All repositories set up. Building containers..."
cd "$ROOT_DIR"
docker-compose up -d --build
echo "Setup complete!"

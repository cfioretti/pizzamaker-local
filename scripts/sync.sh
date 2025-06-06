#!/usr/bin/env bash
set -e

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$ROOT_DIR/repos" || { echo "repos directory does not exist"; exit 1; }

check_pull_output() {
    local repo=$1
    if ! git pull | grep -q "Already up to date"; then
        touch "$TEMP_DIR/$repo.changed"
    fi
}

echo "Syncing repositories..."
for repo in pizzamaker-fe recipe-manager ingredients-balancer calculator; do
    (
        if [ -d "$repo" ]; then
            echo "Syncing $repo..."
            cd "$repo" && check_pull_output "$repo" && cd ..
        else
            echo "Repository $repo not found, skipping."
        fi
    ) &
done

# Wait for all background processes to complete
wait

if [ "$(find "$TEMP_DIR" -name "*.changed" | wc -l)" -gt 0 ]; then
    echo "Changes detected in repositories:"
    for changed in "$TEMP_DIR"/*.changed; do
        if [ -f "$changed" ]; then
            echo "- $(basename "$changed" .changed)"
        fi
    done
    echo "Rebuilding containers..."
    cd "$ROOT_DIR" && docker-compose up -d --build
else
    echo "No changes detected, skipping rebuild."
fi

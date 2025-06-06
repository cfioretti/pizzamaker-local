# Pizzamaker Local Env Setup

This project provides a local development environment for the Pizzamaker application, which consists of multiple microservices. It allows you to run all the necessary services locally for development and testing purposes.

## Overview

The Pizzamaker application is composed of the following services:

- **Frontend (pizzamaker-fe)**: React-based web interface
- **Recipe Manager (recipe-manager)**: Manages pizza recipes
- **Ingredients Balancer (ingredients-balancer)**: Calculates ingredient proportions
- **Calculator (calculator)**: Performs dough calculations
- **MySQL**: Database for storing recipes

## Prerequisites

- Git
- Docker and Docker Compose
- Make

## Getting Started

### Initial Setup

To set up the local environment for the first time:

```bash
make setup
```

This command will:
1. Clone all required repositories in parallel
2. Build Docker images with caching
3. Start all containers

### Daily Development

To sync your repositories with the latest changes:

```bash
make sync
```

This command will:
1. Pull the latest changes from all repositories in parallel
2. Rebuild containers only if changes were detected

### Available Commands

Run `make help` to see all available commands:

```
Available targets:
  setup                     - Initial setup of repositories and containers
  sync                      - Sync repositories and rebuild if needed
  start                     - Start all containers
  stop                      - Stop all containers and remove volumes
  restart                   - Restart all containers
  status                    - Show status of all containers
  logs [service=name]       - Show logs for all or specific service
  clean                     - Remove all containers, volumes, and images
  rebuild                   - Rebuild all containers
  rebuild-frontend          - Rebuild only frontend container
  rebuild-recipe-manager    - Rebuild only recipe-manager container
  rebuild-ingredients-balancer - Rebuild only ingredients-balancer container
  rebuild-calculator        - Rebuild only calculator container
```

## Service URLs

When the environment is running, you can access the services at:

- Frontend: http://localhost:3000
- Recipe Manager API: http://localhost:8080
- Ingredients Balancer gRPC: localhost:50052
- Calculator gRPC: localhost:50051

## Troubleshooting

If you encounter issues:

1. Check service status with `make status`
2. View logs with `make logs` or `make logs service=<service-name>`
3. Try rebuilding a specific service with `make rebuild-<service-name>`
4. For a clean start, run `make clean` followed by `make setup`

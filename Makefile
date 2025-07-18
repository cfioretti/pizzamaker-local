.PHONY: setup sync start stop restart status logs clean rebuild rebuild-frontend rebuild-recipe-manager rebuild-ingredients-balancer rebuild-calculator monitoring-start monitoring-stop logging-start logging-stop observability-start observability-stop help

help:
	@echo "Available targets:"
	@echo "  setup                - Initial setup of repositories and containers"
	@echo "  sync                 - Sync repositories and rebuild if needed"
	@echo "  start                - Start all containers"
	@echo "  stop                 - Stop all containers and remove volumes"
	@echo "  restart              - Restart all containers"
	@echo "  status               - Show status of all containers"
	@echo "  logs [service=name]  - Show logs for all or specific service"
	@echo "  clean                - Remove all containers, volumes, and images"
	@echo "  rebuild              - Rebuild all containers"
	@echo "  rebuild-frontend     - Rebuild only frontend container"
	@echo "  rebuild-recipe-manager - Rebuild only recipe-manager container"
	@echo "  rebuild-ingredients-balancer - Rebuild only ingredients-balancer container"
	@echo "  rebuild-calculator   - Rebuild only calculator container"
	@echo "  monitoring-start     - Start monitoring stack (Prometheus + Grafana)"
	@echo "  monitoring-stop      - Stop monitoring stack only"
	@echo "  logging-start        - Start logging stack (Elasticsearch + Fluentd + Kibana)"
	@echo "  logging-stop         - Stop logging stack only"
	@echo "  observability-start  - Start both monitoring and logging stacks together"
	@echo "  observability-stop   - Stop both monitoring and logging stacks together"

setup:
	./scripts/setup.sh

sync:
	./scripts/sync.sh

start:
	docker-compose up -d

stop:
	docker-compose down -v --remove-orphans

restart: stop start

status:
	docker-compose ps

logs:
	@if [ -z "$(service)" ]; then \
		docker-compose logs --tail=100 -f; \
	else \
		docker-compose logs --tail=100 -f $(service); \
	fi

clean:
	docker-compose down -v --remove-orphans --rmi all

rebuild:
	docker-compose build --no-cache
	docker-compose up -d

rebuild-frontend:
	docker-compose build --no-cache frontend
	docker-compose up -d frontend

rebuild-recipe-manager:
	docker-compose build --no-cache recipe-manager
	docker-compose up -d recipe-manager

rebuild-ingredients-balancer:
	docker-compose build --no-cache ingredients-balancer
	docker-compose up -d ingredients-balancer

rebuild-calculator:
	docker-compose build --no-cache calculator
	docker-compose up -d calculator

observability-start:
	docker-compose up -d prometheus grafana elasticsearch-logs fluentd kibana-logs

observability-stop:
	docker-compose stop prometheus grafana elasticsearch-logs fluentd kibana-logs

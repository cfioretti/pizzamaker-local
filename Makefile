setup:
	./scripts/setup.sh

sync:
	./scripts/sync.sh

start:
	docker-compose up -d

stop:
	docker-compose down -v --remove-orphans

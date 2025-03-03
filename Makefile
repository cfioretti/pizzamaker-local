setup:
	./scripts/setup.sh

start:
	docker-compose up -d

stop:
	docker-compose down -v --remove-orphans

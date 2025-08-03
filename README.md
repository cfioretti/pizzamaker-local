# Pizzamaker Local Env Setup

This project provides a local development environment for the Pizzamaker application, which consists of multiple microservices. It allows you to run all the necessary services locally for development and testing purposes.

## Overview

The Pizzamaker application is composed of the following services:

## Core Application Services
- **Frontend (pizzamaker-fe)**: React-based web interface
- **Recipe Manager (recipe-manager)**: Manages pizza recipes (HTTP/REST API)
- **Ingredients Balancer (ingredients-balancer)**: Calculates ingredient proportions (gRPC)
- **Calculator (calculator)**: Performs dough calculations (gRPC)

## Infrastructure Services
- **Kong API Gateway**: Enterprise-grade API gateway with rate limiting, CORS, circuit breaker
- **PostgreSQL (Kong DB)**: Kong configuration database
- **MySQL**: Application database for storing recipes
- **Jaeger**: Distributed tracing system for observability

## Architecture & Observability

This project implements a comprehensive observability stack following the **Three Pillars of Observability**:

### Structured Logging
- **Logrus**: JSON-structured logging across all Go services
- **Correlation ID**: Automatic request tracking across service boundaries
- **Context propagation**: Trace and span IDs automatically included in logs
- **EFK Integration**: Logs automatically collected and parsed by Fluentd for Kibana analysis

### Distributed Tracing
- **OpenTelemetry**: Industry-standard tracing instrumentation
- **Jaeger**: Distributed tracing backend with web UI
- **Cross-service tracing**: Automatic trace propagation between HTTP and gRPC services
- **Context correlation**: Traces linked with structured logs via correlation IDs

### Metrics (Prometheus + Grafana)
- **Prometheus**: Time-series database for metrics collection from all DDD microservices
- **Grafana**: Dashboard and visualization platform with pre-configured dashboards
- **Business Metrics**: Domain-specific metrics (recipe operations, calculation accuracy, balancer efficiency)
- **Technical Metrics**: Response times, error rates, throughput, resource utilization
- **Infrastructure Metrics**: Service health, active connections, database operations

### Service Communication
- **HTTP**: Frontend ↔ Recipe Manager (with OpenTelemetry Gin middleware)
- **gRPC**: Recipe Manager ↔ Calculator/Ingredients Balancer (with OpenTelemetry gRPC interceptors)
- **Automatic instrumentation**: All inter-service calls are automatically traced

## Project Structure

This project follows an infrastructure-centric organization for better scalability and maintainability:

```
pizzamaker-local/
├── infrastructure/           # Infrastructure configuration files
│   ├── gateway/             # API Gateway configurations
│   │   └── kong/           # Kong Gateway config and plugins
│   └── monitoring/         # Observability stack
│       ├── prometheus/     # Metrics collection
│       ├── grafana/        # Dashboards and visualization
│       ├── elasticsearch/  # Log storage
│       ├── fluentd/        # Log processing
│       └── kibana/         # Log analysis and visualization
├── scripts/                # Automation scripts
│   ├── infrastructure/     # Infrastructure management scripts
│   ├── setup.sh           # Initial environment setup
│   └── sync.sh             # Repository synchronization
└── repos/                  # Application microservices (Git submodules)
    ├── pizzamaker-fe/      # Frontend application
    ├── recipe-manager/     # Recipe management service
    ├── calculator/         # Calculation service
    └── ingredients-balancer/ # Balancing service
```

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

### Daily Development

To sync your repositories with the latest changes:

```bash
make sync
```

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
  observability-start       - Start both monitoring and logging stacks together
  observability-stop        - Stop both monitoring and logging stacks together
```

## Service URLs

When the environment is running, you can access the services at:

### Core Services
- **Frontend**: http://localhost:3000
- **Recipe Manager API**: http://localhost:8000/api/v1/recipes (via Kong)
- **Health Check**: http://localhost:8000/health (via Kong)
- **Ingredients Balancer gRPC**: localhost:50052 (internal)
- **Calculator gRPC**: localhost:50051 (internal)

### Kong API Gateway
- **Kong Proxy**: http://localhost:8000 (Main API entry point)
- **Kong Admin API**: http://localhost:8001 (Configuration)
- **Kong Admin GUI**: http://localhost:8002 (Web interface)

### Observability Stack
- **Jaeger UI**: http://localhost:16686 (Distributed Tracing)
- **Prometheus**: http://localhost:9090 (Metrics Collection)
- **Grafana**: http://localhost:3001 (Dashboards - admin/admin)
- **Kibana**: http://localhost:5601 (Log Analysis & Monitoring)
- **Elasticsearch**: http://localhost:9200 (Search Engine API)

To start or stop monitoring (Prometheus + Grafana) and logging (EFK) stacks:

```bash
make observability-start
make observability-stop
```

## Kong API Gateway Management

After starting the environment, configure Kong Gateway:

```bash
make kong-setup
make kong-test
make kong-show
```

### Metrics Endpoints
- **Kong Gateway**: http://localhost:8001/metrics (Admin API)
- **Recipe Manager**: http://localhost:8000/metrics/recipe-manager (via Kong)
- **Calculator**: http://localhost:8000/metrics/calculator (via Kong, protected)
- **Ingredients Balancer**: http://localhost:8000/metrics/balancer (via Kong, protected)

### Pre-configured Dashboards

#### Grafana Dashboards
- **Business Overview**: Real-time business metrics and KPIs
- **Infrastructure Health**: System health, error rates, response times

#### Kibana Dashboards
- **Service Health Overview**: Real-time service status and log volume
- **Log Levels Distribution**: Error detection and logging patterns
- **Correlation ID Tracking**: Distributed request tracing across services
- **Error Detection & Alerting**: Performance anomaly detection and exception tracking

# EFK Configuration

1. Access Kibana at http://localhost:5601
2. Index patterns are automatically created:
   - `pizzamaker-logs-*`: Enhanced logs with correlation IDs
   - `fluentd-*`: Raw container logs
3. Pre-configured visualizations available for import
4. Real-time log monitoring and correlation ID tracking
5. For detailed instructions on setting up Kibana dashboards, see [Kibana Dashboard Setup Guide](infrastructure/monitoring/kibana/KIBANA_DASHBOARD_GUIDE.md)

## Troubleshooting

If you encounter issues:

1. Check service status with `make status`
2. View logs with `make logs` or `make logs service=<service-name>`
3. Check Jaeger UI for distributed tracing information
4. Verify OpenTelemetry configuration in service logs
5. Try rebuilding a specific service with `make rebuild-<service-name>`
6. For a clean start, run `make clean` followed by `make setup`

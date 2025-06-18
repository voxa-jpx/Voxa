# Makefile for Voxa System Management

.PHONY: help start stop restart logs status clean test setup

# Default target
help:
	@echo "Voxa System Management Commands:"
	@echo "  make start      - Start all services"
	@echo "  make stop       - Stop all services"
	@echo "  make restart    - Restart all services"
	@echo "  make logs       - View logs (all services)"
	@echo "  make logs-api   - View API logs"
	@echo "  make logs-odoo  - View Odoo logs"
	@echo "  make status     - Show service status"
	@echo "  make clean      - Clean up containers and volumes"
	@echo "  make test       - Test communication between services"
	@echo "  make setup      - Initial setup (create .env, directories)"
	@echo "  make shell-api  - Enter API container"
	@echo "  make shell-odoo - Enter Odoo container"

# Setup environment
setup:
	@echo "Setting up Voxa environment..."
	@if [ ! -f .env ]; then \
		cp .env.example .env 2>/dev/null || echo "Creating .env file..."; \
		echo "# Voxa Configuration" > .env; \
		echo "VOXA_API_KEY=Bearer V9kEXAMPLEp5xGv4jR9_eXaO4Db-YzMVhwGtBmfSY" >> .env; \
		echo "VOXA_LICENSE_API_URL=http://voxa-api:8000/api/license/verify" >> .env; \
		echo "VOXA_LICENSE_API_KEY=Bearer V9kEXAMPLEp5xGv4jR9_eXaO4Db-YzMVhwGtBmfSY" >> .env; \
		echo "DATABASE_URL=postgresql://voxa:voxa123@db-api:5432/voxa_api" >> .env; \
		echo "API_PORT=8001" >> .env; \
		echo "API_CONTAINER_NAME=voxa_api" >> .env; \
	fi
	@mkdir -p postgresql postgres_api_data filestore sessions api_data logs
	@echo "Setup complete!"

# Start services
start: setup
	@echo "Starting Voxa services..."
	@docker network create voxa_network 2>/dev/null || true
	@docker-compose up -d
	@echo "Waiting for services to be ready..."
	@sleep 10
	@make status
	@echo ""
	@echo "Services started successfully!"
	@echo "Odoo: http://localhost:8069"
	@echo "API:  http://localhost:8001"
	@echo "Docs: http://localhost:8001/docs"

# Stop services
stop:
	@echo "Stopping Voxa services..."
	@docker-compose down
	@echo "Services stopped."

# Restart services
restart: stop start

# View logs
logs:
	@docker-compose logs -f

logs-api:
	@docker-compose logs -f voxa-api

logs-odoo:
	@docker-compose logs -f odoo

# Show status
status:
	@echo "Voxa Service Status:"
	@docker-compose ps
	@echo ""
	@echo "Network Status:"
	@docker network inspect voxa_network | grep -E "(Name|IPv4Address)" | grep -v "SecondaryIPv" || echo "Network not found"

# Clean up
clean:
	@echo "Cleaning up Voxa system..."
	@docker-compose down -v
	@docker network rm voxa_network 2>/dev/null || true
	@echo "Clean up complete. Data volumes have been removed."

# Test communication
test:
	@echo "Testing Voxa communication..."
	@echo "1. Testing API health..."
	@curl -s http://localhost:8001/health | jq . || echo "API health check failed"
	@echo ""
	@echo "2. Testing license verification..."
	@curl -s -X POST http://localhost:8001/api/license/verify \
		-H "Authorization: Bearer V9kEXAMPLEp5xGv4jR9_eXaO4Db-YzMVhwGtBmfSY" \
		-H "Content-Type: application/json" \
		-d '{"license_key":"VOXA-DEMO-2024-001","domain":"localhost","version":"18.0"}' | jq . || echo "License verification failed"
	@echo ""
	@echo "3. Testing internal network..."
	@docker exec voxa_odoo ping -c 1 voxa-api > /dev/null && echo "✓ Odoo can reach API" || echo "✗ Odoo cannot reach API"
	@docker exec voxa_api ping -c 1 odoo > /dev/null && echo "✓ API can reach Odoo" || echo "✗ API cannot reach Odoo"

# Shell access
shell-api:
	@docker exec -it voxa_api /bin/bash

shell-odoo:
	@docker exec -it voxa_odoo /bin/bash

# Create sample license
create-license:
	@echo "Creating sample license..."
	@curl -X POST http://localhost:8001/api/license/licenses \
		-H "Authorization: Bearer V9kEXAMPLEp5xGv4jR9_eXaO4Db-YzMVhwGtBmfSY" \
		-H "Content-Type: application/json" \
		-d '{"license_key":"VOXA-DEMO-2024-001","status":"active","grace_days":30,"expiration_date":"2025-12-31"}' \
		| jq . || echo "Failed to create license"

# Debug commands
debug-network:
	@echo "Debugging network configuration..."
	@docker network inspect voxa_network | jq '.[] | {Name, Containers: .Containers | to_entries | map({Name: .value.Name, IP: .value.IPv4Address})}'

debug-env:
	@echo "Environment variables in Odoo container:"
	@docker exec voxa_odoo env | grep VOXA || echo "No VOXA variables found"
	@echo ""
	@echo "Environment variables in API container:"
	@docker exec voxa_api env | grep -E "(DATABASE_URL|VOXA)" || echo "No relevant variables found"

# Development helpers
dev-reload-odoo:
	@echo "Reloading Odoo with updated modules..."
	@docker-compose restart odoo
	@docker-compose logs -f odoo

dev-reload-api:
	@echo "Reloading API..."
	@docker-compose restart voxa-api
	@docker-compose logs -f voxa-api

# Backup and restore
backup:
	@echo "Creating backup..."
	@mkdir -p backups
	@docker exec voxa_postgres_odoo pg_dump -U odoo postgres > backups/odoo_backup_$(shell date +%Y%m%d_%H%M%S).sql
	@docker exec voxa_postgres_api pg_dump -U voxa voxa_api > backups/api_backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Backup created in backups/ directory"

restore:
	@echo "Available backups:"
	@ls -la backups/*.sql 2>/dev/null || echo "No backups found"
	@echo "To restore, use: docker exec -i <container> psql -U <user> <database> < backups/<backup_file>"
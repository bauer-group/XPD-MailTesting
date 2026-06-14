# Thin passthrough for `make` users. The Taskfile is the primary runner.
.PHONY: up down reset logs status pull help

up:      ## Start the stack in the background
	docker compose up -d

down:    ## Stop the stack (keeps mailbox data)
	docker compose down

reset:   ## Stop the stack and wipe all captured mail
	docker compose down -v

logs:    ## Follow Mailpit logs
	docker compose logs -f mailpit

status:  ## Show container status and health
	docker compose ps

pull:    ## Update to the latest Mailpit image
	docker compose pull

help:    ## Show this help
	@grep -E '^[a-z]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-8s %s\n", $$1, $$2}'

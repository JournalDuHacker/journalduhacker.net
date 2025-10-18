.PHONY: help 

help: ## Afficher l'aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

test: ## Lancer tous les tests
	docker compose run --rm web bundle exec rspec

test-file: ## Lancer un fichier de test spécifique (usage: make test-file FILE=spec/models/user_spec.rb)
	docker compose run --rm web bundle exec rspec $(FILE)

lint: ## Lancer le linter (StandardRB)
	docker compose run --rm web bundle exec standardrb

lint-fix: ## Corriger automatiquement les problèmes de lint
	docker compose run --rm web bundle exec standardrb --fix

rails-console: ## Ouvrir la console Rails
	docker compose run --rm web bundle exec rails console

rails-migrate: ## Exécuter les migrations
	docker compose run --rm web bundle exec rake db:migrate

rails-db-setup: ## Créer et initialiser la base de données
	docker compose run --rm web bundle exec rake db:setup

rails-db-reset: ## Réinitialiser la base de données
	docker compose run --rm web bundle exec rake db:reset

shell: ## Ouvrir un shell dans le conteneur web
	docker compose run --rm web bash

bundle: ## Installer les dépendances
	docker compose run --rm web bundle install
<div align="center">

# 📰 Journal du hacker

**La plateforme francophone de partage de liens tech pour les hackers, développeurs et passionnés**

[![Rails](https://img.shields.io/badge/Rails-4.2.8-red.svg)](https://rubyonrails.org/)
[![Ruby](https://img.shields.io/badge/Ruby-2.x-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/License-AGPLv3-blue.svg)](LICENSE)
[![Website](https://img.shields.io/badge/Website-journalduhacker.net-green.svg)](https://www.journalduhacker.net)

[Site web](https://www.journalduhacker.net) • [Contribuer](#-contributing) • [Documentation](#-documentation)

</div>

---

## 🎯 À propos

**Journal du hacker** est un agrégateur de liens communautaire axé sur l'informatique et le hacking (au sens noble du terme). Inspiré de [Lobsters](https://lobste.rs) et [Hacker News](https://news.ycombinator.com/), il offre un espace francophone pour partager et discuter d'articles techniques, de projets open source, et de sujets liés au développement logiciel.

### ✨ Fonctionnalités

- 🔗 **Soumission de liens** avec preview automatique et détection de doublons
- 💬 **Commentaires hiérarchiques** avec threading infini
- ⬆️ **Système de vote** avec raisons pour les downvotes
- 🏷️ **Tags et filtres** pour organiser le contenu
- 🔍 **Recherche full-text** sur les stories et commentaires
- 👤 **Profils utilisateurs** avec karma et historique
- 🎩 **Système de "hats"** (chapeaux) pour contextualiser les commentaires
- ✉️ **Messages privés** entre utilisateurs
- 🎫 **Invitations** pour contrôler la croissance de la communauté
- 🛡️ **Outils de modération** complets
- 📧 **Réponse par email** aux commentaires
- 🌐 **API JSON** pour intégrations tierces

---

## 🚀 Quick Start (Docker)

La façon la plus rapide de démarrer le projet en local :

```bash
# Clone le repository
git clone https://github.com/flemzord/journalduhacker.net.git
cd journalduhacker

# Lance avec Docker Compose (la config DB est déjà gérée !)
docker-compose up -d

# Crée la base de données et les seeds
docker-compose exec web bundle exec rake db:setup

# Le site est disponible sur http://localhost:3000
# Login par défaut : test / test
```

> **Note** : Avec Docker, `config/database.yml` utilise automatiquement les variables d'environnement définies dans `docker-compose.yml`. Aucune configuration manuelle nécessaire !

---

## 📦 Installation locale

### Prérequis

- **Ruby** 2.0.0+ (testé avec 1.9.3, 2.0.0, 2.1.0, 2.3.0)
- **MariaDB** ou **MySQL** 5.7+
- **Bundler** 2.x
- **Node.js** (pour les assets)

### Installation pas à pas

1. **Clone le repository**

```bash
git clone https://github.com/flemzord/journalduhacker.net.git
cd journalduhacker
```

2. **Installe les dépendances**

```bash
bundle install
```

3. **Configure la base de données**

Le fichier `config/database.yml` existe déjà et utilise des variables d'environnement. Tu peux soit :

**Option A** - Définir les variables d'environnement :
```bash
export DATABASE_USER=root
export DATABASE_PASSWORD=your_password
export DATABASE_HOST=localhost
```

**Option B** - Modifier directement `config/database.yml` (lignes 7-10) :
```yaml
development:
  username: root
  password: your_password
  host: localhost  # ou le chemin socket: /tmp/mysql.sock
```

4. **Crée la base de données**

```bash
bundle exec rake db:setup
```

Cela va :
- Créer la base de données
- Charger le schéma
- Créer un utilisateur de test (`test` / `test`)
- Créer un tag de test

5. **Configure le secret token**

Génère un token secret :

```bash
bundle exec rake secret
```

Crée `config/initializers/secret_token.rb` :

```ruby
Lobsters::Application.config.secret_key_base = 'your_generated_secret_here'
```

6. **Configure ton site (optionnel)**

Crée `config/initializers/production.rb` :

```ruby
class << Rails.application
  def domain
    "localhost:3000"
  end

  def name
    "Journal du hacker"
  end
end

Rails.application.routes.default_url_options[:host] = Rails.application.domain
```

7. **Lance le serveur**

```bash
bundle exec rails server
```

Ouvre http://localhost:3000 et connecte-toi avec `test` / `test` 🎉

---

## 🧪 Tests

Le projet utilise RSpec pour les tests :

```bash
# Lance tous les tests
bundle exec rspec

# Lance un fichier spécifique
bundle exec rspec spec/models/user_spec.rb

# Lance un test spécifique
bundle exec rspec spec/models/user_spec.rb:10
```

---

## 🏗️ Architecture

```
journalduhacker/
├── app/
│   ├── controllers/      # Contrôleurs Rails
│   ├── models/          # Modèles ActiveRecord
│   ├── views/           # Templates ERB
│   ├── assets/          # CSS, JS, images
│   └── mailers/         # Emails
├── config/              # Configuration Rails
├── db/
│   ├── migrate/         # Migrations de base de données
│   └── schema.rb        # Schéma actuel
├── spec/                # Tests RSpec
├── docker-compose.yml   # Configuration Docker
└── Dockerfile          # Image Docker
```

### Stack technique

- **Framework** : Ruby on Rails 4.2.8
- **Base de données** : MariaDB/MySQL avec full-text search
- **Frontend** : jQuery, CSS vanilla
- **Server** : Unicorn (production)
- **Email** : ActionMailer avec parsing d'emails entrants
- **Authentification** : bcrypt + TOTP 2FA (optionnel)

---

## 🤝 Contributing

Les contributions sont les bienvenues ! Voici comment participer :

1. **Fork** le projet
2. Crée une **branche** pour ta feature (`git checkout -b feature/amazing-feature`)
3. **Commit** tes changements (`git commit -m 'Add amazing feature'`)
4. **Push** sur ta branche (`git push origin feature/amazing-feature`)
5. Ouvre une **Pull Request**

### Guidelines

- Respecte le style de code existant
- Ajoute des tests pour les nouvelles fonctionnalités
- Mets à jour la documentation si nécessaire
- Utilise des messages de commit descriptifs

Pour plus de détails, consulte [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 📚 Documentation

### Configuration de production

Pour un déploiement en production, pense à :

- Utiliser un reverse proxy (nginx, Apache)
- Configurer SSL/TLS
- Mettre en place des backups automatiques de la base de données
- Configurer les emails (SMTP)
- Activer le cache (Redis recommandé)
- Configurer les variables d'environnement sensibles

### Customisation

- **CSS personnalisé** : Place tes styles dans `app/assets/stylesheets/local/`
- **Logo** : Remplace les images dans `app/assets/images/`
- **Traductions** : Modifie `config/locales/fr.yml`

---

## 📜 Licence

Ce projet est sous double licence :

- **Nouveau code** (depuis le 8 novembre 2016) : [AGPLv3](LICENSE) - © 2016-2017 Carl Chenet
- **Code original** (jusqu'au 3 novembre 2016) : 3-BSD License - © 2012-2016 Joshua Stein (Lobsters)

Le code original de Lobsters est disponible sur [github.com/lobsters/lobsters](https://github.com/lobsters/lobsters).

---

## 🙏 Remerciements

- [Joshua Stein](https://github.com/jcs) pour avoir créé [Lobsters](https://lobste.rs)
- La communauté [Journal du hacker](https://www.journalduhacker.net) pour ses contributions
- Tous les contributeurs qui ont rendu ce projet possible

---

<div align="center">

**[⬆ Retour en haut](#-journal-du-hacker)**

Fait avec ❤️ pour la communauté francophone des hackers

</div>

# edwards.bookclub

Rails migration workspace for replacing the current SharePoint List + Power BI workflow with a web application backed by SQLite.

## Repository contents

- `app/`, `config/`, `db/`, `test/`: Rails application baseline
- `scripts/export_pbix_migration_assets.py`: PBIX analysis exporter
- `sql/bookclub.sqlite.sql`: target schema draft from the migration design
- `srs.md`: requirements summary based on the current PBIX model
- `migration-design.md`: Rails-first migration design plan
- `artifacts/`: generated PBIX analysis outputs

## Local Ruby and Rails toolchain

This workspace was bootstrapped in WSL using Homebrew-installed Ruby rather than system packages.

Before running Rails commands in a fresh shell:

```bash
source script/dev-env.sh
```

The helper script exports:

- Homebrew Ruby and SQLite paths
- user-local gem paths
- project-local Bundler path at `vendor/bundle`

## Rails workflow

Initialize dependencies:

```bash
source script/dev-env.sh
bundle install
```

Create and migrate the database:

```bash
source script/dev-env.sh
bundle exec bin/rails db:create db:migrate
```

Run the test suite:

```bash
source script/dev-env.sh
bundle exec bin/rails test
```

Run a Rails command:

```bash
source script/dev-env.sh
bundle exec bin/rails runner 'puts Rails.application.class.name'
```

## PBIX migration artifacts

The PBIX exporter can be rerun at any time:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 scripts/export_pbix_migration_assets.py \
  --pbix 독서동호회.pbix \
  --out artifacts
```

## Current migration direction

- Application stack: Rails
- Database: SQLite
- Delivery style: kanban-driven implementation from the local board
- Migration sequence: Rails scaffold -> normalized schema -> importer -> reconciliation -> admin workflows -> dashboards

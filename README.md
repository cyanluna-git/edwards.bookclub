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

Seed the baseline data and local admin account:

```bash
source script/dev-env.sh
bundle exec bin/rails db:seed
```

Run the test suite:

```bash
source script/dev-env.sh
bundle exec bin/rails test
```

Default local admin bootstrap from `db:seed`:

```text
email: admin@edwards-bookclub.local
password: changeme123!
```

Override with:

```bash
source script/dev-env.sh
BOOKCLUB_ADMIN_EMAIL=admin@example.com \
BOOKCLUB_ADMIN_PASSWORD='replace-me' \
bundle exec bin/rails db:seed
```

Run a Rails command:

```bash
source script/dev-env.sh
bundle exec bin/rails runner 'puts Rails.application.class.name'
```

## Aladin search integration

The book request forms can optionally search the official Aladin developer API and prefill core book metadata.

Configure a TTB key in the shell before starting Rails:

```bash
export ALADIN_TTB_KEY='your-ttb-key'
```

Notes:

- If `ALADIN_TTB_KEY` is not set, the book request forms stay fully usable in manual-entry mode.
- The current integration uses the Aladin `ItemSearch` API and prefills `title`, `author`, `publisher`, `cover_url`, and `link_url`.
- Review Aladin API usage terms before enabling this in a company or production environment.

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

## Import pipeline

Run the first-pass importer with the PBIX-exported members CSV and SharePoint-style CSV exports:

```bash
source script/dev-env.sh
BOOK_REQUESTS_CSV=test/fixtures/imports/book_requests.csv \
ATTENDANCE_CSV=test/fixtures/imports/attendance.csv \
bundle exec bin/rake bookclub:import
```

Notes:

- `MEMBERS_CSV` defaults to `artifacts/csv/Members.csv` when present.
- `BOOK_REQUESTS_CSV` and `ATTENDANCE_CSV` should point to SharePoint export CSV files.
- Re-running the task is designed to update existing imported rows instead of duplicating them.

Generate a reconciliation report against the PBIX baseline:

```bash
source script/dev-env.sh
bundle exec bin/rake bookclub:reconcile
```

## Operations

Deployment, backup, restore, and cutover guidance lives in:

- `ops/runbook.md`
- `script/backup-production.sh`
- `script/restore-production.sh`
- `script/cutover-dry-run.sh`

## Current migration direction

- Application stack: Rails
- Database: SQLite
- Delivery style: kanban-driven implementation from the local board
- Migration sequence: Rails scaffold -> normalized schema -> importer -> reconciliation -> admin workflows -> dashboards

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

## SSO email handoff

The app can accept an upstream SSO email and create the local Rails session without a password prompt.

Environment variables:

```bash
BOOKCLUB_SSO_ENABLED=true
BOOKCLUB_SSO_LOGIN_URL='https://your-sso-entry.example.com'
BOOKCLUB_SSO_EMAIL_HEADERS='X-Forwarded-Email,X-Auth-Request-Email'
BOOKCLUB_SSO_AUTO_REDIRECT=false
BOOKCLUB_SSO_SHARED_SECRET='shared-secret-for-signed-callbacks'
BOOKCLUB_SSO_MAX_AGE_SECONDS=300
```

Behavior:

- `BOOKCLUB_SSO_ENABLED=true` turns on the SSO entry and callback paths.
- `GET /auth/sso` redirects to `BOOKCLUB_SSO_LOGIN_URL` when no email is present yet.
- `GET` or `POST /auth/sso/callback` accepts a trusted upstream email and signs the user in.
- If the email matches an existing `users.email`, that account is used.
- If there is no `User` yet but there is an active `members.email`, the app auto-creates a linked `member` user.
- Local email/password login remains available as fallback.

Callback options:

- Preferred: an internal proxy or auth layer injects a trusted email header such as `X-Forwarded-Email`.
- Alternative: send `email`, `ts`, and `sig` where `sig = HMAC_SHA256(shared_secret, "#{email}:#{ts}")`.
- Query-parameter callback verification is relaxed in `development` and `test` to keep local integration simple.

## Microsoft Entra ID sign-in

The app can also authenticate directly against Microsoft Entra ID using OmniAuth.

Environment variables:

```bash
ENTRA_TENANT_ID='tenant-uuid'
ENTRA_CLIENT_ID='application-client-id'
ENTRA_CLIENT_SECRET='application-client-secret'
```

Behavior:

- When all three Entra variables are present, the sign-in page promotes `Sign in with Microsoft` as the primary path.
- The callback uses the returned Microsoft email identity and matches it to an existing `users.email`.
- If there is no `User` yet but there is an active `members.email`, the app auto-creates a linked member user.
- Local email/password sign-in remains available as an admin fallback.

Azure redirect URI:

```text
https://bookclub.10.82.37.79.sslip.io/auth/entra_id/callback
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

Generate a reserve-history reconciliation report for manual overrides, missing office-tenure data, and suspicious same-day multiple attendance:

```bash
source script/dev-env.sh
bundle exec bin/rake bookclub:reconcile_history
```

## Office assignment backfill

The historical office-assignment foundation is now separate from `members.member_role`.

Preview the current backfill mapping without writing rows:

```bash
source script/dev-env.sh
bundle exec bin/rake bookclub:backfill_offices
```

Apply the backfill with an explicit effective start date:

```bash
source script/dev-env.sh
EFFECTIVE_FROM=2026-01-01 DRY_RUN=false bundle exec bin/rake bookclub:backfill_offices
```

Notes:

- `member_role` remains in place for profile/search compatibility during the transition.
- `bookclub:backfill_offices` reads `config/bookclub/office_tenures.yml` first and falls back to `member_role` labels for members not listed there.
- Member entries in `config/bookclub/office_tenures.yml` are authoritative for that member and should contain the real historical handoff dates when known.
- Use `REPLACE_EXISTING=true` only when you intentionally want to wipe and rebuild office-tenure rows before reapplying a corrected plan.
- `bookclub:backfill_offices` currently maps `회장`, `총무`, and `Lead` roles into effective-dated office assignments.
- Site-leader backfill requires a member location; missing locations are reported as warnings.

Backfill attendance award snapshots after office assignments are in place:

```bash
source script/dev-env.sh
bundle exec bin/rake bookclub:snapshot_attendance_awards
```

Apply the attendance snapshot refresh:

```bash
source script/dev-env.sh
DRY_RUN=false bundle exec bin/rake bookclub:snapshot_attendance_awards
```

Notes:

- Attendance now stores a default `awarded_points` snapshot plus an optional `override_points`.
- Effective reserve payout follows `override_points` first, then the stored snapshot.
- Re-run the snapshot task after major office-tenure backfills or manual historical corrections.
- Use `override_points` for one-off reserve corrections instead of creating fake attendance rows.

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

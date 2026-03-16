# Deployment, Backup, And Cutover Runbook

## Target Shape

Recommended first release shape:

- Single Rails application
- Kamal-based container deployment
- SQLite databases stored on a persistent volume
- Local file/photo storage inside the same persistent volume
- One active fiscal period at a time

This matches the repository defaults in:

- `config/deploy.yml`
- `config/database.yml`
- `Dockerfile`

## Production Data Layout

Expected runtime paths inside the app container:

- Primary DB: `storage/production.sqlite3`
- Solid Cache DB: `storage/production_cache.sqlite3`
- Solid Queue DB: `storage/production_queue.sqlite3`
- Solid Cable DB: `storage/production_cable.sqlite3`
- Uploaded files / local blob storage: `storage/` excluding the SQLite files above

## Deployment Assumptions

Prerequisites:

- `RAILS_MASTER_KEY` is available
- Kamal target host and registry are configured in `config/deploy.yml`
- Persistent volume `edwards_bookclub_storage` or equivalent is mounted to `/rails/storage`
- First admin credentials are provided through seed or post-deploy bootstrap

First deployment sequence:

1. Build and push the image with `bin/kamal setup` or `bin/kamal deploy`.
2. Run migrations with the deployed app.
3. Run `db:seed` once to ensure fiscal period, reserve policies, and bootstrap admin exist.
4. Verify sign-in, admin dashboard, member portal, and importer tooling.

## SQLite Backup

Use the provided script:

```bash
script/backup-production.sh /path/to/backup-root
```

What it does:

- creates a timestamped backup directory
- uses `sqlite3 .backup` for each production SQLite database
- archives non-database files from `storage/` into `storage_files.tar.gz`
- writes a small manifest with timestamps and file names

Why `.backup`:

- safer than copying a live SQLite file directly
- handles journaling state better
- reduces the chance of corrupt point-in-time copies

Operational note:

- run backups during low-write periods when possible
- if a content freeze is already in place for cutover, take the final backup during the freeze window

## SQLite Restore

Use the provided restore script:

```bash
script/restore-production.sh /path/to/backup-root/20260316T000000Z
```

What it does:

- restores each SQLite DB backup into `storage/`
- restores archived storage files back into `storage/`
- preserves a `.pre_restore.<timestamp>` copy of any existing DB before overwriting it

Restore precautions:

- stop app writes before restore
- restore into the same Rails release and schema version used when the backup was taken, or run migrations intentionally after restore
- verify filesystem ownership and permissions after restore

## File / Photo Backup

Photo and uploaded-file handling currently assumes simple local storage under `storage/`.

Backup rule:

- archive `storage/` contents except the SQLite DB files

Restore rule:

- unpack the file archive back into `storage/` after DB restore

If storage later moves to S3-compatible object storage, replace this section with object-store snapshot procedures and keep the DB backup steps unchanged.

## Cutover Sequence

Recommended cutover:

1. Announce a short content freeze for SharePoint list changes.
2. Export the final SharePoint CSVs.
3. Take a final backup of the Rails production volume with `script/backup-production.sh`.
4. Run the importer against the final exports.
5. Run reconciliation checks against the PBIX baseline where applicable.
6. Verify the Rails admin screens:
   - members
   - meetings / attendance / photos / reviews
   - book requests / reserve snapshot
   - fiscal periods / reserve policies
7. Verify member sign-in and member portal scoping.
8. Point operators to the Rails app and stop routine edits in SharePoint.
9. Keep the PBIX file as a read-only reference during the first live period.

## Cutover Validation

Minimum validation checklist:

- `bundle exec bin/rails test`
- `bundle exec bin/rake bookclub:reconcile`
- admin can sign in
- member user can sign in
- active fiscal period is correct
- reserve policy values are correct
- member count matches expected import scope
- latest meetings and book requests are visible
- a new member-side book request can be submitted

## Rollback

Rollback trigger examples:

- importer loaded incorrect final data
- reserve policy or fiscal period settings are wrong
- core admin workflows are blocked
- member scoping leaks or auth failures appear

Rollback steps:

1. Stop edits in the Rails app.
2. Restore the most recent pre-cutover backup with `script/restore-production.sh`.
3. Point operators back to SharePoint + PBIX.
4. Record the exact failing step and affected data.
5. Fix the issue in a new release and repeat the dry run before retrying cutover.

## Dry Run

Use the dry-run helper:

```bash
script/cutover-dry-run.sh
```

It validates:

- expected production file paths
- backup/restore scripts exist and are executable
- Rails test suite passes
- reconciliation task can run

Recommended dry-run cadence:

- once before staging a release candidate
- once again immediately before real cutover using fresh export files

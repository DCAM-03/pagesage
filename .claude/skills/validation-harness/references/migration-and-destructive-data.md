# Migration And Destructive-Data Validation

Use this reference when a change touches the Drift schema, migrations, database open/upgrade paths, backup and
restore, deletion, secure storage, or any path that can destroy user data.

## Separate Authorities

- Distinguish the database owner (schema creation, migration) from ordinary repository access. Migration code runs
  only from the open/migration path, never from a repository, controller, provider, or UI action.
- Migrations must be additive and forward-only. Never edit an already-released migration and never clear user data as
  a migration shortcut.
- Book files are copied into the library directory at import. Removing a book from PageSage must never delete the
  user's original file path.

## Declare The Contract

Before implementation, freeze:

- the exact schema delta and its `schemaVersion`;
- the prior version(s) the migration must upgrade from;
- what happens to existing rows, locators, settings, and indexes;
- whether any derivative data (FTS index, cover cache, daily-reading rows) must be rebuilt;
- backup and restore compatibility, including the rollback copy;
- deletion semantics: what is removed from the database, what is removed from disk, and what is deliberately
  preserved; and
- secure-storage keys: which keys are migrated, and how a failed migration is handled.

## Required Evidence

Select a bounded named matrix; do not run every data path. When applicable, include:

1. fresh install through the production `AppDatabase` open path;
2. upgrade from the immediately supported previous schema state with representative rows;
3. a semantic negative case proving a prohibited or corrupt state is rejected rather than silently reset;
4. backup → delete all → restore, with row counts or probe queries proving the restored state;
5. reader reopen after restore: progress, locators, bookmarks, annotations, and search results resolve to the same
   place in the same book; and
6. deletion: the library record and app copy are gone, the original file path on disk still exists.

Migration text, a schema dump, or a successful build are supporting evidence. They do not prove upgrade behavior, and
they never justify claiming data safety.

Keep applied migrations immutable. If a released migration is wrong, add an immutable forward migration. Redact
failure evidence so it contains no API keys, book text, or full AI context.

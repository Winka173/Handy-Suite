# Architecture

App composition -> thin feature views/controllers -> handy_trip_engine typed immutable
entities and pure services. Platform interfaces: repository, managed assets, one-shot
location, maps/handoff, files, camera, reminders, monetization. Shared packages never
import Trip. SQLite native worker, version/CAS/transactions and indexed references;
IndexedDB Web transaction with quota failures preserving old state. App namespace and
database isolated from the nine existing apps. Saved photos are managed copies, never
gallery paths. Validate before commits; backup restore includes asset checksums and
ID/ref remapping. No migration of existing app databases.

# Implemented schema

Schema 1 new database: trips, places, stops, visits, notes, bookings, packing, expenses,
assets and alarms plus singleton settings/revision. Trip days derive from inclusive
calendar dates, with journal day notes. Asset paths are relative portable keys and bytes
are managed separately from originals. UTC instants + explicit IANA zones, strict local
dates, stable UUIDs, exact decimal money encoded as minor-unit strings. FK/index trip,
date, place, stop, visit time; transactions for check-in + visited projection and restore.
Future/corrupt schemas refuse without clearing. Deletion/Undo retain referenced assets
until safe cleanup. Native indexes are implemented; FTS is not. Future-version,
corrupt database, CAS conflict and rollback tests pass. Optional stop estimate currency
preserves its original denomination when a trip changes currency. P1 uses existing
schema-1 assets/visits and portable fields; it does not reset or migrate other apps.

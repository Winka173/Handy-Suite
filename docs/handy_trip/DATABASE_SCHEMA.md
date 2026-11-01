# Schema plan

Schema 1 new database: trips, places, stops, visits, notes, bookings, packing, expenses,
assets and alarms plus singleton settings/revision. Trip days derive from inclusive
calendar dates, with journal day notes. Asset paths are relative portable keys and bytes
are managed separately from originals. UTC instants + explicit IANA zones, strict local
dates, stable UUIDs, exact decimal money encoded as minor-unit strings. FK/index trip,
date, place, stop, visit time; transactions for check-in + visited projection and restore.
Future/corrupt schemas refuse without clearing. Deletion/Undo retain referenced assets
until safe cleanup. Index/FTS and actual migration tests must be recorded as implemented.

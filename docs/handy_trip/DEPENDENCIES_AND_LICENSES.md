# Dependency decisions

Retain pins: sqlite3 3.5.2 (MIT), web 1.1.1/path_provider 2.1.6 (BSD), archive 4.5.2
(BSD), crypto 3.0.8 (BSD), image 4.12.0 (MIT), pdf 3.13.1 (Apache-2.0), timezone 0.11.2
(BSD), xml 7.0.1 (MIT), desktop_drop 0.8.0 (MIT), existing file/camera/notification
and monetization adapters. No workspace dependency upgrade.

Candidate new pin: geolocator 14.1.2, MIT, maintained Baseflow package published
recently, Android/iOS/Windows/Web implementations, no API key or account. Confirm pub
resolution and transitive licenses before calling this integrated. Foreground one-shot
only; remove merged foreground-service permission since no location stream/service is
used. iOS bypass Always permission; Web needs secure context; Windows OS permission/
service availability is runtime-dependent. No background location entitlement.
[Official package](https://pub.dev/packages/geolocator/versions/14.1.2).

NoBasemap is the initial MapProvider. flutter_map/MapLibre would still need a licensed
tile configuration; rendering libraries do not license tiles or guarantee free offline
use. No provider or caching service is configured, so no tile requests/downloads.
[OSM policy](https://operations.osmfoundation.org/policies/tiles/) prohibits offline
prefetch of its public raster tile server. Coordinates/list/external handoff stay usable.
Installed package LICENSE files and native build requirements will be recorded after
resolution. Browser/native/installer footprint is measured from actual builds, not guessed.

# Fixtures

All content is synthetic and created for this repository. Tests generate PDFs, ZIPs, malformed input, schema vectors and adversarial regex text in memory. This avoids copyrighted sample documents and makes corruption cases reproducible.

`tests/documents.test.ts`: valid 1×1 PNG, two source PDFs with different page sizes, malformed PDF, HTML script/link payload, ZIP traversal name, SRT/VTT timing.
`tests/dev.test.ts`: quoted CSV newline, Unicode, nested JSON, XML DTD/XXE, malformed XML/JSON/Base64, SHA canonical vectors, unsigned JWT, adversarial regex, 12 valid/invalid schema pairs, mocked HTTP offline/404.
`tests/tools.test.ts`: decimal arithmetic, incompatible units, absolute zero, zero-rate and 6% loan, leap days, invalid dates, Unicode, contrast vectors.
`tests/foundation.test.ts`: collisions/path safety, format signatures, queue failure/retry/cancel, contract mismatch, migration and entitlement states.

Device-only media fixtures (HEIC/AVIF, large video, revoked Files provider handle, real camera QR image) remain pending. Generated fixtures are not demo output in production UI.

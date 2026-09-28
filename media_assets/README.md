# Promotional media asset library

Source-of-truth registry for licensed third-party promotional photos.

Rules: verify each source file page; prefer Public Domain/CC0, then CC BY, then CC BY-SA; record creator/license/source/dimensions/watermark; reject unclear licensing and embedded watermarks; preserve attribution and ShareAlike obligations.

Downloaded originals belong in `media_assets/cache/` and are not committed by default. Use Git LFS if binaries are later versioned.

Production inventory: `canonical_event_inventory.items` and its parallel `spot_keys` list reflect the active 44-row Supabase join checked on 2026-09-28. Run `python tool/recalculate_media_readiness.py` after editing the assets, then `python tool/validate_media_assets.py` (or `dart run tool/validate_media_assets.dart` when Dart is installed). The validator rejects stale readiness, off-inventory aliases, missing rights metadata and unsafe cache paths.

Each verified record has a Commons original `download_url` and a deterministic `cache_path`. Run `python tool/download_media_assets.py --max-files 10` from the repo root to populate the ignored cache gradually. The script stops immediately on Commons HTTP 429; retry later rather than overriding the source's rate limit. `cache_path` names are stable across machines but the binary is present only after download. The dated audit lists all 158 input records, including removed mismatches. The dated remaining report lists unresolved spots and their source searches.

# Promotional media asset library

This directory is the source-of-truth registry for third-party photos considered for Seichi Quest promotional videos.

## Rules

1. Never use a photo only because it appears on Wikimedia Commons. Verify the individual file page first.
2. Prefer Public Domain / CC0, then CC BY, then CC BY-SA.
3. Record title/source page, creator, exact license, license URL, dimensions and whether the file contains an embedded watermark.
4. Reject unclear licensing/authorship and embedded-watermark candidates from the automated pipeline.
5. Preserve attribution requirements. If an image is modified, record that fact in the generated credit.
6. CC BY-SA material needs ShareAlike handling for adaptations. Do not silently treat it like unrestricted stock.
7. Keep the original source URL even when a local copy is made.

## Storage strategy

The Git repository stores the manifest and tooling, not an uncontrolled pile of full-resolution binaries. GitHub recommends Git LFS for binary files and keeping repositories small. Approved originals should be downloaded into a local/object-storage asset cache from the verified manifest. If originals are later versioned in GitHub, add them through Git LFS.

## Planned generated layout

```
media_assets/cache/jomo-karuta-gunma/
  onioshidashi/
    source_01.jpg
    source_02.jpg
```

The cache is intentionally not committed by default.

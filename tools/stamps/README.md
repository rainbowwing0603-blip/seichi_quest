# Original stamp assets

This directory documents the workflow for generating original, copyright-conscious stamp artwork for Seichi Quest.

## Naming convention

Use `assets/generated_stamps/<event_slug>/<content_id>.png` for each individual transparent PNG. The stable `content_id` prevents filename collisions when titles change. Keep an inventory mapping event slug, content ID, content key, title, and output path.

## Safety and quality gates

- Create original generic travel motifs only. Do not trace, reproduce, or incorporate copyrighted characters, logos, or official card artwork.
- Generate one file per content item, not a contact sheet.
- Verify that each PNG is 512×512 RGBA, non-empty, and has a transparent background.
- Check Japanese font availability and render text legibly before batch generation.
- Review a representative sample from every event style before bulk creation.
- Do not overwrite production image URLs or upload to production storage until the manifest and image outputs have been validated.

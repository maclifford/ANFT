# ANFT site

Static marketing site for the Association of Nature and Forest Therapies.
Plain HTML/CSS/JS — no build framework. Deployed on Netlify.

## Data-driven content

- `data/trainings.json` — trainings + events shown in the homepage accordion (`index.html#trainings`).
  After editing, re-run `tools/build-trainings.ps1` to re-inline the JSON into `index.html`.
- `data/trainers.json` — the trainers directory (not yet surfaced on a public page).

## Internal editor tools (unlinked, not indexed)

<!--
  Two browser-based editor pages exist for non-technical editing of the data files.
  They are intentionally NOT linked from anywhere and carry <meta robots noindex,nofollow>;
  they are also kept out of sitemap.xml. Filenames are deliberately obscure — rename freely.

    edit-trainings-gate.html  -> edits data/trainings.json (trainings + events)
    edit-people-gate.html     -> edits data/trainers.json  (trainers directory)

  Each tool loads the JSON, lets you add/edit/remove entries with proper inputs
  (date pickers, dropdowns, validation), and produces a complete, pretty-printed file.
  Nothing they do is live automatically. Update routine:
    1. Open the tool and make changes.
    2. Click "Download updated <file>.json" (or copy to clipboard).
    3. Replace the file in /data with the downloaded version.
    4. Deploy. (For trainings, also re-run tools/build-trainings.ps1.)
-->

See the HTML comment above for the internal editor-page paths and how they work.

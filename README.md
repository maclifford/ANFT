# ANFT site

Static marketing site for the Association of Nature and Forest Therapies.
Plain HTML/CSS/JS — no build framework. Deployed on Netlify.

## Trainings data — the one-line routine

**Replace `data/trainings.json` → run `update-trainings` (or just deploy, if Netlify builds) → verify.**

`data/trainings.json` is the single source of truth for the trainings + events
shown in the homepage accordion (`index.html#trainings`) and the apply page's
selected-training card (`apply.html?event=…`). Both pages read an **inlined copy**
of that JSON (no runtime fetch), so after you change the JSON the pages must be
rebuilt or they will show stale data.

You do not have to remember to rebuild:

- **Locally:** double-click **`update-trainings.bat`** in the repo root. It rebuilds
  both pages and then prints **FRESH** (or **STALE** if something went wrong). Works
  with or without Node installed.
- **On Netlify (git-connected sites only):** `netlify.toml` runs the build on every
  deploy, so the published pages are always rebuilt from the current JSON.
  ⚠️ This repo currently has **no git remote**, so no git deploy is connected yet —
  until it is (or if you deploy by drag-and-drop), run `update-trainings.bat` first.

### Build & freshness tools (`tools/`)

- `build-trainings.js` — canonical cross-platform build (Node). Re-inlines the JSON
  into `index.html` and `apply.html` and stamps each with a content-hash freshness marker.
- `build-trainings.ps1` — calls the Node build when Node is present; otherwise runs an
  equivalent pure-PowerShell build (so it works on machines without Node).
- `check-fresh.js` / `check-fresh.ps1` — **staleness guard.** Compare the JSON's current
  hash against the hash embedded in each page and print `FRESH` (exit 0) or
  `STALE — run the build` (exit 1).

### Pre-launch audit

Include the freshness check in the pre-launch sweep — it exits non-zero on stale data,
so it can gate the audit:

```
node tools/check-fresh.js        # or: powershell -File tools/check-fresh.ps1
```

Stale pages must never ship: the audit is not clean unless this prints `FRESH`.

## Other data-driven content

- `data/trainers.json` — the trainers directory (not yet surfaced on a public page).
  No build step: edit → replace the file in `/data` → deploy.

## Internal editor tools (unlinked, not indexed)

<!--
  Two browser-based editor pages exist for non-technical editing of the data files.
  They are intentionally NOT linked from anywhere and carry <meta robots noindex,nofollow>;
  they are also kept out of sitemap.xml. Filenames are deliberately obscure — rename freely.

    edit-trainings-7fq3.html  -> edits data/trainings.json (trainings + events)
    edit-people-7fq3.html     -> edits data/trainers.json  (trainers directory)

  Each tool loads the JSON, lets you add/edit/remove entries with proper inputs
  (date pickers, dropdowns, validation), and produces a complete, pretty-printed file.
  Nothing they do is live automatically.

  Trainings routine:
    1. In edit-trainings-7fq3.html, make changes and "Download updated trainings.json".
    2. Replace data/trainings.json with the downloaded file.
    3. Run update-trainings (double-click update-trainings.bat) — or just deploy if
       the site builds on Netlify.
    4. Verify in the browser.

  Trainers routine (no build step):
    1. In edit-people-7fq3.html, make changes and "Download updated trainers.json".
    2. Replace data/trainers.json with the downloaded file.
    3. Deploy.
-->

See the HTML comment above for the internal editor-page paths and how they work.

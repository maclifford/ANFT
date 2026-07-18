/* =====================================================================
   ANFT COURSE LISTINGS — the "CMS" data file
   =====================================================================
   Each entry controls its own display window:
     listFrom  — first date the card appears  (YYYY-MM-DD)
     listUntil — last date it appears; usually the enrollment deadline
   Cards show automatically between those dates and retire themselves.
   Order on the page = soonest listUntil first (most urgent leads).

   id — short unique slug; the card links to course.html?id=<this>
   blurb — 1-3 sentence description shown on the detail page
   trainers — list of {name, role}; REPLACE THE PLACEHOLDER NAMES
   image — optional path to the course's picture. Put course images in
   images/courses/ (landscape, ~800x500 works well; webp or jpg).
   Cards without an image render as clean text cards.

   To add courses: copy a block, edit the fields, save. Nothing else
   to touch. Claude Code can bulk-add these from a pasted list.
   ===================================================================== */
window.ANFT_COURSES = [
  {
    id:        "ontario-2026",
    format:    "In-Person First",
    place:     "Canada, Ontario",
    venue:     "Dharma Centre of Canada",
    image:     "images/guide-banner.webp",
    dateLabel: "August 2026 · Cohort 171",
    status:    "Enrollment open",
    url:       "https://anft.earth/combos/cb-ontario-august-2026/",
    listFrom:  "2026-01-01",
    listUntil: "2026-08-01",
    blurb:     "A residential immersion at the Dharma Centre of Canada opens this cohort, followed by the six-month online training and mentored practicum.",
    trainers:  [ {name:"Trainer To Be Announced", role:"Lead Trainer"} ]
  },
  {
    id:        "komorebi-2026",
    format:    "Online First",
    place:     "Online, Global",
    venue:     "Komorebi 木漏れ日",
    image:     "images/rfta-banner.webp",
    dateLabel: "Begins July 29, 2026 · Cohort 169",
    status:    "Enrollment open · deadline approaching",
    url:       "https://anft.earth/training-events/komorebi-%e6%9c%a8%e6%bc%8f%e3%82%8c%e6%97%a5/",
    listFrom:  "2026-01-01",
    listUntil: "2026-07-28",
    blurb:     "Begin online with live calls and cohort community, then complete certification with a four-day in-person immersion within two years.",
    trainers:  [ {name:"Trainer To Be Announced", role:"Lead Trainer"} ]
  },
  {
    id:        "georgia-2026",
    format:    "In-Person First",
    place:     "USA, Georgia",
    venue:     "Just Love Forest",
    image:     "images/trail-banner.webp",
    dateLabel: "November 2026 · Cohort 176",
    status:    "Enrollment open",
    url:       "https://anft.earth/combos/usa-georgia-just-love-forest-november-2026/",
    listFrom:  "2026-01-01",
    listUntil: "2026-11-01",
    blurb:     "Begin on the land at Just Love Forest, then continue into the online training and mentored practicum with your cohort.",
    trainers:  [ {name:"Trainer To Be Announced", role:"Lead Trainer"} ]
  }
];

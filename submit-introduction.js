// netlify/functions/submit-introduction.js
//
// Receives an introduction from introduce.html, stores it as a row in Baserow,
// then (best-effort) emails admissions — cc'ing the event's trainers — and sends
// the person a warm confirmation. All secrets come from Netlify environment
// variables; nothing sensitive lives in the page.
//
// Required Netlify environment variables:
//   BASEROW_TOKEN     - Baserow database token with "create rows" permission
//   BASEROW_TABLE_ID  - the Introductions table id (e.g. 1130698)
// Optional (email; if absent, the row is still saved and email is skipped):
//   RESEND_API_KEY    - Resend API key
//   MAIL_FROM         - e.g. "ANFT <introductions@anft.earth>" (needs a verified domain)
//   ADMISSIONS_EMAIL  - defaults to admissions@anft.earth
//   BASEROW_API_URL   - defaults to https://api.baserow.io

const BASEROW_API = process.env.BASEROW_API_URL || 'https://api.baserow.io';

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return json(405, { ok: false, error: 'Method not allowed' });
  }

  let body;
  try { body = JSON.parse(event.body || '{}'); }
  catch (e) { return json(400, { ok: false, error: 'Bad request' }); }

  // Honeypot — a real person never fills this hidden field. Accept silently.
  if (body.company) return json(200, { ok: true });

  const fullName = str(body.fullName);
  const email = str(body.email);
  const eventId = str(body.eventId);
  const consent = body.consent === true || body.consent === 'true';

  if (!fullName || !isEmail(email) || !consent) {
    return json(400, { ok: false, error: 'Please add your name, a valid email, and consent.' });
  }

  // Enrich from the published data: event title, cohort, and the trainers' emails.
  const base = 'https://' + (event.headers.host || '');
  let eventTitle = '', cohort = '', trainerEmails = [];
  try {
    const [trainings, trainers] = await Promise.all([
      fetchJson(base + '/data/trainings.json'),
      fetchJson(base + '/data/trainers.json'),
    ]);
    const recs = [].concat(trainings.trainings || [], trainings.events || []);
    const rec = recs.find((r) => r.id === eventId);
    if (rec) {
      eventTitle = rec.title || '';
      cohort = rec.cohort || '';
      const byId = {};
      (trainers.trainers || []).forEach((t) => { byId[t.id] = t; });
      trainerEmails = (rec.trainers || [])
        .map((id) => byId[id] && byId[id].email)
        .filter(Boolean);
    }
  } catch (e) { /* enrichment is non-fatal */ }

  // 1) Store the row in Baserow (field names must match the table exactly).
  const row = {
    'Event ID': eventId,
    'Event title': eventTitle,
    'Cohort': cohort,
    'Full Name': fullName,
    'Email': email,
    'Country': str(body.country),
    'Calling': str(body.calling),
    'Intention': str(body.intention),
    'Support Needs': str(body.supportNeeds),
    'Consent': true,
    'Policy read': body.policyRead === true || body.policyRead === 'true',
  };
  const payment = str(body.payment);
  if (payment) row['Payment'] = payment; // single select: "Deposit" or "Paid in full"

  try {
    const r = await fetch(
      BASEROW_API + '/api/database/rows/table/' + process.env.BASEROW_TABLE_ID + '/?user_field_names=true',
      {
        method: 'POST',
        headers: {
          'Authorization': 'Token ' + process.env.BASEROW_TOKEN,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(row),
      }
    );
    if (!r.ok) {
      const txt = await r.text();
      return json(502, { ok: false, error: 'Could not save your introduction. Please try again.', detail: txt.slice(0, 300) });
    }
  } catch (e) {
    return json(502, { ok: false, error: 'Could not reach storage. Please try again.' });
  }

  // 2) Emails — best-effort. Never let an email problem fail a saved introduction.
  try { await sendEmails({ fullName, email, eventTitle, cohort, trainerEmails, row }); }
  catch (e) { /* logged by the platform; row is already saved */ }

  return json(200, { ok: true });
};

async function sendEmails({ fullName, email, eventTitle, cohort, trainerEmails, row }) {
  const key = process.env.RESEND_API_KEY;
  if (!key) return; // email not configured yet — Baserow already has the record
  const from = process.env.MAIL_FROM || 'ANFT <onboarding@resend.dev>';
  const admissions = process.env.ADMISSIONS_EMAIL || 'admissions@anft.earth';
  const label = [eventTitle, cohort].filter(Boolean).join(' · ') || 'a training';

  const internalHtml =
    '<h2 style="font-family:sans-serif">New introduction &mdash; ' + esc(label) + '</h2>' +
    '<p style="font-family:sans-serif"><b>Name:</b> ' + esc(fullName) + '<br>' +
    '<b>Email:</b> ' + esc(email) + '<br>' +
    '<b>Country:</b> ' + esc(row['Country'] || '—') + '<br>' +
    '<b>Payment:</b> ' + esc(row['Payment'] || '—') + '</p>' +
    '<p style="font-family:serif"><b>What is calling you:</b><br>' + esc(row['Calling'] || '—') + '</p>' +
    '<p style="font-family:serif"><b>Intention:</b><br>' + esc(row['Intention'] || '—') + '</p>' +
    '<p style="font-family:serif"><b>Support needs:</b><br>' + esc(row['Support Needs'] || '—') + '</p>';

  await resend(key, {
    from: from,
    to: [admissions],
    cc: trainerEmails,
    reply_to: email,
    subject: 'New introduction — ' + label,
    html: internalHtml,
  });

  const custHtml =
    '<p style="font-family:serif">Dear ' + esc(fullName) + ',</p>' +
    '<p style="font-family:serif">Thank you for introducing yourself. Your place for <b>' + esc(label) + '</b> is reserved, and your guides will read what you shared before you meet.</p>' +
    '<p style="font-family:serif">We look forward to walking with you.</p>' +
    '<p style="font-family:serif">&mdash; The Association of Nature and Forest Therapies</p>';

  await resend(key, {
    from: from,
    to: [email],
    subject: 'Your introduction — ' + label,
    html: custHtml,
  });
}

async function resend(key, payload) {
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!r.ok) throw new Error('resend ' + r.status);
}

async function fetchJson(url) {
  const r = await fetch(url);
  if (!r.ok) throw new Error('fetch ' + r.status);
  return r.json();
}

function str(v) { return String(v == null ? '' : v).trim(); }
function isEmail(v) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v); }
function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
function json(status, obj) {
  return { statusCode: status, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(obj) };
}

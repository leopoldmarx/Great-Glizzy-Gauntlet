# GGG — TODO List

Short-term = doable before or during the current event cycle, no backend migration needed.
Long-term = requires or benefits from the custom Node/Postgres backend (see `backend-migration-plan.md`).

---

## Short-Term (Current Stack)

### High Priority

- [ ] **Fix nginx to serve `results-*.json`**
  The nginx config currently blocks all `.json` files. Add an exception for `results-*.json` so the static results page actually works in production.
  ```nginx
  location ~* ^/results-\d{4}\.json$ {
      add_header Cache-Control "no-cache";
      try_files $uri =404;
  }
  ```

- [ ] **Replace Apps Script email with Resend**
  The 100 emails/day Gmail limit is the most urgent production issue. Swap `MailApp.sendEmail()` for a Resend API call. All existing email HTML templates in `GGG Backend google sheets.txt` port over unchanged. Free tier = 3,000 emails/month.
  See: https://resend.com/docs/send-with-node

- [ ] **Auto-close submissions after deadline**
  In `verify.html`, check `new Date() > new Date('2026-05-05T05:59:00Z')` on page load and show a "Submissions closed" banner instead of the form. Prevents late submissions from coming in after the deadline has passed.

- [ ] **Add `rejectionReason` handling in Apps Script**
  The admin panel now sends `rejectionReason` in the `updateStatus` POST body, but the Apps Script backend ignores it. Update `updateSubmissionStatus()` in `GGG Backend google sheets.txt` to store it in the sheet and include it in the rejection email body.

- [ ] **Move admin notes from localStorage to Sheets**
  Admin notes currently live in the browser's localStorage (lost on new device/browser). Add an `adminNotes` column to the sheet and a `saveNotes` action to the Apps Script. The admin panel already has the UI — just needs the backend save call.

- [ ] **Add `results-2026.json` to nginx allowlist**
  Related to the first item — also verify the file is actually accessible at `/results-2026.json` in production by testing after deploy.

### Medium Priority

- [ ] **EmailOctopus year tagging**
  When a rider submits, add them to the EmailOctopus list with a `year:2026` tag via their API. This enables "unsubscribe from 2027 only" campaigns by filtering on the tag. Prevents polluting the whole list when targeting a specific year's riders.

- [ ] **Submission confirmation page**
  After a rider submits, show a nicer confirmation UI instead of just alert(). Could be a simple success card on the verify page with their stats, a "check your email" message, and a link to results.

- [ ] **Impute dwell time when GPS paused at Costco**
  Currently if a rider pauses their Garmin inside a Costco radius, leaves, then resumes, the dwell time reads near-zero. Logic: detect the GPS gap while inside radius, use average riding speed to estimate how far they traveled during the gap, and if they're still inside radius at that estimated point, extend dwell time accordingly. Complex GPS logic — document the edge case for now, address before next event.

- [ ] **Filter ride distance to Costco-to-Costco only**
  Total distance currently includes the rider's travel to/from the first/last Costco. Consider capping it at first-Costco-departure to last-Costco-arrival coordinates, matching how challenge time is calculated. Simpler and more consistent.

- [ ] **Flag if rider registered in time**
  The admin panel shows whether the *submission* was on time. Add a second check: was the rider on the pre-event registration form? This requires either a separate registration list CSV import or a manual check column in the sheet.

### Low Priority / Nice to Have

- [ ] **Purist/Pizza Party eligibility shown on results page**
  Currently only shown as badges. Consider a small tooltip or note explaining what each badge means for first-time viewers.

- [ ] **Strava auto-validation hint**
  If a rider provides a Strava link, show the admin a direct link to the Strava activity date — helps cross-reference the claimed ride date without manually clicking through.

- [ ] **Export submissions to CSV from admin panel**
  Simple client-side download of all submissions as CSV for offline review/backup.

---

## Long-Term (Post Backend Migration)

See `backend-migration-plan.md` for the full scope. Summary of what the migration unlocks:

### Phase 1 — Email (1–2 days, no backend needed)
- [ ] Integrate Resend for transactional email (standalone change, can happen now)

### Phase 2 — Node.js + Postgres + MinIO (1–2 weeks)
- [ ] Replace Apps Script with Fastify API
- [ ] PostgreSQL schema (all fields, JSONB for food orders/verification data)
- [ ] MinIO for GPX file storage (streaming upload, no base64)
- [ ] Admin auth via Bearer token (same model, no user-facing change)
- [ ] Migrate existing 2026 Sheets data to Postgres

### Phase 3 — Results + Admin Notes (3–5 days)
- [ ] "Publish Results" button writes directly to server (no manual `docker cp`)
- [ ] Admin notes stored in `admin_notes` DB column, visible across devices
- [ ] `results-YEAR.json` generated by API endpoint, served by Nginx

### Phase 4 — Advanced Features (ongoing)
- [ ] **Per-segment approve/deny** — admin can approve each Costco-to-Costco leg independently, useful when a rider went significantly off route for one segment but was fine otherwise
- [ ] **Rider submission status page** — rider enters email, sees their submission status without admin involvement
- [ ] **Auto-close submissions** — cron job sets a DB flag at deadline; verify page checks it
- [ ] **GPS jump imputation** — server-side GPX processing with a proper library (`gpxpy` or similar) to handle paused-Garmin dwell time estimation
- [ ] **Second GPX / alternate route file** — support for a second official route variant (e.g. if a segment changes year-over-year) without replacing the original
- [ ] **Approval webhook → EmailOctopus** — when admin approves, automatically tag the rider in EmailOctopus as `status:approved-2026` for targeted post-event campaigns
- [ ] **Static results archive** — each year's `results-YEAR.json` permanently served; multi-year comparison view in results.html

---

## Route / Operational (Not Code)

These came up during post-event review and are noted here for next year's planning:

- [ ] Route: 1700s train tracks section — explore routing over 1300s bridge instead
- [ ] Route: Find alternative to 10400s stretch
- [ ] Route: Move Lehi exit to other side road
- [ ] Pre-event: Get people to help with route recon
- [ ] Logistics: "Purest and Menu Master" eligibility requires all 10 stops — communicated clearly in rules now (code updated), but reinforce in pre-event email
- [ ] Logistics: Decide policy on off-route riders — disqualify full submission vs. disqualify only that segment's food item
- [ ] Logistics: Move deadline announcement to Monday clearly (updated on site already)

---

## Already Done (May 2026 Session)

- [x] Hot Dog Purist, Pizza Party, Menu Master now require all 10 Costcos (not just visited ones)
- [x] GPS pause jumps excluded from total distance calculation (2-min gap threshold)
- [x] Deadline updated to Monday May 4th everywhere on site
- [x] Admin: low dwell time auto-flagged on submission card (orange banner)
- [x] Admin: late submission auto-flagged on submission card (red banner)
- [x] Admin: duplicate flag only triggers after one is *approved* (was already correct)
- [x] Admin: notes textarea with localStorage auto-save per submission
- [x] Admin: custom rejection reason prompt → sent to Apps Script
- [x] Admin: "Publish Results" button downloads `results-YEAR.json` for manual deploy
- [x] results.html: rewritten to load from static `/results-YEAR.json` (no live API call)
- [x] results.html: year selector buttons (2026 only for now, trivially extensible)
- [x] results.html: "Results Coming Soon" state when `published: false` or file missing
- [x] results-2026.json: placeholder file created (`published: false`)
- [x] CLAUDE.md: written with full project context
- [x] docs/backend-migration-plan.md: full migration scope, rationale, schema, API spec
- [x] docs/todo.md: this file

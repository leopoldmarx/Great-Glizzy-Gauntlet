# CLAUDE.md — Great Glizzy Gauntlet

Project context for AI-assisted development. Keep this up to date as the codebase evolves.

---

## What This Is

A self-hosted website for the **Great Glizzy Gauntlet** — a real annual cycling event where riders bike ~100 miles visiting 10 Costco locations across Utah's Wasatch Front (Orem → Bountiful), eating food court items at each stop. Event day: May 2, 2026. Organized by Leopold Marx.

---

## Tech Stack

**Current (as of May 2026):**
- **Frontend**: Static HTML5 / CSS3 / Vanilla JS — no framework, no build step
- **Backend**: Google Apps Script (serverless), Google Sheets (database), Google Drive (GPX storage)
- **Server**: Nginx on Docker, port 36969 local / 443 production
- **Deployment**: Portainer pulling from GitHub, Traefik reverse proxy for SSL
- **Email**: `MailApp` via Google Apps Script (100/day free limit — a known pain point)
- **Marketing email**: EmailOctopus (newsletters/campaigns only — NOT suitable for transactional)
- **Domain**: ggg.lmarx.com

**Planned migration** (see `docs/backend-migration-plan.md`):
- Backend: Node.js (Fastify) + PostgreSQL + MinIO (self-hosted S3 for GPX files)
- Email: Resend (transactional) + keep EmailOctopus (marketing)
- Results: static JSON files published on demand (already partially implemented)

---

## Key Files

| File | Purpose |
|---|---|
| `index.html` | Homepage — countdown, rules, Costco locations, FAQ, prizes |
| `verify.html` | GPX upload, GPS verification, food order form, submission |
| `results.html` | Public leaderboard — now reads from static `/results-YEAR.json` |
| `admin.html` | Password-protected admin panel — review/approve/reject submissions |
| `styles.css` | All shared styles |
| `admin-config.js` | **Gitignored** — contains `GGG_ADMIN_CONFIG = { passwordHash, adminToken }` |
| `GGG Backend google sheets.txt` | Full Google Apps Script source code (copy-paste into Apps Script editor) |
| `Great_Glizzy_Gauntlet.gpx` | Official route GPX file (embedded in admin for route comparison) |
| `results-2026.json` | Static results file for 2026 season (`published: false` until revealed) |
| `docs/backend-migration-plan.md` | Full architecture migration plan and rationale |
| `docs/todo.md` | Short-term and long-term task list |
| `nginx.conf` | Blocks access to configs, scripts, hidden files; serves static files |
| `Dockerfile` / `docker-compose.yml` | Single-container setup (Nginx + static files) |

---

## How Verification Works (verify.html)

1. Rider drops a `.gpx` file
2. Browser parses GPX with `DOMParser`, extracts track points (lat/lon/timestamp)
3. **Haversine distance** checked against each of 10 Costco coordinates + Spanish Fork
4. **0.1-mile radius** = "visited"
5. Calculates:
   - **Challenge time**: last timestamp inside first Costco radius → first timestamp inside last Costco radius
   - **Total distance**: sum of consecutive haversine distances, **skipping gaps > 2 min** (GPS pause/Garmin jump)
   - **Moving speed** (admin only): filters intervals < 2 mph and gaps > 2 min
   - **Dwell time**: last timestamp in radius − first timestamp in radius, per Costco
6. Rider fills food order dropdowns for each visited Costco
7. Bonus auto-detection:
   - **Hot Dog Purist / Pizza Party**: requires all 10 Costcos visited + matching food at each (changed from "any visited" in May 2026)
   - **Menu Master**: requires all 10 visited, no skips, all unique items
   - **Speed Demon**: all 10 visited + elapsed < 7 hours
   - **Spanish Fork**: GPX visited Spanish Fork location
8. Submission is a 2-step POST to Apps Script: form JSON first, then base64 GPX

---

## How the Admin Panel Works (admin.html)

- Auth: client-side SHA-256 password check → server-side `ADMIN_TOKEN` verification on all API calls
- Fetches all submissions from Apps Script, renders cards per submission
- **Flags automatically shown on each card:**
  - ⚠️ Duplicate — GPX hash matches another *approved* submission (not just any)
  - ⏰ Late — `submittedAt` > Monday May 4, 2026 11:59 PM MDT (`2026-05-05T05:59:00Z`)
  - ⚠️ Low Dwell — any visited Costco with < 5 min dwell time (computed from verificationData timestamps)
- **Admin Notes**: textarea on each card, auto-saved to `localStorage` keyed by submission ID
- **Reject**: prompts for a custom reason (sent to Apps Script → included in rejection email)
- **Publish Results**: downloads `results-YEAR.json` for manual deploy to server
  - Deploy command: `docker cp results-2026.json <container>:/usr/share/nginx/html/`
  - Once placed, set `"published": true` in the JSON (the Download button does this automatically)
- Route analysis: Leaflet map comparing rider GPX track against official route (embedded as point array)

---

## How Static Results Work (results.html)

Results no longer fetch from the live Apps Script API. Instead:
1. Page fetches `/results-YEAR.json` (a static file served by Nginx)
2. If file is missing (404) or `published: false` → shows "Results Coming Soon"
3. If `published: true` → renders leaderboard from `results` array

**To publish results:**
1. In admin panel → "Publish Results" → select year → "Download JSON"
2. Run: `docker cp results-2026.json <container_name>:/usr/share/nginx/html/`

**JSON format** (`results-2026.json`):
```json
{
  "year": 2026,
  "published": true,
  "publishedAt": "2026-05-05T12:00:00Z",
  "results": [
    {
      "name": "...", "rideDate": "...", "elapsedTime": 25200000,
      "avgSpeed": "15.2", "totalDistance": "98.5", "movingTime": 23400000,
      "stravaLink": "...", "bonuses": ["hotdog_purist"],
      "foodOrders": "{\"Orem\":\"hotdog\",...}", "costcosVisited": 10, "ebikeUsed": false
    }
  ]
}
```

**Adding a new year**: Add `{ year: 2027, label: '2027' }` to the `YEARS` array in `results.html`, create `results-2027.json` with `published: false`.

---

## Ranking Logic

Applied in both `results.html` (display) and documented for future backend:

1. **Most Costcos visited** (10 > 9 > 8…)
2. **Fewest food skips** (zero skips ranks above any skips at the same stop count)
3. **Fastest elapsed time** (Costco #1 departure → last Costco arrival)

E-bike riders: separate section, same ranking within category.

**Fastest time stat** (stat card): only counts riders with all 10 Costcos AND zero food skips.

---

## Costco Coordinates (canonical, used in verify.html and admin.html)

```
Orem             40.28056, -111.67989   mile 3.1
Lehi             40.38930, -111.82281   mile 20.8
Saratoga Springs 40.38136, -111.91846   mile 26.3
Riverton         40.51326, -112.00193   mile 42.2
South Jordan     40.56004, -111.97541   mile 46.6
Sandy            40.54986, -111.89433   mile 51.7
Murray           40.65774, -111.88997   mile 64.3
West Valley      40.69054, -111.95432   mile 70.6
Salt Lake City   40.73088, -111.90172   mile 78.8
Bountiful        40.89003, -111.89465   mile 99.3
Spanish Fork     40.12397, -111.64918   (bonus, mile 0)
```

---

## Google Apps Script Endpoints

All use the same deployment URL stored in `API_URL` / `SUBMIT_URL` constants:

| Action | Method | Notes |
|---|---|---|
| `addSubmission` (POST, no action param) | POST | Creates sheet row, sends confirmation email |
| `uploadGpx` (POST) | POST | Base64 GPX → Google Drive, updates row |
| `getResults` (GET) | GET | Public; filters approved + year |
| `getSubmissions` (GET) | GET | Admin only; requires `adminToken` |
| `updateStatus` (POST) | POST | Admin only; accepts `rejectionReason` field |

**Known limits:**
- 100 emails/day (free Gmail) — breaks on busy submission days
- 6-min execution timeout — base64 GPX upload is close to this
- No streaming — full GPX must arrive in one request

---

## Security Notes

- `admin-config.js` is gitignored — never commit it
- Nginx blocks: `.json`, `.yml`, `.env`, `.sh`, `.py`, and all hidden files
- **Exception**: `results-*.json` files must be served — add Nginx exception if needed (currently not blocked because the block pattern is `~* \.(json)$` with a location for static files first — verify this works in prod)
- Admin token is verified server-side on every mutation (Apps Script checks `ADMIN_TOKEN` Script Property)

---

## Development Workflow

```bash
# Rebuild and run locally
docker compose down && docker compose build --no-cache && docker compose up -d
# → http://localhost:36969

# Deploy results JSON after publishing
docker cp results-2026.json <container_name>:/usr/share/nginx/html/

# Check container name
docker ps
```

**No build step** — edit HTML/CSS/JS directly, rebuild Docker to see changes.

---

## Things That Are Intentionally Simple

- No JS framework (intentional — zero build complexity, easy to read)
- No database queries on the frontend (all data comes from Apps Script or static files)
- No authentication library (SHA-256 password + UUID token is sufficient for a single-admin tool)
- No CI/CD pipeline beyond Portainer's git pull

---

## Contact / Owner

Leopold Marx — ggg@lmarx.com — leopoldmarx@gmail.com

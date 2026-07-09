# Backend Migration Plan — Google Apps Script → Custom Stack

> Written: May 2026. Covers the decision rationale, proposed architecture, database schema, API spec, and phased rollout for migrating GGG off Google Apps Script into a self-hosted Node.js + PostgreSQL backend.

---

## TL;DR

| Question | Answer |
|---|---|
| EmailOctopus for transactional? | **No** — it's marketing-only, no programmatic send API |
| Static vs live results page? | **Static publish** — better UX, zero real-time dependency |
| Custom backend worth it? | **Yes**, for 500+ riders Google hits hard limits |
| Backend language? | **Node.js (Fastify)** — JS throughout, code sharing with frontend |
| Database? | **PostgreSQL** — JSONB for GPX/food data, easy Docker |
| File storage? | **Local Docker volume → MinIO** (self-hosted S3, no egress fees) |
| Email service? | **Resend** for transactional, keep **EmailOctopus** for campaigns |

---

## Why Migrate Off Google Apps Script

### Hard limits that break at scale

| Constraint | Apps Script Limit | Problem at 500 riders |
|---|---|---|
| Email per day (free Gmail) | **100** | Already breaking with 100 riders |
| Email per day (Workspace) | 1,500 | Still cuts out on busy submission days |
| Script execution time | 6 min/call | Base64 GPX upload already close to this |
| Simultaneous executions | ~30 | Concurrent submissions drop requests |
| URL fetch calls/day | 20,000 | Manageable, but adds up |
| Spreadsheet cells | 10M | Fine, but Sheets is not a real database |

The **email limit is the most urgent cliff**. A busy submission day (all riders submitting the night before the deadline) can easily blow past 100 emails: confirmation + status update = 2 per rider, admin notification = 1. With 100 riders that's 300 emails — already 3x the free limit.

### Other Google ecosystem pain points

- **GPX upload via base64 in a JSON POST** is fragile. Apps Script has a 50MB request limit and the base64 encoding bloats file size ~33%. A 200KB GPX becomes ~270KB before you add the JSON wrapper.
- **No streaming** — the entire GPX must be uploaded in one shot. A timeout partway through silently fails.
- **Drive API rate limits** — at 500 riders you can hit per-minute write limits on Drive file creation.
- **No connection pooling** — every Apps Script execution opens and closes a Sheets connection. This is fine for hundreds of rows, slow for thousands.
- **Debugging** — Apps Script logs are terrible. No real error tracking.

---

## EmailOctopus Assessment

**EmailOctopus is not suitable for transactional email.** It confirmed this explicitly in their own docs: no SMTP relay, no event-triggered single-send API. All sends are campaign-based and created manually in the dashboard.

| Feature | EmailOctopus | Resend |
|---|---|---|
| Marketing campaigns | ✅ Great | ❌ Not its purpose |
| Triggered per-user email via API | ❌ No | ✅ Yes |
| Unsubscribe management | ✅ Built-in | Manual |
| Free tier | 10k emails/mo (2.5k contacts) | **3,000 emails/mo** |
| Paid tier | ~$9/mo (10k contacts) | $0.80/1,000 emails |
| Deliverability | Good | Excellent (built by ex-Sendgrid engineers) |

**Recommended split:**

- **EmailOctopus** → keeps doing what it does: pre-event newsletters, general updates, post-ride recap campaign. Its unsubscribe management is good and it integrates with the existing list.
- **Resend** → all transactional emails: submission confirmation, approval/rejection notification. Simple REST API, 3 lines of code. Already supports the "unsubscribe for just 2027" use case via their audience API (tag contacts as `year:2027` and filter on campaigns).

---

## Proposed Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Docker Host                       │
│                                                      │
│  ┌─────────────┐   ┌──────────────┐   ┌──────────┐  │
│  │   Nginx     │──▶│  Node.js API │──▶│ Postgres │  │
│  │  (port 443) │   │  (Fastify)   │   │          │  │
│  │             │   │  port 3000   │   │ port 5432│  │
│  └──────┬──────┘   └──────┬───────┘   └──────────┘  │
│         │                 │                          │
│         │           ┌─────▼──────┐                  │
│         │           │   MinIO    │                   │
│         ▼           │ (GPX files)│                   │
│  ┌─────────────┐   │  port 9000 │                   │
│  │  Static     │   └────────────┘                   │
│  │  HTML/CSS/JS│                                     │
│  │  + results  │                                     │
│  │  JSON file  │                                     │
│  └─────────────┘                                     │
└─────────────────────────────────────────────────────┘
          │
          ├──▶ Resend API (transactional email)
          └──▶ EmailOctopus API (add to marketing list)
```

### Why Fastify (Node.js)?

- **Language consistency** — the entire codebase is JS. The `COSTCOS` coordinates array, `haversineDistance`, and bonus logic can be imported directly into server-side validation. No duplication.
- **Fastify** is faster than Express, has first-class TypeScript support, and built-in schema validation (JSON Schema).
- **Ecosystem**: `multer` or Fastify's multipart for GPX file uploads, `pg` for Postgres, `@aws-sdk/client-s3` for MinIO (S3-compatible).
- **Alternative**: Python + FastAPI is excellent for the GPS processing side (`gpxpy` library), but introduces a second language. Only worth it if you plan to do heavy server-side GPX analysis.

### Why PostgreSQL?

- JSONB columns for `verificationData` and `foodOrders` — no schema change needed from what Sheets currently stores, but you get indexing and querying.
- Easy to add to Docker Compose alongside the API.
- Handles 500k+ rows without breaking a sweat.
- For the data volume here (thousands of rows max), SQLite would technically work, but Postgres is the right long-term foundation.

### Why MinIO for GPX storage?

- **Self-hosted** — no external dependency, no egress fees.
- **S3-compatible API** — same code works if you ever migrate to Cloudflare R2 or AWS S3.
- Supports presigned URLs so the admin panel can download GPX files directly without routing through the API.
- Docker image is tiny.

---

## Database Schema

```sql
CREATE TABLE submissions (
    id              BIGSERIAL PRIMARY KEY,
    name            TEXT NOT NULL,
    email           TEXT NOT NULL,
    ride_date       DATE,
    elapsed_time_ms BIGINT,           -- challenge time start→end in ms
    avg_speed       NUMERIC(5,2),     -- mph
    total_distance  NUMERIC(6,2),     -- miles
    moving_time_ms  BIGINT,
    strava_link     TEXT,
    bonuses         TEXT[],           -- e.g. {'hotdog_purist','speed_demon'}
    food_orders     JSONB,            -- {"Orem":"hotdog","Lehi":"pizza",...}
    ebike_used      BOOLEAN DEFAULT FALSE,
    comments        TEXT,
    costcos_visited SMALLINT DEFAULT 0,
    gpx_hash        CHAR(16),
    gpx_storage_key TEXT,             -- MinIO object key
    consent_given   BOOLEAN DEFAULT FALSE,
    verification_data JSONB,          -- full GPS verification results
    submitted_at    TIMESTAMPTZ DEFAULT NOW(),
    status          TEXT DEFAULT 'pending'
                        CHECK (status IN ('pending','approved','rejected','duplicate')),
    year            SMALLINT DEFAULT EXTRACT(YEAR FROM NOW()),
    reviewed_at     TIMESTAMPTZ,
    rejection_reason TEXT,            -- custom text shown in rejection email
    admin_notes     TEXT              -- replaces localStorage notes
);

CREATE INDEX idx_submissions_status ON submissions(status);
CREATE INDEX idx_submissions_year   ON submissions(year);
CREATE INDEX idx_submissions_hash   ON submissions(gpx_hash);
CREATE INDEX idx_submissions_email  ON submissions(email);
```

---

## API Endpoints

All endpoints live at `/api/v1/`. The frontend replaces `SUBMIT_URL`, `API_URL`, and `RESULTS_URL` constants with the new base URL.

### Public endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/v1/submissions` | Submit ride (form data) |
| `POST` | `/api/v1/submissions/gpx` | Upload GPX file (multipart) |
| `GET` | `/api/v1/results?year=2026` | Public approved results |
| `GET` | `/api/v1/health` | Health check |

### Admin endpoints (Bearer token auth)

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/admin/submissions` | All submissions |
| `PATCH` | `/api/v1/admin/submissions/:id/status` | Approve / reject / duplicate |
| `PATCH` | `/api/v1/admin/submissions/:id/notes` | Save admin notes |
| `GET` | `/api/v1/admin/submissions/:id/gpx` | Download GPX (presigned URL) |
| `POST` | `/api/v1/admin/results/publish` | Regenerate static results JSON |

### Key design decisions

**GPX upload as multipart, not base64** — eliminates the 33% size inflation and the 50MB Apps Script limit. A 200KB GPX uploads as 200KB. Fastify's `@fastify/multipart` handles streaming directly to MinIO without loading the whole file into memory.

**Static results publish** — `POST /api/v1/admin/results/publish` writes a pre-rendered `results.json` to the static file directory. `results.html` fetches this local file instead of calling a live API. Zero latency, zero dependency on the backend being up during the reveal.

**Admin auth** — Bearer token in `Authorization` header (same secret as today's `ADMIN_TOKEN` in `admin-config.js`). No session management needed for a single-admin tool.

---

## Static Results Strategy

This is the right approach for the event model:

```
Admin reviews → clicks "Publish Results" → 
  API writes /static/results-2026.json →
    results.html fetches /results-2026.json (local file, no API call) →
      Leaderboard renders instantly
```

Benefits:
- **Zero API dependency at reveal time** — results.html is pure HTML + a static JSON file. If the server is under load from everyone hitting the page at once, the API doesn't get hammered.
- **Instant load** — no fetch round trip to a live endpoint.
- **Controlled reveal** — you publish exactly when you're ready. `RESULTS_HIDDEN = true` stays until you click Publish.
- **Archive** — `results-2026.json` stays on disk forever. Next year you add `results-2027.json`.

The current live approach (fetching from Apps Script in real time) has a real problem with 500 concurrent visitors: Apps Script will start returning errors under load, and Nginx doesn't cache POST responses.

---

## Email Architecture (Resend)

```javascript
// Single Resend API call to replace all MailApp.sendEmail() calls
import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY);

await resend.emails.send({
  from: 'GGG <noreply@ggg.lmarx.com>',
  to: rider.email,
  subject: '✅ GGG — Ride approved!',
  html: approvalEmailHtml(rider),
});
```

Resend's free tier gives **3,000 emails/month** — enough for a 500-rider event (submission confirmation + status update = 1,000 rider emails + ~500 admin notifications = 1,500 total per event). Paid is $0.80/1,000 after that.

The existing email HTML templates in `GGG Backend google sheets.txt` port directly — no changes needed.

### EmailOctopus integration for "unsubscribe from 2027 only"

When a rider submits, also call the EmailOctopus API to add them to the list with a `year:2026` tag. For 2027, create a separate segment. This is the cleanest way to let people unsubscribe from future years without nuking their existing subscription.

```javascript
// Add to EmailOctopus list with year tag
await fetch('https://emailoctopus.com/api/1.6/lists/{LIST_ID}/contacts', {
  method: 'POST',
  body: JSON.stringify({
    api_key: process.env.EMAILOCTOPUS_API_KEY,
    email_address: rider.email,
    fields: { FirstName: rider.name.split(' ')[0], Year: '2026' },
    tags: ['2026-rider'],
  }),
});
```

---

## Docker Compose

Replace the current single-container `docker-compose.yml` with a multi-service stack:

```yaml
services:
  nginx:
    image: nginx:alpine
    ports: ["443:443", "80:80"]
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./static:/usr/share/nginx/html:ro   # existing frontend
      - certs:/etc/letsencrypt:ro
    depends_on: [api]

  api:
    build: ./api                             # new Node.js service
    environment:
      DATABASE_URL: postgres://ggg:${DB_PASSWORD}@postgres:5432/ggg
      MINIO_ENDPOINT: minio
      MINIO_ACCESS_KEY: ${MINIO_ACCESS_KEY}
      MINIO_SECRET_KEY: ${MINIO_SECRET_KEY}
      RESEND_API_KEY: ${RESEND_API_KEY}
      EMAILOCTOPUS_API_KEY: ${EMAILOCTOPUS_API_KEY}
      ADMIN_TOKEN: ${ADMIN_TOKEN}
    depends_on: [postgres, minio]

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ggg
      POSTGRES_USER: ggg
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY}
    volumes:
      - gpxdata:/data

volumes:
  pgdata:
  gpxdata:
  certs:
```

---

## Migration Plan

### Phase 1 — Fix Email Now (1–2 days, zero downtime)

Bypass Apps Script email entirely. Add a Resend API call directly from the frontend submission (client-side → Resend API, or via a tiny proxy endpoint on your existing Nginx). This solves the 100 emails/day cliff immediately without touching the rest of the stack.

**Deliverable**: Riders get reliable email confirmations/approvals regardless of Gmail daily quota.

### Phase 2 — New Node API (1–2 weeks)

Build the Fastify API service, PostgreSQL schema, and MinIO setup. Keep the frontend HTML/CSS/JS identical — just update the 3 URL constants in each page.

Migrate existing Sheets data: export as CSV → import script into Postgres.

**Deliverable**: Apps Script retired. All submissions go to Postgres. GPX files in MinIO. Same frontend, same admin panel.

### Phase 3 — Static Results + Admin Notes (3–5 days)

- Move admin notes from `localStorage` to the `admin_notes` column in Postgres.
- Build the "Publish Results" button in admin that calls `POST /api/v1/admin/results/publish`.
- Update `results.html` to fetch `/results-2026.json` instead of the Apps Script URL.

**Deliverable**: Controlled leaderboard reveal. Admin notes persist across devices/browsers.

### Phase 4 — Segment Approval + Advanced Features (future)

- Per-segment approve/deny (from the todo list).
- Automated submission close based on deadline (cron job sets a DB flag).
- Rider-facing submission status page (check your own status with email lookup).
- GPS jump imputation (paused Garmin at Costco — Phase 4 because it requires server-side GPX processing with a proper library like `gpxpy` or a JS port).

---

## Effort Estimate

| Phase | Effort | Complexity |
|---|---|---|
| Phase 1 (Resend email) | 1–2 days | Low |
| Phase 2 (Node API + Postgres + MinIO) | 1–2 weeks | Medium |
| Phase 3 (Static results + DB notes) | 3–5 days | Low–Medium |
| Phase 4 (Segment approval etc.) | Ongoing | High |

Phase 1 is the obvious quick win — do it before any future event regardless of whether the full migration happens.

Phase 2 is self-contained and doesn't require any frontend changes beyond updating 3 URL constants.

---

## What Stays the Same

- All frontend HTML/CSS/JS (index, verify, results, admin) — near-zero changes
- Nginx config — add a `/api/` proxy pass block, rest stays the same
- Docker deployment workflow
- Admin password + token auth model
- GPX parsing and verification logic (runs client-side in the browser, unchanged)
- EmailOctopus for marketing campaigns
- The `admin-config.js` pattern for secrets not checked into git

---

## Open Questions

1. **Domain for API** — same domain (`ggg.lmarx.com/api`) or separate subdomain (`api.ggg.lmarx.com`)? Same domain is simpler (no CORS config).
2. **Backups** — Postgres `pg_dump` on a cron to a separate volume or offsite. What's the current backup story for the Google Sheet?
3. **Monitoring** — Worth adding a simple uptime monitor (e.g. UptimeRobot free) now that the backend is self-hosted.
4. **Data migration** — The current Sheets data has `verificationData` as a JSON string in a cell. Need a one-time migration script to parse and insert into the JSONB column.

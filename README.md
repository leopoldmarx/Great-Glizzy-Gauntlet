# Great Glizzy Gauntlet Website

A static website for the Great Glizzy Gauntlet - an epic 100-mile cycling challenge visiting 10 Costco locations along Utah's Wasatch Front!

## About

Inspired by the legendary Taco Bell 50K in Denver, the Great Glizzy Gauntlet is a cycling adventure that visits 10 of Utah's 12 Costco locations across Utah, Salt Lake, and Davis Counties. This 100-mile route is designed around Utah's FrontRunner commuter rail system and bike trail network, offering multiple bailout points for riders of all levels.

**Challenge Day: May 2, 2026**
**Official Start: 10:00 AM at Orem Costco**
**Website: https://ggg.lmarx.com/**

## Challenge Rules

- Visit all 10 Costcos from south to north (Orem to Bountiful)
- Purchase and consume at least one food court item at each location
- Complete all 10 stops on the same day
- Self-powered only (bikes or e-bikes)
- Provide GPX proof via https://ggg.lmarx.com/verify

### Bonus Challenges

- Hot Dog Purist: Get the $1.50 combo at all 10 locations
- Pizza Party: Eat pizza at all 10 locations
- Menu Master: Get a different item at each Costco
- Sample Collector: Get at least one free sample at 5/10 locations
- Speed Demon: Finish in under 7 hours
- Spanish Fork Extension: Start at Spanish Fork for 115 miles!

## Tech Stack

- **Frontend**: Static HTML5, CSS3, vanilla JavaScript
- **Backend**: Google Apps Script (serverless)
- **Server**: Nginx (Alpine Linux)
- **Containerization**: Docker & Docker Compose
- **Domain**: https://ggg.lmarx.com/

## Quick Start

### Development (Windows One-Liner)

Stop any existing container, rebuild without cache, and run:

```powershell
docker compose down; docker compose build --no-cache; docker compose up -d
```

Or using cmd:

```cmd
docker compose down && docker compose build --no-cache && docker compose up -d
```

### Development (Linux/Mac One-Liner)

```bash
docker compose down && docker compose build --no-cache && docker compose up -d
```

### Using Docker Compose

```bash
docker compose up -d
```

Then open your browser to `http://localhost:36969`

### Using Docker Directly

```bash
docker build -t costcoride .
docker run -d -p 36969:80 --name costcoride costcoride
```

## Project Structure

```
.
├── index.html          # Main homepage with countdown, rules, route info
├── verify.html         # GPX upload and ride verification page
├── results.html        # Public leaderboard/results page
├── admin.html          # Admin panel for reviewing submissions
├── admin-config.js     # Admin password hash (KEEP IN .gitignore!)
├── styles.css          # Main stylesheet
├── nginx.conf          # Nginx configuration with security rules
├── Dockerfile          # Container definition
├── docker-compose.yml  # Local dev configuration
├── README.md           # This file
├── .gitignore          # Git ignore rules
└── [Images]
    ├── ggg-bike-logo.png
    ├── costco_outside_square.jpg
    ├── Costco_outside.jpg
    └── Hotdog_foodcourt.jpg
```

## Pages

### Homepage (index.html)
- Live countdown timer to May 2, 2026
- Challenge rules and bonus challenges
- All 10 Costco locations with addresses and distances
- FrontRunner meet-up schedule
- Bailout point information
- Email signup for updates
- FAQ section
- Safety disclaimers

### Verify Page (verify.html)
- GPX file upload with drag-and-drop
- Automatic GPS verification against Costco coordinates
- Calculates challenge time (Orem departure to Bountiful arrival)
- Calculates average speed and total distance
- Submission form for official results

### Results Page (results.html)
- Public leaderboard sorted by time
- Stats cards (total finishers, completions, fastest time)
- Achievement badges display
- Links to Strava activities

### Admin Panel (admin.html)
- Password-protected login
- Review pending submissions
- Approve/reject/mark as duplicate
- View GPS verification data
- Tabs for pending, approved, rejected, all

## Backend (Google Apps Script)

The backend is a Google Apps Script deployed as a web app. It handles:

- Storing ride submissions in Google Sheets
- Email notifications for new submissions
- Serving approved results via API
- Admin submission management

**Sheet Columns:**
`id, name, email, rideDate, elapsedTime, avgSpeed, totalDistance, movingTime, stravaLink, bonuses, comments, costcosVisited, gpxHash, verificationData, submittedAt, status, year, reviewedAt`

**Note:** `elapsedTime` and `movingTime` are stored in milliseconds for accurate sorting and display.

## Security

### Admin Authentication (Two-Factor)

The admin panel uses two layers of security:

1. **Client-side password** - SHA-256 hash stored in `admin-config.js`
2. **Server-side token** - Secret token verified by Google Apps Script

**IMPORTANT:** `admin-config.js` must be in `.gitignore` to prevent exposure!

#### Setup Instructions

1. **Generate a password hash** (run in browser console):
```javascript
async function hash(p) {
  const d = new TextEncoder().encode(p);
  const h = await crypto.subtle.digest('SHA-256', d);
  return [...new Uint8Array(h)].map(b => b.toString(16).padStart(2, '0')).join('');
}
await hash('your-password-here');
```

2. **Generate an admin token** (run in browser console):
```javascript
crypto.randomUUID()
// Example output: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
```

3. **Update `admin-config.js`:**
```javascript
const GGG_ADMIN_CONFIG = {
    passwordHash: 'your-generated-hash',
    adminToken: 'your-generated-uuid'
};
```

4. **Add token to Google Apps Script:**
   - Open your Google Apps Script project
   - Go to Project Settings (gear icon)
   - Click "Script Properties"
   - Add property: `ADMIN_TOKEN` = `your-generated-uuid` (same as step 3)
   - Save and create a new deployment

### Nginx Security
The nginx configuration blocks access to:
- Document files (`.docx`, `.xlsx`, `.csv`, `.txt`, etc.)
- Configuration files (`.env`, `.conf`, `.ini`, `.json`, `.yml`)
- Script files (`.sh`, `.py`, `.php`, etc.)
- Hidden files (starting with `.`)
- Backup/temp files (`.bak`, `.tmp`, `.swp`, etc.)
- Admin config files
- Cache directories (`__pycache__`, `node_modules`, `.git`)

### HTTPS
SSL/HTTPS is handled by a reverse proxy (Portainer/Traefik). The container exposes port 80 internally.

## Deployment

### Production (Portainer with Git)

The production deployment uses Portainer to pull from GitHub. Admin credentials are passed via environment variables.

**Setup Steps:**

1. **In Portainer**, create a new Stack from Git repository
2. **Repository URL**: `https://github.com/your-username/costco-ride`
3. **Add Environment Variables** in the Portainer stack settings:
   ```
   ADMIN_PASSWORD_HASH=your_sha256_hash_here
   ADMIN_TOKEN=your_uuid_token_here
   ```
4. Deploy the stack

**To generate your credentials:**
```javascript
// Run in browser console:

// 1. Generate password hash
async function hash(p) {
  const d = new TextEncoder().encode(p);
  const h = await crypto.subtle.digest('SHA-256', d);
  return [...new Uint8Array(h)].map(b => b.toString(16).padStart(2, '0')).join('');
}
await hash('your-password-here');

// 2. Generate admin token
crypto.randomUUID();
```

**Important**: The same `ADMIN_TOKEN` must be added to your Google Apps Script project:
- Go to Project Settings > Script Properties
- Add: `ADMIN_TOKEN` = `your-uuid-token`

### Local Development

1. Copy `.env.example` to `.env` and fill in your values
2. Run:
```bash
docker compose down && docker compose build --no-cache && docker compose up -d
```

Or create `admin-config.js` manually (this file is gitignored):
```javascript
const GGG_ADMIN_CONFIG = {
    passwordHash: 'your_sha256_hash',
    adminToken: 'your_uuid_token'
};
```

## Route Details

- **Distance**: 100 miles (115 miles with Spanish Fork extension)
- **Costco Stops**: 10 (11 with bonus location)
- **Counties**: Utah, Salt Lake, Davis
- **Direction**: South to North
- **FrontRunner Bailouts**: 6 stations along the route
- **Route Link**: [View on Ride with GPS](https://ridewithgps.com/routes/53521603)

### The 10 Costcos (South to North)

| # | Location | County | Mile Marker |
|---|----------|--------|-------------|
| 1 | Orem | Utah | 3.1 (Start) |
| 2 | Lehi | Utah | 20.9 |
| 3 | Saratoga Springs | Utah | 26.4 |
| 4 | Riverton | Salt Lake | 42.4 |
| 5 | South Jordan | Salt Lake | 46.9 |
| 6 | Sandy | Salt Lake | 52.0 |
| 7 | Murray | Salt Lake | 64.6 |
| 8 | West Valley | Salt Lake | 70.9 |
| 9 | Salt Lake City | Salt Lake | 77.7 |
| 10 | Bountiful | Davis | 98.9 (Finish) |

**Bonus**: Spanish Fork (optional pre-ride extension, adds ~15 miles)

## External Integrations

- **Ride with GPS**: Route map embed (Route ID: 53521603)
- **Google Apps Script**: Backend API and email notifications
- **Google Sheets**: Data storage for submissions
- **Google Fonts**: Poppins font family

## License

Feel free to use this template for your own cycling challenges!

## Credits

- **Route Design**: Leopold
- **Inspired by**: Taco Bell 50K Challenge (Denver, CO)
- **Contact**: ggg@lmarx.com

*Not affiliated with Costco Wholesale Corporation or UTA FrontRunner*

---

**Stay safe, ride responsibly, and enjoy those food court items!**

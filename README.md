# SLC 10 Glizzy Challenge Website

A website showcasing the epic 10-Costco, 90-mile cycling challenge through Salt Lake County and beyond!

## 🌭 About

Inspired by the legendary Taco Bell 50K in Denver, the SLC 10 Glizzy Challenge is a cycling adventure that visits all 10 Costco locations across Utah, Salt Lake, and Davis Counties. This 90-mile route is designed around Utah's FrontRunner commuter rail system and bike trail network, offering multiple bailout points for riders of all levels.

**Challenge Day: May 2, 2026**

## 🎯 Challenge Rules

- Visit all 10 Costcos from south to north (Orem → Bountiful)
- Purchase and consume at least one food court item at each location
- Complete all 10 stops on the same day
- Self-powered only (bikes or e-bikes)
- Provide photo proof at each location

### Bonus Challenges
- 🌶️ Hot Dog Purist: Get the $1.50 combo at all 10 locations
- 🍕 Pizza Party: Eat pizza at all 10 locations
- 🎭 Menu Master: Get a different item at each Costco
- 🧪 Sample Collector: Get at least one free sample at each location
- ⚡ Speed Demon: Finish in under 8 hours
- 🏔️ Spanish Fork Extension: Start at Spanish Fork for 105 miles!

## 🚀 Quick Start

### Using Docker Compose (Recommended)

1. Make sure you have Docker and Docker Compose installed
2. Clone or download this repository
3. Run:
   ```bash
   docker-compose up -d
   ```
4. Open your browser to `http://localhost:36969`

### Using Docker

Build and run manually:
```bash
docker build -t costcoride .
docker run -d -p 36969:80 --name costcoride costcoride
```

## 🛠️ Development

The website is a simple static site consisting of:
- `index.html` - Main HTML file with countdown timer
- `styles.css` - Styling
- `Dockerfile` - Docker configuration
- `docker-compose.yml` - Docker Compose configuration

To make changes:
1. Edit the HTML or CSS files
2. If using Docker Compose with volumes, changes will be reflected immediately
3. If not using volumes, rebuild the container:
   ```bash
   docker-compose down
   docker-compose up --build -d
   ```

## 📦 Deployment

### Production Deployment

For production, you may want to:

1. **Change the port** in `docker-compose.yml`:
   ```yaml
   ports:
     - "80:80"  # For standard HTTP
   ```

2. **Add SSL/HTTPS** using a reverse proxy like Nginx or Traefik

3. **Set up a domain** and point it to your server

4. **Enable automatic restarts**:
   ```yaml
   restart: always
   ```

### Example Production Setup with Nginx Reverse Proxy

If you're running this behind nginx:

```nginx
server {
    listen 80;
    server_name costcoride.com;

    location / {
        proxy_pass http://localhost:36969;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 🏔️ Route Details

- **Distance**: 90 miles (105 miles with Spanish Fork extension)
- **Costco Stops**: 10 (11 with bonus location)
- **Counties**: Utah, Salt Lake, Davis
- **Direction**: South to North
- **FrontRunner Stations**: 5 bailout points
- **Route Link**: [View on Ride with GPS](https://ridewithgps.com/routes/53354590)

### The 10 Costcos (South to North)
1. Orem (Utah County) - START
2. Lehi (Utah County)
3. Saratoga Springs (Utah County)
4. Riverton (Salt Lake County)
5. South Jordan (Salt Lake County)
6. Sandy (Salt Lake County)
7. Murray (Salt Lake County)
8. West Valley (Salt Lake County)
9. Salt Lake City (Salt Lake County)
10. Bountiful (Davis County) - FINISH

**Bonus:** Spanish Fork (optional pre-ride extension)

## 🚆 FrontRunner Meet-Up

The website includes suggested FrontRunner meeting times to help riders coordinate:
- Depart from various stations starting at 5:45 AM
- Arrive at Orem Costco by 7:00 AM
- Challenge starts when Costco opens at 10:00 AM

## ✨ Website Features

- Live countdown timer to May 2, 2026
- Complete challenge rules and bonus challenges
- All 10 Costco locations with addresses
- FrontRunner meet-up schedule
- Bailout point information
- Responsive mobile-friendly design
- Embedded route map
- Costco-themed color scheme

## 🎨 Customization

### Changing Colors

Edit the CSS variables in `styles.css`:
```css
:root {
    --primary-color: #e31837;    /* Costco red */
    --secondary-color: #005daa;  /* Blue */
    --accent-color: #ffc72c;     /* Yellow/gold */
}
```

### Adding More Sections

The HTML uses a modular section structure. To add a new section:
```html
<section id="your-section" class="section">
    <div class="container">
        <h2 class="section-title">Your Title</h2>
        <!-- Your content -->
    </div>
</section>
```

## 📝 License

Feel free to use this template for your own cycling challenges!

## 🙏 Credits

Route design: Leopold
Inspired by: Taco Bell 50K Challenge (Denver, CO)
Not affiliated with Costco Wholesale Corporation or UTA FrontRunner

## 🐛 Issues or Suggestions?

Feel free to modify the site to fit your needs. Some ideas:
- Add a photo gallery
- Include rider testimonials  
- Add a leaderboard for fastest times
- Create printable cue sheets
- Add weather forecasts
- Integrate Strava segments

---

**Stay safe, ride responsibly, and enjoy those food court items! 🌭🍕🚲**
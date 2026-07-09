FROM nginx:alpine

# Copy the main HTML pages
# admin.html and admin-config.js are intentionally excluded — open locally, not served publicly
COPY index.html /usr/share/nginx/html/
COPY verify.html /usr/share/nginx/html/
COPY results.html /usr/share/nginx/html/

# Copy stylesheets
COPY styles.css /usr/share/nginx/html/

# Copy SEO files
COPY sitemap.xml /usr/share/nginx/html/
COPY robots.txt /usr/share/nginx/html/

# Copy favicon
COPY favicon.ico /usr/share/nginx/html/
COPY favicon.svg /usr/share/nginx/html/

# Copy images
COPY Great_Glizzy_Gauntlet.gpx /usr/share/nginx/html/
COPY costco_outside_square.jpg /usr/share/nginx/html/
COPY Hotdog_foodcourt.jpg /usr/share/nginx/html/
COPY ggg-bike-logo.png /usr/share/nginx/html/
COPY wholesale-hotdog-logo.png /usr/share/nginx/html/
COPY SessionCo_778.jpg /usr/share/nginx/html/
COPY Sessionco_beer.jpeg /usr/share/nginx/html/
COPY food-court.JPG /usr/share/nginx/html/

# Copy results JSON (published: false until revealed via admin panel)
COPY results-2026.json /usr/share/nginx/html/

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy entrypoint script and fix line endings (Windows -> Unix)
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN sed -i 's/\r$//' /docker-entrypoint.sh && chmod +x /docker-entrypoint.sh

# Expose port 80
EXPOSE 80

# Use entrypoint to generate config from env vars, then start nginx
ENTRYPOINT ["/docker-entrypoint.sh"]

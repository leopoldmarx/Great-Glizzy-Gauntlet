FROM nginx:alpine

# Copy the main HTML pages
COPY index.html /usr/share/nginx/html/
COPY verify.html /usr/share/nginx/html/
COPY results.html /usr/share/nginx/html/
COPY admin.html /usr/share/nginx/html/

# Copy admin config (ensure this is in .gitignore!)
COPY admin-config.js /usr/share/nginx/html/

# Copy stylesheets
COPY styles.css /usr/share/nginx/html/

# Copy SEO files
COPY sitemap.xml /usr/share/nginx/html/
COPY robots.txt /usr/share/nginx/html/

# Copy images
COPY costco_outside_square.jpg /usr/share/nginx/html/
COPY Costco_outside.jpg /usr/share/nginx/html/
COPY Hotdog_foodcourt.jpg /usr/share/nginx/html/
COPY ggg-bike-logo.png /usr/share/nginx/html/

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
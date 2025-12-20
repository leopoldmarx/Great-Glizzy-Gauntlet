FROM nginx:alpine

# Copy the website files to nginx html directory
COPY index.html /usr/share/nginx/html/
COPY styles.css /usr/share/nginx/html/
COPY Costco_outside.jpg /usr/share/nginx/html/
COPY costco_outside_square.jpg /usr/share/nginx/html/
COPY Hotdog_foodcourt.jpg /usr/share/nginx/html/
COPY costco_logo.png /usr/share/nginx/html/

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
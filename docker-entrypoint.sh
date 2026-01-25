#!/bin/sh

# Generate admin-config.js from environment variables
# If not set, use placeholder values that won't work (safer than exposing defaults)
cat > /usr/share/nginx/html/admin-config.js << EOF
const GGG_ADMIN_CONFIG = {
    passwordHash: '${ADMIN_PASSWORD_HASH:-PLACEHOLDER_SET_ENV_VAR}',
    adminToken: '${ADMIN_TOKEN:-PLACEHOLDER_SET_ENV_VAR}'
};
EOF

# Start nginx
exec nginx -g 'daemon off;'

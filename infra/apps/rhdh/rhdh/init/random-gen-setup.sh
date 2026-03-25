#TODO: map to helm maybe

#!/bin/bash
CLUSTER_DOMAIN="apps.snoaxolab.axodevelopment.dev"

echo "=== Gitea App Secret ==="
echo "SECRET_KEY: $(openssl rand -hex 32)"
echo "INTERNAL_TOKEN: $(openssl rand -hex 32)"
echo "JWT_SECRET: $(openssl rand -hex 32)"

echo ""
echo "=== Gitea Admin Secret ==="
echo "GITEA_ADMIN_PASSWORD: $(openssl rand -base64 20 | tr -d '=+/')"

echo ""
echo "=== Keycloak DB Secret ==="
KC_DB_PASS=$(openssl rand -base64 20 | tr -d '=+/')
echo "username (b64): $(echo -n 'keycloak' | base64)"
echo "password (b64): $(echo -n ${KC_DB_PASS} | base64)"
echo "password (plain): ${KC_DB_PASS}"

echo ""
echo "=== RHDH Secrets ==="
echo "REDIS_PASSWORD: $(openssl rand -base64 20 | tr -d '=+/')"
echo "POSTGRES_PASSWORD: $(openssl rand -base64 20 | tr -d '=+/')"
echo "POSTGRES_ADMIN_PASSWORD: $(openssl rand -base64 20 | tr -d '=+/')"
echo "SESSION_SECRET: $(openssl rand -hex 32)"
echo "KEYCLOAK_CLIENT_SECRET: $(openssl rand -hex 20)"
echo "KEYCLOAK_BASE_URL: https://keycloak.${CLUSTER_DOMAIN}"
echo "GITEA_BASE_URL: https://gitea.${CLUSTER_DOMAIN}"
echo "GITEA_HOST: gitea.${CLUSTER_DOMAIN}"
echo ""
echo "NOTE: GITEA_TOKEN comes from job logs after Gitea init"
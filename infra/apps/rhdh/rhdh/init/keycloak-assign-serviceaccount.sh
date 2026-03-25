TOKEN=$(curl -sk -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&grant_type=password&username=temp-admin&password=${ADMIN_PASS}" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# Enable service accounts on the rhdh client
curl -sk -X PUT \
  "${KEYCLOAK_URL}/admin/realms/rhdh/clients/${CLIENT_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "rhdh",
    "serviceAccountsEnabled": true,
    "standardFlowEnabled": true,
    "directAccessGrantsEnabled": false,
    "publicClient": false
  }'

echo "Client updated"

# Verify
curl -sk \
  "${KEYCLOAK_URL}/admin/realms/rhdh/clients/${CLIENT_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('serviceAccountsEnabled:', d['serviceAccountsEnabled'])"
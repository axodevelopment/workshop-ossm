# TODO: We need to manually assign realm-manageemtn and view-roles to the init admina account

# TODO: cleanup keycloak url, get keycloak base url
KEYCLOAK_URL=https://keycloak.apps.snoaxolab.axodevelopment.dev


# TODO: This will likely change as i'll create a permenant keycloak admin user rather then the temp
ADMIN_PASS=$(oc get secret keycloak-initial-admin -n keycloak \
  -o jsonpath='{.data.password}' | base64 -d)

# get the token
TOKEN=$(curl -sk -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&grant_type=password&username=temp-admin&password=${ADMIN_PASS}" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# Get rhdh client ID
CLIENT_ID=$(curl -sk \
  "${KEYCLOAK_URL}/admin/realms/rhdh/clients?clientId=rhdh" \
  -H "Authorization: Bearer ${TOKEN}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")

echo "rhdh client ID: ${CLIENT_ID}"

# Get service account user ID
SA_USER_ID=$(curl -sk \
  "${KEYCLOAK_URL}/admin/realms/rhdh/clients/${CLIENT_ID}/service-account-user" \
  -H "Authorization: Bearer ${TOKEN}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

echo "service account user ID: ${SA_USER_ID}"

# Get realm-management client ID
RM_ID=$(curl -sk \
  "${KEYCLOAK_URL}/admin/realms/rhdh/clients?clientId=realm-management" \
  -H "Authorization: Bearer ${TOKEN}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")

echo "realm-management client ID: ${RM_ID}"

# Get view-users role
VIEW_USERS=$(curl -sk \
  "${KEYCLOAK_URL}/admin/realms/rhdh/clients/${RM_ID}/roles/view-users" \
  -H "Authorization: Bearer ${TOKEN}")

echo "view-users role: ${VIEW_USERS}"

# Assign it
curl -sk -X POST \
  "${KEYCLOAK_URL}/admin/realms/rhdh/users/${SA_USER_ID}/role-mappings/clients/${RM_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "[${VIEW_USERS}]"

echo "Done"
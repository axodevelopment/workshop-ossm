TOKEN_KC=$(curl -sk -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&grant_type=password&username=temp-admin&password=${ADMIN_PASS}" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

CONTENT=$(printf 'apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: rhdh-admin
  namespace: default
spec:
  profile:
    email: rhdh-admin@example.com
    displayName: RHDH Admin
  memberOf:
    - rhdh-admins
' | base64 -w 0)

curl -sk -X POST \
  "https://gitea.apps.snoaxolab.axodevelopment.dev/api/v1/repos/workshop/catalog/contents/users/rhdh-admin.yaml" \
  -H "Content-Type: application/json" \
  -H "Authorization: token cce43b068e4290bf0cba487964876ce12b118a12" \
  -d "{\"message\":\"Add rhdh-admin user entity\",\"content\":\"${CONTENT}\"}"
#!/bin/bash
# want to test JWT Token for the authpolicy

KEYCLOAK_ROUTE=$(oc get route -l app=keycloak -n keycloak -o jsonpath='{.items[0].spec.host}')
echo "Keycloak: https://$KEYCLOAK_ROUTE"

# dev token test
DEV_TOKEN=$(curl -sk \
  -d "client_id=bookinfo" \
  -d "client_secret=bookinfo-client-secret" \
  -d "username=dev-user" \
  -d "password=dev-password" \
  -d "grant_type=password" \
  "https://$KEYCLOAK_ROUTE/realms/workshop/protocol/openid-connect/token" \
  | python3 -m json.tool | grep '"access_token"' | cut -d'"' -f4)

echo "Route connecting to: https://$KEYCLOAK_ROUTE/realms/workshop/protocol/openid-connect/token ..."
echo "Dev token obtained: ${DEV_TOKEN:0:50}..."
echo "Full dev token:"
echo ${DEV_TOKEN}

# ops toekten test
OPS_TOKEN=$(curl -sk \
  -d "client_id=bookinfo" \
  -d "client_secret=bookinfo-client-secret" \
  -d "username=ops-user" \
  -d "password=ops-password" \
  -d "grant_type=password" \
  "https://$KEYCLOAK_ROUTE/realms/workshop/protocol/openid-connect/token" \
  | python3 -m json.tool | grep '"access_token"' | cut -d'"' -f4)

echo "Route connecting to: https://$KEYCLOAK_ROUTE/realms/workshop/protocol/openid-connect/token ..." 
echo "Ops token obtained: ${OPS_TOKEN:0:50}..."
echo "Full ops token:"
echo ${OPS_TOKEN}

# TODO: change this to qewruy bookinfo
BOOKINFO_URL="https://bookinfo.apps.snoaxolab.axodevelopment.dev/productpage"

# test 1- dev gets 200
echo ""
echo "=== Testing dev-user (expect 200) ==="
curl -sk -o /dev/null -w "HTTP Status: %{http_code}\n" \
  -H "Authorization: Bearer $DEV_TOKEN" \
  "$BOOKINFO_URL"

# test 2 - ops gets 403
echo ""
echo "=== Testing ops-user (expect 403) ==="
curl -sk -o /dev/null -w "HTTP Status: %{http_code}\n" \
  -H "Authorization: Bearer $OPS_TOKEN" \
  "$BOOKINFO_URL"

# test 3 - default no token
echo ""
echo "=== Testing no token (expect 401/403) ==="
curl -sk -o /dev/null -w "HTTP Status: %{http_code}\n" \
  "$BOOKINFO_URL"

# decode the claims
echo ""
echo "=== Dev token claims ==="
echo $DEV_TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool | \
  grep -E '"groups|realm_access|sub|exp|iss"'
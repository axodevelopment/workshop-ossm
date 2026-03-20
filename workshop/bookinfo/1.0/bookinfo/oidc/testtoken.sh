KEYCLOAK_ROUTE=$(oc get route -l app=keycloak -n keycloak -o jsonpath='{.items[0].spec.host}')

DEV_TOKEN=$(curl -sk \
  -d "client_id=bookinfo" \
  -d "client_secret=bookinfo-client-secret" \
  -d "username=dev-user" \
  -d "password=dev-password" \
  -d "grant_type=password" \
  "https://$KEYCLOAK_ROUTE/realms/workshop/protocol/openid-connect/token" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "Token: ${DEV_TOKEN:0:50}"

echo echo "Dev token obtained: "
echo $DEV_TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool | grep -E "iss|groups|aud"

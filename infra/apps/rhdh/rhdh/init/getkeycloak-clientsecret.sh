EYCLOAK_URL=https://keycloak.apps.snoaxolab.axodevelopment.dev
michwils@michwils-thinkpadp1gen3:~/repos/axodevelopment/workshop-osm/workshop-ossm$ ADMIN_PASS=$(oc get secret keycloak-initial-admin -n keycloak \
  -o jsonpath='{.data.password}' | base64 -d)
michwils@michwils-thinkpadp1gen3:~/repos/axodevelopment/workshop-osm/workshop-ossm$ TOKEN=$(curl -sk -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&grant_type=password&username=temp-admin&password=${ADMIN_PASS}" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
michwils@michwils-thinkpadp1gen3:~/repos/axodevelopment/workshop-osm/workshop-ossm$ echo "${KEYCLOAK_URL} - ${ADMIN_PASS} - ${TOKEN}
> ^C
michwils@michwils-thinkpadp1gen3:~/repos/axodevelopment/workshop-osm/workshop-ossm$ echo "${KEYCLOAK_URL} - ${ADMIN_PASS} - ${TOKEN}"
https://keycloak.apps.snoaxolab.axodevelopment.dev - 0b7e7a8ba9514ed7a0d22ee4f04ec216 - eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI1c3p4Zm1INGp1eUc3bjRjcnRlRDh6VHYyVkp0Tkw1TDNqc2dPNVVpajk4In0.eyJleHAiOjE3NzQ0MTE3MjEsImlhdCI6MTc3NDQxMTY2MSwianRpIjoib25sdHJvOjI5Zjc3Y2EyLWZhOGYtYmUyMC1iYmQ2LTZkMzIyYmFjNTBkMCIsImlzcyI6Imh0dHBzOi8va2V5Y2xvYWsuYXBwcy5zbm9heG9sYWIuYXhvZGV2ZWxvcG1lbnQuZGV2L3JlYWxtcy9tYXN0ZXIiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJhZG1pbi1jbGkiLCJzaWQiOiI5MTE0MWMyNi05NTk4LWFhMGUtMWQwMy03M2M1ZjhjZWEwNGYiLCJzY29wZSI6ImVtYWlsIHByb2ZpbGUifQ.s8KTxIHrc-DWj8vbJrLY3t3NSmY-JiAPkvsado1qbvz5XIBxqobpbl29A0gz5iGN3qKMFVruXkj5SyfHsrfp1IINccE7wCWQTnHbmxxeaY7WGQYiB9CGAnzTjNXeoSZZ-MTFVASQ9eWeKd7QlGK3Rg1kXRN5Gp5Oi0Rx6g3dzmJX2F1Yi1D5VCX5LuruZ2lJsKDDc_1SUfTiBZWFGej8OR9nWkjGdHAJYAVCmZ5JDu6y1eQK1cQDfY7Y2K0JPqHO1u13tX-vR1z72nGtFj2Ei2Zd-S9CXDtiWkYEIS6zysfCvsRdOT2d4PhUosOZu4b8lko4oPkxWKQmKc8sgeos4Q
michwils@michwils-thinkpadp1gen3:~/repos/axodevelopment/workshop-osm/workshop-ossm$ CLIENT_ID=$(curl -sk \
  "${KEYCLOAK_URL}/admin/realms/rhdh/clients?clientId=rhdh" \
  -H "Authorization: Bearer ${TOKEN}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")

echo "rhdh client ID: ${CLIENT_ID}"
rhdh client ID: 1780aee4-798d-4919-9690-1b53ebea9542


---

TOKEN=$(curl -sk -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&grant_type=password&username=temp-admin&password=${ADMIN_PASS}" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

curl -sk -X GET \
  "${KEYCLOAK_URL}/admin/realms/rhdh/clients/${CLIENT_ID}/client-secret" \
  -H "Authorization: Bearer ${TOKEN}"
{"type":"secret","value":"wG03JcQaSP78in8riVrrJNq1Uyo8SbvT"}
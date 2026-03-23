# tasks to be done before syncing

# 1. Real PostgreSQL secret -> gitea/security/gitea-postgres-secret.yaml
oc create secret generic gitea-postgres-secret \
  --from-literal=POSTGRES_USER=gitea \
  --from-literal=POSTGRES_PASSWORD=<strong-password> \
  --from-literal=POSTGRES_DB=gitea \
  -n gitea

# 2. Admin init secret -> gitea/security/secret-admin.yaml
oc create secret generic gitea-admin-secret \
  --from-literal=GITEA_ADMIN_USER=gitea-admin \
  --from-literal=GITEA_ADMIN_PASSWORD=<strong-password> \
  --from-literal=GITEA_ADMIN_EMAIL=admin@example.com \
  -n gitea

# 3. Generate and patch secrets into configmap app.ini before committing
SECRET_KEY=$(openssl rand -hex 32)
INTERNAL_TOKEN=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 32)
# Substitute __GITEA_SECRET_KEY__, __GITEA_INTERNAL_TOKEN__, __GITEA_JWT_SECRET__
# in gitea/configmap.yaml with the generated values before committing
# (or move them to a Secret + env override like the DB password)




# tasks to be done after sync

After the init job completes, grab the token from the job logs:
```
oc logs -n gitea job/gitea-admin-init | grep -A5 "rhdh-catalog-token"
```

Then patch the RHDH secret with the real token value:
```
oc patch secret my-rhdh-secrets -n rhdh \
  --type=merge \
  -p '{"stringData": {"GITEA_TOKEN": "<token-from-job-log>"}}'
```

And restart RHDH to pick it up:
```
oc rollout restart deployment/backstage-rhdh -n rhdh
```



 Get admin token
KEYCLOAK_URL=https://keycloak.apps.snoaxolab.axodevelopment.dev
ADMIN_SECRET=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d)
TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&grant_type=password&username=admin&password=${ADMIN_SECRET}" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# Delete the realm
curl -s -X DELETE "${KEYCLOAK_URL}/admin/realms/rhdh" \
  -H "Authorization: Bearer ${TOKEN}"

# Delete the CR and re-apply
oc delete keycloakrealmimport rhdh-realm -n keycloak
oc apply -n keycloak -f rhdh/keycloak/realm-rhdh.yaml
```

### Step 4 — Watch ArgoCD sync

```bash
# Watch Gitea come up
oc get pods -n gitea -w

# Watch RHDH operator install
oc get csv -n rhdh-operator -w

# Watch RHDH workloads
oc get pods -n rhdh -w

# Watch the Backstage CR reconcile
oc get backstage rhdh -n rhdh -w
```

### Step 5 — Grab the Gitea token from the init job logs

The init job runs as a PostSync hook after Gitea is healthy. You have 10 minutes.

```bash
oc logs -n gitea job/gitea-admin-init -f
```

Look for the block:
```
================================================================
  TOKEN CREATED SUCCESSFULLY — COPY THIS VALUE NOW
  GITEA_TOKEN=<your-token-here>
  ...
================================================================
```

### Step 6 — Patch the RHDH secret with the Gitea token

```bash
oc patch secret my-rhdh-secrets -n rhdh \
  --type=merge \
  -p '{"stringData":{"GITEA_TOKEN":"<token-from-job-log>"}}'

oc rollout restart deployment/backstage-rhdh -n rhdh
```

### Step 7 — Verify RHDH is up

```bash
# Get the route
oc get route -n rhdh

# Should be: https://backstage-rhdh-rhdh.apps.snoaxolab.axodevelopment.dev
# Log in with: rhdh-admin / CHANGEME-rhdh-admin-password (forced change on first login)
```

---

## CHANGEME Values Reference

Every `CHANGEME-*` value in these files is intentionally left as a placeholder.
Replace before real use. For workshop purposes they are safe to commit as-is.

| File | Key | Notes |
|------|-----|-------|
| `rhdh/redis/secret.yaml` | `REDIS_PASSWORD` | Must match `rhdh/secrets/my-rhdh-secrets.yaml` |
| `rhdh/postgres/secret.yaml` | `POSTGRES_PASSWORD` | Must match `rhdh/secrets/my-rhdh-secrets.yaml` |
| `rhdh/secrets/my-rhdh-secrets.yaml` | `KEYCLOAK_CLIENT_SECRET` | Must match `rhdh/keycloak/realm-rhdh.yaml` clients[0].secret |
| `rhdh/secrets/my-rhdh-secrets.yaml` | `GITEA_TOKEN` | Patch in after init job — see Step 6 |
| `rhdh/secrets/my-rhdh-secrets.yaml` | `BASE64_EMBEDDED_FULL_LOGO` | `echo "data:image/svg+xml;base64,$(base64 -i logo.svg)"` |
| `rhdh/keycloak/realm-rhdh.yaml` | `secret` | Must match `KEYCLOAK_CLIENT_SECRET` above |
| `rhdh/keycloak/realm-rhdh.yaml` | `CHANGEME-rhdh-admin-password` | First-login Keycloak admin password |
| `gitea/postgres/secret.yaml` | `POSTGRES_PASSWORD` | Gitea DB password |
| `gitea/gitea/secret-admin.yaml` | `GITEA_ADMIN_PASSWORD` | Gitea web admin password |
| `gitea/gitea/secret-app.yaml` | `SECRET_KEY` | `openssl rand -hex 32` |
| `gitea/gitea/secret-app.yaml` | `INTERNAL_TOKEN` | `openssl rand -hex 32` |
| `gitea/gitea/secret-app.yaml` | `JWT_SECRET` | `openssl rand -hex 32` |

---

###  gitea pvc

oc scale deployment gitea -n gitea --replicas=0
oc delete pvc gitea-data -n gitea

then refresh

May need to routinely delete pvc until i get this stabalized


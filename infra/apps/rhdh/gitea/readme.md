# Gitea setup tasks

Gitea Bootstrap
Step 1 — Admin user creation

Where: infra/apps/gitea/init/job-admin-init.yaml
Status: In job via oc exec su-exec git gitea admin user create
Note: Handles "already exists" gracefully

Step 2 — Workshop org creation

Where: infra/apps/gitea/init/job-admin-init.yaml
Status: In job via Gitea API POST /api/v1/orgs

Step 3 — RHDH catalog token creation

Where: infra/apps/gitea/init/job-admin-init.yaml
Status: In job via Gitea API POST /api/v1/users/.../tokens with scopes

Step 4 — Workshop/catalog repo creation

Where: infra/apps/gitea/init/job-admin-init.yaml
Status: In job via Gitea API POST /api/v1/orgs/workshop/repos

Step 5 — Seed catalog-info.yaml into the repo

Where: infra/apps/gitea/init/job-admin-init.yaml
Status: Needs to be added to job (we did it manually via Gitea UI this session)
Action: Add the base64 file creation step to the job


RHDH ← twftea Token Handoff
Step 6 — Patch GITEA_TOKEN into rhdh-secrets

Where: Manual step / future Ansible
Status: Manual — done with oc patch secret rhdh-secrets
Action: This is the one step with no clean GitOps solution yet. The token is printed by the init job logs. You copy it and patch manually. Future automation target.

Step 7 — Restart RHDH after token patch

Where: Manual
Status: Manual — oc rollout restart deployment/backstage-rhdh -n rhdh
Action: Same as above — part of the future Ansible wrapper


PostgreSQL Bootstrap
Step 8 — Grant CREATEDB to backstage user

Where: infra/apps/rhdh/postgres/job-grant-createdb.yaml
Status: In job — PostSync hook, runs after PostgreSQL is ready
Note: Uses POSTGRES_ADMIN_PASSWORD from rhdh-secrets to connect as postgres superuser


Keycloak
Step 9 — Create rhdh realm, client, users, groups

Where: infra/apps/rhdh/rhdh/keycloakrealm.yaml
Status: Partially manual — applied with oc apply -n keycloak -f ...
Note: KeycloakRealmImport is one-shot. To re-import you must delete the realm via API first, then delete and recreate the CR. Not managed by the main ArgoCD app because it targets the keycloak namespace.

Step 10 — Regenerate Keycloak client secret and sync to rhdh-secrets

Where: Manual — done via Keycloak Admin UI
Status: Manual — go to Keycloak → rhdh realm → Clients → rhdh → Credentials → Regenerate, then update rhdh-secrets.yaml and the realm YAML with matching value
Note: This is needed because KeycloakRealmImport sometimes ignores the secret: field and generates its own


YAML Files That Need Updates
infra/apps/gitea/init/job-admin-init.yaml



infra/apps/rhdh/rhdh/dynamic-plugins-rhdh.yaml

Add Keycloak catalog provider plugin:

yaml      - package: './dynamic-plugins/dist/backstage-community-plugin-catalog-backend-module-keycloak-dynamic'
        disabled: false
infra/apps/rhdh/security/rhdh-secrets.yaml

Add missing keys:

yaml  KEYCLOAK_BASE_URL: "https://keycloak.apps.snoaxolab.axodevelopment.dev/realms/rhdh"
  KEYCLOAK_REALM: "rhdh"
  KEYCLOAK_LOGIN_REALM: "rhdh"
  SESSION_SECRET: "123456-session-secret-change-this-to-something-long"
  GITEA_TOKEN: "cce43b068e4290bf0cba487964876ce12b118a12"
```

**`infra/apps/rhdh/rhdh/rhdh-app-config.yaml`**
- Already updated with `keycloakOrg` provider block
- Already updated with `SESSION_SECRET`
- Already updated with `GITEA_HOST`

---

## TODO: possible Runbook orderfor a Fresh Cluster
```
1.  ArgoCD syncs everything via app-of-apps
2.  postgres/job-grant-createdb runs (PostSync) → backstage gets CREATEDB
3.  gitea/init/job-admin-init runs (PostSync) →
      a. admin user bootstrapped via CLI
      b. workshop org created
      c. token created + printed to logs
      d. workshop/catalog repo created
      e. catalog-info.yaml seeded        ← needs to be added to job
4.  MANUAL: copy GITEA_TOKEN from job logs
5.  MANUAL: oc patch secret rhdh-secrets with GITEA_TOKEN
6.  MANUAL: oc rollout restart deployment/backstage-rhdh
7.  MANUAL: apply keycloakrealm.yaml in keycloak namespace
8.  MANUAL: verify/regenerate Keycloak client secret, update rhdh-secrets.yaml
9.  Keycloak catalog provider syncs users on RHDH startup (15s delay)
10. Login with rhdh-admin works
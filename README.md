# workshop-ossm

# TODO: Current needs.


Test GITEA admin init
Integrate RHDB dependencies Postgres
Integrate RHDB dependencies Redis
Integrate RHDB dep gitea
KeycloakRealmImport should be deleted after they are first ran per docs
Keycloak service monitor setup
KubeletConfig to increase pod limit to 500 (currently hitting 250 limit)
Scope down otel-collector and kiali cluster-admin to minimal RBAC
Replace inline jwks with proper CA trust for jwksUri
MinIO bucket creation Job reliability
Tempo gossip ring issues when in ambient mesh

# pre reqs

~/workshop-ossm/argocd/projects$ oc apply -f .


# Current order of things.

step 1

1. Create namespaces: rhdh, rhdh-operator, gitea, keycloak
2. Create OperatorGroup for rhdh-operator (AllNamespaces — OwnNamespace unsupported)
3. Install RHDH operator via Subscription (watches all namespaces)
4. Verify operator pod running in rhdh-operator namespace

2 postgerss

1. Create rhdh-secrets containing:
   - POSTGRES_USER
   - POSTGRES_PASSWORD
   - POSTGRES_ADMIN_PASSWORD
   - POSTGRES_HOST
   - POSTGRES_PORT
   - REDIS_PASSWORD
   - SESSION_SECRET
   - KEYCLOAK_CLIENT_ID
   - KEYCLOAK_CLIENT_SECRET
   - KEYCLOAK_BASE_URL
   - KEYCLOAK_REALM
   - KEYCLOAK_LOGIN_REALM
   - GITEA_TOKEN        (placeholder — will be patched later)
   - GITEA_HOST
   - GITEA_BASE_URL
   - NODE_TLS_REJECT_UNAUTHORIZED=0  (dev only)

2. Deploy PostgreSQL StatefulSet referencing rhdh-secrets
3. Verify PostgreSQL pod running and accepting connections
4. Run job-grant-createdb (PostSync hook):
   - Connects as postgres admin
   - Grants CREATEDB to backstage user
   - Verify job completes successfully


step 3 redis

1. Deploy Redis using REDIS_PASSWORD from rhdh-secrets
2. Verify Redis pod running


Step 4 - Gitea

1. Create gitea namespace secrets:
   - gitea-admin-secret:
     GITEA_ADMIN_USER
     GITEA_ADMIN_PASSWORD
     GITEA_ADMIN_EMAIL
   - gitea-postgres-secret:
     POSTGRES_USER
     POSTGRES_PASSWORD
     POSTGRES_HOST
     POSTGRES_PORT
     POSTGRES_DB

2. Create gitea ServiceAccount + ClusterRoleBinding (anyuid SCC)
3. Create gitea-init-sa ServiceAccount + Role + RoleBinding (pod exec permissions)
4. Deploy PostgreSQL for Gitea
5. Deploy Gitea:
   - Empty container securityContext {}
   - fsGroup: 1000 at pod level
   - All config via GITEA__section__key env vars (no app.ini mount)
   - Gitea binary refuses to run as root — su-exec git handles this
6. Verify Gitea pod running and /api/healthz returns 200

7. Run gitea-admin-init job (PostSync hook):
   a. Bootstraps admin user via: oc exec su-exec git gitea admin user create
   b. Creates 'workshop' organisation
   c. Creates 'rhdh-catalog-token' with scopes: read:repository, read:user, read:organization
   d. Creates 'workshop/catalog' repo
   e. Seeds catalog-info.yaml into repo

8. MANUAL: Copy GITEA_TOKEN from job logs
9. MANUAL: oc patch secret rhdh-secrets -n rhdh with the token value
10. MANUAL: Create or update catalog-info.yaml in workshop/catalog repo
    (if not seeded by job) — minimum content is a Location kind pointing to catalog targets


Step 5 - Keycloak

1. Apply KeycloakRealmImport CR in keycloak namespace
   CRITICAL settings in the CR:
   - serviceAccountsEnabled: true   ← must be true or catalog sync silently returns 0 users
   - standardFlowEnabled: true
   - directAccessGrantsEnabled: false
   - publicClient: false
   - secret: <KEYCLOAK_CLIENT_SECRET matching rhdh-secrets>

2. Wait for KeycloakRealmImport status to show Done
   NOTE: If realm already exists, import is skipped — must delete realm via API first

3. Verify in Keycloak UI that realm 'rhdh' exists with client 'rhdh'

4. MANUAL: Keycloak UI → realm rhdh → Clients → rhdh → Settings tab
   - Confirm Service accounts roles toggle is ON
   - If not, enable it and Save

5. MANUAL: Keycloak UI → Clients → rhdh → Service accounts roles tab
   - Click Assign role
   - Filter by: realm-management client
   - Assign: view-users
   NOTE: This cannot be done via the KeycloakRealmImport CR

6. Verify in Keycloak UI → Clients → rhdh → Service accounts roles:
   - view-users from realm-management is listed

7. Verify the following exist in the rhdh realm:
   Realm roles:
   - rhdh-admin
   - rhdh-user
   Groups:
   - rhdh-admins  (has rhdh-admin realm role)
   - rhdh-users   (has rhdh-user realm role)
   Users:
   - rhdh-admin (email: rhdh-admin@example.com, in group: rhdh-admins, temporary: false)


Step 6 - RHDH

1. Verify rhdh-secrets has all required keys (see Phase 2 list)
   KEYCLOAK_BASE_URL must be server root: https://keycloak.apps.xxx.xxx
   NOT: https://keycloak.apps.xxx.xxx/realms/rhdh

2. Apply rhdh-app-config ConfigMap with:
   - keycloakOrg catalog provider (baseUrl = server root, realm and loginRealm separate)
   - OIDC auth provider (metadataUrl = ${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration)
   - Gitea integration (host, username, password/token)
   - Catalog location pointing to Gitea workshop/catalog repo
   - RBAC admin: user:default/rhdh-admin

3. Apply dynamic-plugins ConfigMap with at minimum:
   - backstage-community-plugin-catalog-backend-module-keycloak-dynamic (local path, disabled: false)
   - backstage-community-plugin-rbac (OCI ref, disabled: false)
   - backstage-plugin-auth-backend-module-oidc-provider (OCI ref, disabled: false)
   - backstage-plugin-techdocs + backend (OCI refs or local, disabled: false)
   - backstage-plugin-scaffolder-backend-module-gitea (OCI ref, disabled: false)

4. Apply Backstage CR (v1alpha3):
   - enableLocalDb: false
   - refs rhdh-secrets and rhdh-app-config

5. Wait for RHDH pod to reach Running state
6. Watch logs for Keycloak sync (appears ~15s after startup):
   "Read N Keycloak users and N Keycloak groups... Committing..."
   "Committed N Keycloak users and N Keycloak groups"

7. Verify catalog has users:
   curl .../api/catalog/entities?filter=kind=User | check count > 0


Step 7 - Things to verify

1. Navigate to https://backstage-rhdh-rhdh.apps.xxx.xxx
2. Sign in using OIDC button should appear (no Guest login in production mode)
3. Login with rhdh-admin / ChangeMe123!
4. Verify RBAC admin access (Administration menu visible)
5. Verify Catalog shows at least the workshop-catalog Location entity
6. Verify Gitea integration (try creating a component via scaffolder)


Issues - Things i need to fix

KEYCLOAK_BASE_URL = server root only (keycloakOrg appends realm itself)
serviceAccountsEnabled: true on rhdh Keycloak client
view-users role assigned to service account (manual step every realm re-import)
KeycloakRealmImport is one-shot — delete realm via API before re-importing
Gitea binary refuses root — all exec commands need: su-exec git gitea ...
Gitea token creation requires explicit scopes in 1.22+
RHDH operator requires AllNamespaces OperatorGroup (OwnNamespace not supported)
WaitForFirstConsumer storage: PVC must be same sync-wave as Deployment
NODE_TLS_REJECT_UNAUTHORIZED=0 required for self-signed OCP certs (dev only)
GITEA_TOKEN handoff is manual until Ansible automation is built

TODO: more todo

1. Read GITEA_TOKEN from job logs
2. Patch rhdh-secrets with token
3. Restart RHDH deployment
4. Assign view-users to Keycloak service account via API
5. Verify Keycloak sync committed users
6. Get rid of keycloakrealm imports they are the bane of my existance
7. Smoke test login

### notes

for subs

oc get packagemanifest -n openshift-marketplace | grep -iE "sail|service-mesh|kiali|opentelemetry"
opentelemetry-product                                Red Hat Operators     34d
sailoperator                                         Community Operators   34d
opentelemetry-operator                               Community Operators   34d
kiali-ossm                                           Red Hat Operators     34d

oc get packagemanifest servicemeshoperator3 -n openshift-marketplace -o jsonpath='{range .status.channels[*]}{.name}{"\t"}{end}{"\n"}'
candidates	stable	stable-3.0	stable-3.1	stable-3.2	


oc get packagemanifest servicemeshoperator3 -n openshift-marketplace -o jsonpath='{range .status.channels[*]}{.name}{"\t"}{.currentCSV}{"\n"}{end}'
candidates	servicemeshoperator3.v3.0.0-tp.2
stable	servicemeshoperator3.v3.2.2
stable-3.0	servicemeshoperator3.v3.0.8
stable-3.1	servicemeshoperator3.v3.1.5
stable-3.2	servicemeshoperator3.v3.2.2

### 
# minio SETUP

oc port-forward svc/minio 9000:9000 -n tempo &
sleep 2

curl -sL https://dl.min.io/client/mc/release/linux-amd64/mc -o /tmp/mc
chmod +x /tmp/mc

/tmp/mc alias set minio http://localhost:9000 tempo tempo123
/tmp/mc mb minio/tempo
/tmp/mc ls minio

kill %1



# debugging httproute


## check httproute status
oc get httproute -n bookinfo
oc get httproute bookinfo-ingress -n bookinfo -o jsonpath='{.status}' | python3 -m json.tool

## check gateway programmed status again
oc get gateway bookinfo-gw -n bookinfo -o jsonpath='{.status}' | python3 -m json.tool | grep -A3 "message\|reason\|type"

## check ingress gateway logs
oc logs -n bookinfo bookinfo-gw-istio-7bb5fdc9f7-bsfwd | tail -20

## exec to get config_dump from pilot

oc exec -n bookinfo bookinfo-gw-istio-7bb5fdc9f7-bsfwd \
  -c istio-proxy -- pilot-agent request GET config_dump | \
  python3 -m json.tool | grep -A5 "productpage\|bookinfo"


## config_dump ztunnel

ZTUNNEL=$(oc get pods -n ztunnel -l app=ztunnel -o jsonpath='{.items[0].metadata.name}')

oc port-forward -n ztunnel $ZTUNNEL 15000:15000 &
sleep 2

curl -s localhost:15000/config_dump | python3 -m json.tool | \
  grep -E "bookinfo|waypoint|HBONE" | head -30

kill %1

## check paths in httproute
oc get httproute bookinfo-ingress -n bookinfo \
  -o jsonpath='{.spec.rules[0].matches}' | python3 -m json.tool

# get temp tracing details

oc get routes -n tempo
oc get svc -n tempo | grep gateway


# ztuennel and otel iptable mapping issue

oc delete pod -n istio-system -l app.kubernetes.io/name=otel-collector

OTEL_POD=$(oc get pods -n istio-system -l app.kubernetes.io/name=otel-collector \
  -o jsonpath='{.items[0].metadata.name}')

oc get pod -n istio-system $OTEL_POD \
  -o jsonpath='{.metadata.annotations}' | python3 -m json.tool

oc exec -n istio-system $OTEL_POD -- iptables-save 2>/dev/null | grep -E "ISTIO|15008|4317" | head -20
{
    "ambient.istio.io/redirection": "disabled",
    "argocd.argoproj.io/tracking-id": "tempo:opentelemetry.io/OpenTelemetryCollector:istio-system/otel",
    "k8s.ovn.org/pod-networks": "{\"default\":{\"ip_addresses\":[\"10.128.0.180/23\"],\"mac_address\":\"0a:58:0a:80:00:b4\",\"gateway_ips\":[\"10.128.0.1\"],\"routes\":[{\"dest\":\"10.128.0.0/14\",\"nextHop\":\"10.128.0.1\"},{\"dest\":\"172.30.0.0/16\",\"nextHop\":\"10.128.0.1\"},{\"dest\":\"169.254.0.5/32\",\"nextHop\":\"10.128.0.1\"},{\"dest\":\"100.64.0.0/16\",\"nextHop\":\"10.128.0.1\"}],\"ip_address\":\"10.128.0.180/23\",\"gateway_ip\":\"10.128.0.1\",\"role\":\"primary\"}}",
    "k8s.v1.cni.cncf.io/network-status": "[{\n    \"name\": \"ovn-kubernetes\",\n    \"interface\": \"eth0\",\n    \"ips\": [\n        \"10.128.0.180\"\n    ],\n    \"mac\": \"0a:58:0a:80:00:b4\",\n    \"default\": true,\n    \"dns\": {}\n}]",
    "kubectl.kubernetes.io/restartedAt": "2026-03-17T01:46:25-04:00",
    "openshift.io/scc": "restricted-v2",
    "opentelemetry-operator-config/sha256": "53d80336c6929c5bc2ad6c260f3850a56aef51cc2e01ebed900ba85877adae10",
    "prometheus.io/path": "/metrics",
    "prometheus.io/port": "8888",
    "prometheus.io/scrape": "true",
    "seccomp.security.alpha.kubernetes.io/pod": "runtime/default",
    "security.openshift.io/validated-scc-subject-type": "user"

}

oc get networkpolicy tempo-tempo-distributor -n tempo -o yaml | grep -A20 "ingress"
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/component: gateway
          app.kubernetes.io/instance: tempo
          app.kubernetes.io/managed-by: tempo-operator
          app.kubernetes.io/name: tempo
    ports:
    - port: 4317
      protocol: TCP
    - port: 4318
      protocol: TCP
  podSelector:
    matchLabels:
      app.kubernetes.io/component: distributor
      app.kubernetes.io/instance: tempo
      app.kubernetes.io/managed-by: tempo-operator
      app.kubernetes.io/name: tempo
  policyTypes:
  - Egress


networkPolicy is causing issue i'll disable that.

will look at this in the future

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-otel-collector
  namespace: tempo
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: distributor
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: istio-system
    ports:
    - port: 4317
      protocol: TCP
```


### cluster admin to 

oc adm policy add-cluster-role-to-user cluster-admin \
  -z kiali-service-account \
  -n istio-system

oc adm policy add-role-to-user edit $(oc whoami) \
  -n tempo \
  --role-namespace=tempo



# keycloak issues with keycloakrealmimport
# ref -> https://www.keycloak.org/operator/realm-import

oc get keycloakrealmimport workshop-realm -n keycloak -o jsonpath='{.status}' | python3 -m json.tool

operator logs

oc logs -n keycloak -l name=rhbk-operator --tail=30 | grep -iE "error|warn|import|realm|workshop"

adding a db postgres helped but also need to clear cache for the UI to see changes


# authorization policies

jwks


# testing jwt

fetch("https://keycloak.apps.snoaxolab.axodevelopment.dev/realms/workshop/protocol/openid-connect/token", {
  method: "POST",
  headers: {"Content-Type": "application/x-www-form-urlencoded"},
  body: "client_id=bookinfo&client_secret=bookinfo-client-secret&username=dev-user&password=dev-password&grant_type=password"
})
.then(r => r.json())
.then(d => {
  sessionStorage.setItem("jwt", d.access_token);
  console.log("Token stored:", d.access_token.substring(0,50));
});

this for dev console in firefox

# testing oauth cluster

probably see errors regarding tls

oc logs -n openshift-authentication-operator \
  deployment/authentication-operator --tail=50 | grep -iE "keycloak|error|warn|oidc|provider"

### map ocp ingress to keycloak
### TODO: create ansible task to do this
Map router-ca and trust keycloak-ca

oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ocp-router-ca.crt

oc create configmap keycloak-ca --from-file=ca.crt=/tmp/ocp-router-ca.crt -n openshift-config

be sure to delete keycloakrealmimport to reimport

# auth logs

oc logs -n openshift-authentication \
  $(oc get pods -n openshift-authentication -o jsonpath='{.items[0].metadata.name}') \
  --tail=30 | grep -iE "error|failed|auth|callback|token|invalid"

### DELETE KEYCLOAK WORKSPACE script
# get admin token
KEYCLOAK_ROUTE=$(oc get route -l app=keycloak -n keycloak -o jsonpath='{.items[0].spec.host}')
ADMIN_PASS=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d)
ADMIN_USER=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.username}' | base64 -d)

ADMIN_TOKEN=$(curl -sk \
  -d "client_id=admin-cli" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d "grant_type=password" \
  "https://$KEYCLOAK_ROUTE/realms/master/protocol/openid-connect/token" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "Token: ${ADMIN_TOKEN:0:30}..."

# delete the realm
curl -sk -X DELETE \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "https://$KEYCLOAK_ROUTE/admin/realms/workshop"

echo "Done - HTTP should return empty on success"


oc delete keycloakrealmimport workshop-realm -n keycloak
oc delete job -n keycloak -l app=keycloak 2>/dev/null || true

oc delete identity keycloak:1c97dba0-108a-49fd-bc5d-a0a6093b4a57 2>/dev/null || true
oc delete identity keycloak:d1936ee6-279d-47a4-8887-fb15c7f968c5 2>/dev/null || true
oc delete user dev-user 2>/dev/null || true


### DELETE KEYCLOAK WORKSPACE script

---


removeing /dev to dev and setting groups.config.full.path = false


# DRAFT - Lessons learned so far

openshift-operators already has global-operators OperatorGroup — never add another

OCP monitoring ignores namespaceSelector in PodMonitors — deploy in same namespace as pods

Tempo outside the mesh (no istio labels) — complex gossip breaks with HBONE

otel-collector has ambient.istio.io/redirection: disabled

otel-collector and kiali-service-account both have cluster-admin (TODO: scope down)

RHBK KeycloakRealmImport is one-shot — must delete realm via API to re-import

jwksUri doesn't work with self-signed OCP router cert — using inline jwks

AuthorizationPolicy ALLOW creates implicit deny for non-matching requests

Gateway API HTTPRoute and VirtualService conflict on same service — pick one


# RHDH - Red Hat Developer Hub -> DOCS

We can see plugin names for new oci format

oci://image@sha256!plugin-name

skopeo inspect docker://registry.access.redhat.com/rhdh/plugin-catalog-index@sha256:88c3f42ee9f203784c4a8b364b34ee0099b01ca4596762ccf5933d97f252e3ad | python3 -m json.tool | grep -i "label\|title\|plugin"

# postgres issue

oc exec -n rhdh statefulset/postgresql -- \
  psql -U backstage -d backstage -c "SELECT 1"

oc exec -n rhdh statefulset/postgresql -- \
  psql -U backstage -d backstage -c "\du"
                                   List of roles
 Role name |                         Attributes                         | Member of 
-----------+------------------------------------------------------------+-----------
 backstage |                                                            | {}
 postgres  | Superuser, Create role, Create DB, Replication, Bypass RLS | {}

Forgot admin password...







# KEYCLOAK TOOLING

### delete workshop realm

KEYCLOAK_ROUTE=$(oc get route -l app=keycloak -n keycloak -o jsonpath='{.items[0].spec.host}')
ADMIN_PASS=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d)
ADMIN_USER=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.username}' | base64 -d)

ADMIN_TOKEN=$(curl -sk \
  -d "client_id=admin-cli" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d "grant_type=password" \
  "https://$KEYCLOAK_ROUTE/realms/master/protocol/openid-connect/token" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "Token: ${ADMIN_TOKEN:0:30}..."

# delete the realm
curl -sk -X DELETE \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "https://$KEYCLOAK_ROUTE/admin/realms/workshop"



### delete rhdh realm
KEYCLOAK_ROUTE=$(oc get route -l app=keycloak -n keycloak -o jsonpath='{.items[0].spec.host}')
ADMIN_PASS=$(oc get secret keycloak-initial-admin -n keycloak \
  -o jsonpath='{.data.password}' | base64 -d)

TOKEN=$(curl -s -X POST \
  "${KEYCLOAK_ROUTE}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&grant_type=password&username=admin&password=${ADMIN_PASS}" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# Delete the realm
curl -s -X DELETE "${KEYCLOAK_ROUTE}/admin/realms/rhdh" \
  -H "Authorization: Bearer ${TOKEN}"

# Delete the CR and re-apply
oc delete keycloakrealmimport rhdh-realm -n keycloak
oc apply -f infra/apps/rhdh/rhdh/keycloakrealm.yaml

# gitea create catalog yaml

curl -s -X POST \
  "https://gitea.apps.snoaxolab.axodevelopment.dev/api/v1/repos/workshop/catalog/contents/catalog-info.yaml" \
  -H "Content-Type: application/json" \
  -H "Authorization: token cce43b068e4290bf0cba487964876ce12b118a12" \
  -d "{
    \"message\": \"Add initial catalog-info.yaml\",
    \"content\": \"$(printf 'apiVersion: backstage.io/v1alpha1\nkind: Location\nmetadata:\n  name: workshop-catalog\n  description: Workshop software catalog root\nspec:\n  targets: []\n' | base64 -w 0)\"
  }"


  # RHDH - rhdh-app-config.yaml breakdown

I'll skip things I think are obvious

```
  app-config.yaml: |
    app:
      title: Red Hat Developer Hub — snoaxolab
      baseUrl: https://backstage-rhdh-rhdh.apps.snoaxolab.axodevelopment.dev        # <- match route

    branding:
      fullLogo: ${BASE64_EMBEDDED_FULL_LOGO}
      fullLogoWidth: 110px
      iconLogo: ${BASE64_EMBEDDED_ICON_LOGO}

    backend:
      baseUrl: https://backstage-rhdh-rhdh.apps.snoaxolab.axodevelopment.dev
      cors:
        origin: https://backstage-rhdh-rhdh.apps.snoaxolab.axodevelopment.dev       #<- cors origin setup
      cache:
        store: redis
        connection: redis://:${REDIS_PASSWORD}@redis.rhdh.svc.cluster.local:6379    #<- configure redis for cache
      database:                                                                     #<- configure pg
        client: pg
        connection:
          host: ${POSTGRES_HOST}
          port: ${POSTGRES_PORT}
          user: ${POSTGRES_USER}
          password: ${POSTGRES_PASSWORD}
          database: backstage

    auth:
      environment: production                                                       #<- set to production to skip guest login
      session:
        secret: ${SESSION_SECRET}                                                   #<- openssl rand -hex 32 in rhdh-secrets.yaml
      providers:
        oidc:
          production:
            metadataUrl: "${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration" #<- this seems right but not in docs but normal oidc path
            clientId: ${KEYCLOAK_CLIENT_ID}                                         #<- KEYCLOAK_CLIENT_IDin rhdh-ssecrets AND import spec.realm.clients.clientid
            clientSecret: ${KEYCLOAK_CLIENT_SECRET}                                 #<- pulled from keycloak -> clients -> rhdh -> credentials -> Client Secret
            prompt: auto                                                            #<- keycloak decides if login needs to be shown || none
            dangerouslyAllowSignInWithoutUserInCatalog: true                        #<- supposedly I can login without users provisioned in rhdh but this didn't do anything if i changed it, so im missing something.  Also checking docs it shows under signIn.resolves.dange... so .. maybe
            signIn:
              resolvers:
                - resolver: preferredUsernameMatchingUserEntityName                 #< match entity map, i should switch this to oidcSubClaimMatchingKeycloakUserId instead to do a sub claim but i'll look at that later, but it checks metadata.name
                - resolver: emailMatchingUserEntityProfileEmail
                - resolver: emailLocalPartMatchingUserEntityName

    signInPage: oidc                                                                #<- configure oidc signing>

    integrations:
      gitea:                                                                        #<- currently generating with gitea-admin-init -> rhdh-secrets
        - host: ${GITEA_HOST}
          username: gitea-admin
          password: ${GITEA_TOKEN}                                                  #<- manual process where this gets filled out by the init process>

    catalog:
      rules:
        - allow:                                                                    #< things to be ingested into rhdh>
            - Component
            - System
            - API
            - Resource
            - Location
            - Template
            - User
            - Group
      providers:
        keycloakOrg:
          default:                                                                  #< rhdh-seecrets
            baseUrl: ${KEYCLOAK_BASE_URL}
            clientId: ${KEYCLOAK_CLIENT_ID}
            clientSecret: ${KEYCLOAK_CLIENT_SECRET}
            realm: ${KEYCLOAK_REALM}
            loginRealm: ${KEYCLOAK_LOGIN_REALM}
            userQuerySize: 100
            groupQuerySize: 100
            schedule:
              frequency: { hours: 1 }
              timeout: { minutes: 50 }
              initialDelay: { seconds: 15 }
      locations:
        # Gitea catalog location — repo seeded by gitea/init/job-admin-init.yaml
        # Add additional locations here ...
        - type: url
          target: https://gitea.apps.snoaxolab.axodevelopment.dev/workshop/catalog/raw/branch/main/catalog-info.yaml
          rules:
            - allow:
                - Component
                - System
                - API
                - Resource
                - Location
                - Template
                - User
                - Group

    techdocs:
      builder: local                                                                #< can support external storage>
      generator:
        runIn: local                                                                #< the generator runs in the pod itself
      publisher:
        type: local                                                                 #< Stores generated docs on the local filesystem inside the pod. Lost on pod restart. = production i'll look at s3or  googleGcs, or azureBlobStorag>
      cache:
        ttl: 3600000

    permission:
      enabled: true
      rbac:
        admin:
          users:
            - name: user:default/rhdh-admin
        pluginsWithPermission:
          - catalog
          - scaffolder
          - permission
```


# PRE START config checks

values in `gitea/security/secret-app.yaml` are generated

```
echo "SECRET_KEY: $(openssl rand -hex 32)"
echo "INTERNAL_TOKEN: $(openssl rand -hex 32)"  
echo "JWT_SECRET: $(openssl rand -hex 32)"
```

values in `gitea/security/secret-admin.yaml` are mix

```
GITEA_ADMIN_USER    — hardcoded, "gitea-admin"
GITEA_ADMIN_PASSWORD — SET THIS
GITEA_ADMIN_EMAIL   — update domain to match your cluster
```

probably ok

```
echo "GITEA_ADMIN_PASSWORD: $(openssl rand -base64 20)"
```

values in `` are default to keycloak atm

maybe something like

```
KC_PASS=$(openssl rand -base64 20)
echo "username: $(echo -n 'keycloak' | base64)"
echo "password: $(echo -n ${KC_PASS} | base64)"
```

values for this`rhdh/security/rhdh-secrets.yaml`


| Key | Type | How to set |
|-----|------|------------|
| `REDIS_PASSWORD` | Generate | `openssl rand -base64 20` |
| `POSTGRES_USER` | Fixed | `backstage` |
| `POSTGRES_PASSWORD` | Generate | `openssl rand -base64 20` |
| `POSTGRES_ADMIN_PASSWORD` | Generate | `openssl rand -base64 20` |
| `POSTGRES_HOST` | Fixed | `postgresql` (k8s service name) |
| `POSTGRES_PORT` | Fixed | `5432` |
| `KEYCLOAK_CLIENT_ID` | Fixed | `rhdh` |
| `KEYCLOAK_CLIENT_SECRET` | From Keycloak | Copy from Keycloak UI after realm import |
| `KEYCLOAK_BASE_URL` | From cluster | `https://keycloak.apps.<cluster-domain>` |
| `KEYCLOAK_REALM` | Fixed | `rhdh` |
| `KEYCLOAK_LOGIN_REALM` | Fixed | `rhdh` |
| `SESSION_SECRET` | Generate | `openssl rand -hex 32` |
| `GITEA_TOKEN` | From job | Copy from gitea-admin-init job logs |
| `GITEA_BASE_URL` | From cluster | `https://gitea.apps.<cluster-domain>` |
| `GITEA_HOST` | From cluster | `gitea.apps.<cluster-domain>` |
| `BASE64_EMBEDDED_FULL_LOGO` | From file | `data:image/svg+xml;base64,$(cat logo.svg \| base64 -w 0)` |
| `BASE64_EMBEDDED_ICON_LOGO` | From file | same as above for icon |
| `NODE_TLS_REJECT_UNAUTHORIZED` | Fixed | `0` (dev only) |
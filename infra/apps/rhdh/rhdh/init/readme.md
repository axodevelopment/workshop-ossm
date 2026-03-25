finally fixed the Login

# Keycloak depends
Additional keycloak settings
serviceAccountsEnabled: true is required currently on keycloakrealm.yaml
missing view-users role from realm-management on the service account script here -> keycloak-assign-view-userassignment.sh

# test to see users added from keycloak into rhdh

oc logs -n rhdh   $(oc get pod -n rhdh -l rhdh.redhat.com/app=backstage-rhdh \
    -o jsonpath='{.items[0].metadata.name}')   -c backstage-backend -f 2>&1 | grep -v "rootHttpRouter\|kube-probe\|entities/by-refs"


# gitea Depds

Bootstrap first admin user via CLIoc exec deploy/gitea -- su-exec git gitea admin user create
- in giteea/init/job-admin-init.yaml
- - Creates admin user
- - Creates 'workshop' organisation
- - Creating RHDH catalog token

Take token and patch rhdh-secrets
oc patch secret rhdh-secrets -n rhdh --type=merge -p '{\"stringData\":{\"GITEA_TOKEN\":\"${TOKEN}\"}}'

MAY OR MAY NOT need to run init job again.

# More keycloak

TODO: Replace forsaken keycloakimport,

But import rhdh/keycloakrealm.yaml


1.  ArgoCD syncs everything
2.  postgres/job-grant-createdb runs (PostSync)
3.  gitea/init/job-admin-init runs (PostSync):
      - admin bootstrapped via su-exec CLI
      - workshop org created
      - token created + printed to logs
      - workshop/catalog repo + catalog-info.yaml created  ← needs adding to job
4.  MANUAL: copy GITEA_TOKEN from job logs
5.  MANUAL: oc patch secret rhdh-secrets with GITEA_TOKEN
6.  MANUAL: oc rollout restart deployment/backstage-rhdh
7.  MANUAL: oc apply -n keycloak -f keycloakrealm.yaml
8.  MANUAL: Keycloak UI → rhdh client → Settings → enable Service accounts roles → Save
9.  MANUAL: Keycloak UI → rhdh client → Service accounts roles → Assign view-users from realm-management
10. RHDH Keycloak sync commits users on next startup (15s delay)
11. Login with rhdh-admin / ChangeMe123!
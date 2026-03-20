# workshop-ossm


# pre reqs

~/workshop-ossm/argocd/projects$ oc apply -f .



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
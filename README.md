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


# minio

oc port-forward svc/minio 9000:9000 -n tempo &
sleep 2

# install mc if you don't have it
curl -sL https://dl.min.io/client/mc/release/linux-amd64/mc -o /tmp/mc
chmod +x /tmp/mc

# create the bucket
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

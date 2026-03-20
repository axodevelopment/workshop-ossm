### map ocp ingress to keycloak
### TODO: create ansible task to do this
Map router-ca and trust keycloak-ca

oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ocp-router-ca.crt

oc create configmap keycloak-ca --from-file=ca.crt=/tmp/ocp-router-ca.crt -n openshift-config
# workshop-ossm

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

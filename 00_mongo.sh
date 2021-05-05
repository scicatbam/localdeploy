#!/bin/sh
# Set up and start a mongodb instance in a kubernetes cluster
# USAGE: $0 [bare] [clean]
# 1st arg: 'bare' sets up services in a 'pure' k8s scenario
#          while using minikube is the default
# 2nd arg: 'clean' runs cleanup procedures only, skips starting services again

# get the script directory before creating any files
scriptdir="$(dirname "$(readlink -f "$0")")"
. "$scriptdir/services/deploytools"

NS_FILE="$(find "$scriptdir/namespaces" -iname '*.yaml')"
kubectl create -f $NS_FILE
NS="$(sed -n -e '/^metadata/{:a;n;s/^\s\+name:\s*\(\w\+\)/\1/;p;Ta' -e'}' "$NS_FILE")"
[ -z "$NS" ] && (echo "Could not determine namespace!"; exit 1)

pvcfg="$scriptdir/definitions/mongo_pv_hostpath.yaml"
if [ "$1" = "bare" ]; then
    pvcfg="$scriptdir/definitions/mongo_pv_nfs.yaml"
    echo " -> Using NFS for persistent volumes in 'bare' mode."
    echo "    Please make sure the configured NFS shares can be mounted: '$pvcfg'"
    mpath="$(awk -F':' '/path:/{sub(/^ */,"",$2);print $2}' "$pvcfg")"
    if ! [ -d "$mpath" ]; then
        mkdir -p "$mpath"
        chmod a+w "$mpath"
    fi
fi

# remove the pod
helm del local-mongodb --namespace "$NS"
# reclaim PV
pvname="$(kubectl -n $NS get pv | grep mongo | awk '{print $1}')"
[ -z "$pvname" ] || \
    kubectl patch pv "$pvname" -p '{"spec":{"claimRef":null}}'

if ([ "$1" = "clean" ] || [ "$2" = "clean" ]); then
    # delete old volume first
    echo -n "Waiting for mongodb persistentvolume being removed ... "
    while kubectl -n "$NS" get pv | grep -q mongo; do
        # https://github.com/kubernetes/kubernetes/issues/77258#issuecomment-502209800
        kubectl patch pv $pvname -p '{"metadata":{"finalizers":null}}'
        timeout 6 kubectl delete pv $pvname
    done
    kubectl delete -f "$pvcfg"
    echo "done."
fi

if [ "$1" = "bare" ] && [ "$2" = "clean" ]; then
    # delete the underlying data
    datapath="$(awk -F: '/path/ {sub("^\\s*","",$2); print $2}' "$pvcfg")"
    [ -d "$datapath" ] && rm -R "$datapath/data"
fi

([ "$1" = "clean" ] || [ "$2" = "clean" ]) && exit

kubectl apply -f "$pvcfg"
# reset root password in existing db:
# - create pod with auth disabled, helm arg '--set auth.enabled=false'
# - change pwd of user root in db
# - recreate pod with auth enabled
# - update k8s secret (example pwd 'test'):
#   kubectl -ndev get secret local-mongodb -o json | jq ".data[\"mongodb-root-password\"]=\"$(echo test | base64)\"" | kubectl apply -f -
cmd="helm install local-mongodb bitnami/mongodb --namespace $NS"
echo "$cmd"; eval $cmd

# vim: set ts=4 sw=4 sts=4 tw=0 et:

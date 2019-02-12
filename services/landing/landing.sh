#!/bin/bash

envarray=(dev)

INGRESS_NAME=" "
if [ "$(hostname)" == "kubetest01.dm.esss.dk" ]; then
  envarray=(dmsc)
  INGRESS_NAME="-f ./landingserver/dmsc.yaml"
elif  [ "$(hostname)" == "scicat01.esss.lu.se" ]; then
  envarray=(ess)
  INGRESS_NAME="-f ./landingserver/lund.yaml"
elif  [ "$(hostname)" == "k8-lrg-prod.esss.dk" ]; then
  envarray=(dev)
  INGRESS_NAME="-f ./landingserver/dmscprod.yaml"
else
  envarray=(dev)
  INGRESS_NAME="-f ./landingserver/$(hostname).yaml"
fi

echo $1

export LOCAL_ENV="${envarray[i]}"
echo $LOCAL_ENV
helm del --purge landingserver
cd services/landing/
if [ -d "./component/" ]; then
  cd component
  git pull
else
  git clone https://github.com/garethcmurphy/landingpageserver.git component
  cd component
fi
export FILESERVER_IMAGE_VERSION=$(git rev-parse HEAD)
docker build . -t $5:$FILESERVER_IMAGE_VERSION$LOCAL_ENV
docker push $5:$FILESERVER_IMAGE_VERSION$LOCAL_ENV
echo "Deploying to Kubernetes"
cd ..
pwd
echo helm install landingserver --name landingserver --namespace $LOCAL_ENV --set image.tag=$FILESERVER_IMAGE_VERSION$LOCAL_ENV --set image.repository=$5 ${INGRESS_NAME}
helm install landingserver --name landingserver --namespace $LOCAL_ENV --set image.tag=$FILESERVER_IMAGE_VERSION$LOCAL_ENV --set image.repository=$5 ${INGRESS_NAME}
# envsubst < ../catanie-deployment.yaml | kubectl apply -f - --validate=false


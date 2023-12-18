#!/bin/bash

# Reference: https://github.com/civo/kubernetes-marketplace
# find config params in ./manifest.yaml

export PRD=grsf
export NS=grpl-system
export TESTNS=grpl-test

export CLUSTERDOMAIN=${GRAPPLE_DNS}.grpl.io
export awsregistry=p7h7z5g3


cat <<EOF > ./values-override.yaml
# Default values for grsf-init.

clusterdomain: ${CLUSTERDOMAIN}

config:
  clusterdomain: ${CLUSTERDOMAIN}
  grapiversion: "0.0.1"
  gruimversion: "0.0.1"
  ssl: "false"
  # sslissuer: "letsencrypt-prod-cloud20x"

external-secrets:
  enabled: false

cert-manager:
  enabled: false

crossplane:
  enabled: true
  kubernetes:
    enabled: true
    local:
      enabled: true
  helm:
    enabled: true
    local:
      enabled: true
  civo:
    enabled: true
    apikey: ""
  aws:
    enabled: false

registry:
  enabled: false

ingress:
  enabled: false

EOF



helm_deploy() {
    i=$1

    echo
    echo "------"
    echo "helm upgrade --install ${i} oci://public.ecr.aws/${awsregistry}/${i} ${NAMESPACE} --create-namespace # + values-override.yaml"
    echo "------"
    helm upgrade --install ${i} oci://public.ecr.aws/${awsregistry}/${i} ${NAMESPACE} --create-namespace -f ./values-override.yaml
}

echo "install the metrics server"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo 
echo ----
echo "deploy grsf-init"

helm_deploy grsf-init

echo "wait for cert-manager to be ready"
if helm get -n kube-system notes traefik >/dev/null 2>&1; then 
    CRD=Middleware && echo "wait for ${CRD} to be deployed:" && until kubectl explain ${CRD} >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "${CRD} deployed"
fi
if kubectl get deploy -n grpl-system grsf-init-cert-manager >/dev/null 2>&1; then 
    kubectl wait deployment -n ${NS} grsf-init-cert-manager --for condition=Available=True --timeout=300s
    CRD=ClusterIssuer && echo "wait for ${CRD} to be deployed:" && until kubectl explain ${CRD} >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "${CRD} deployed"
fi

echo "wait for crossplane to be ready"
if kubectl get deploy -n grpl-system crossplane >/dev/null 2>&1; then 
    CRD=Provider && echo "wait for ${CRD} to be deployed:" && until kubectl explain ${CRD} >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "${CRD} deployed"
fi

echo "wait for external-secrets to be ready"
if kubectl get deploy -n grpl-system grsf-init-external-secrets-webhook >/dev/null 2>&1; then 
    CRD=ExternalSecrets && echo "wait for ${CRD} to be deployed:" && until kubectl explain ${CRD} >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "${CRD} deployed"
    echo "wait for external-secrets to be ready"
    kubectl wait deployment -n ${NS} grsf-init-external-secrets-webhook --for condition=Available=True --timeout=300s
fi 


echo 
echo ----
echo "deploy grsf"

helm_deploy grsf

echo "wait for providerconfigs to be ready"
sleep 10
if kubectl get -n ${NS} $(kubectl get deploy -n ${NS} -o name | grep provider-civo) >/dev/null 2>&1; then 
    kubectl wait -n ${NS} provider.pkg.crossplane.io/provider-civo --for condition=Healthy=True --timeout=300s
    echo "wait for provider-civo to be ready"
    CRD=providerconfigs.civo.crossplane.io  && echo "wait for ${CRD} to be deployed:" && until kubectl explain ${CRD} >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "${CRD} deployed"
fi 

for i in $(kubectl get pkg -n ${NS} -o name); do 
    kubectl wait -n ${NS} $i --for condition=Healthy=True --timeout=300s;
done
if kubectl get -n ${NS} $(kubectl get deploy -n ${NS} -o name | grep provider-helm) >/dev/null 2>&1; then 
    CRD=providerconfigs.helm.crossplane.io  && echo "wait for ${CRD} to be deployed:" && until kubectl explain ${CRD} >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "${CRD} deployed"
fi 
if kubectl get -n ${NS} $(kubectl get deploy -n ${NS} -o name | grep provider-kubernetes) >/dev/null 2>&1; then 
    CRD=providerconfigs.kubernetes.crossplane.io  && echo "wait for ${CRD} to be deployed:" && until kubectl explain ${CRD} >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "${CRD} deployed"
fi 


echo 
echo ----
echo "deploy grsf-config"

helm_deploy grsf-config


echo 
echo ----
echo "deploy grsf-integration"

helm_deploy grsf-integration 

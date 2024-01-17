#!/bin/bash

# Reference: https://github.com/civo/kubernetes-marketplace
# find config params in ./manifest.yaml

cat <<EOF > ./values-override.yaml
# Default values for grsf-init.

clusterdomain: ${GRAPPLE_DNS}.grapple-demo.com

# all the following config records need to be available and shall not be removed
config:
  clusterdomain: ${GRAPPLE_DNS}.grapple-demo.com
  grapiversion: "0.0.1"
  gruimversion: "0.0.1"
  ssl: "true"
  sslissuer: "letsencrypt-grapple-demo"
  CIVO_CLUSTER_ID: ${CIVO_CLUSTER_ID}
  CIVO_CLUSTER_NAME: ${CIVO_CLUSTER_NAME}
  CIVO_REGION: ${CIVO_REGION}
  CIVO_EMAIL_ADDRESS: ${CIVO_EMAIL_ADDRESS}
  CIVO_MASTER_IP: ${CIVO_MASTER_IP}
  GRAPPLE_DNS: ${GRAPPLE_DNS}
  GRAPPLE_VERSION: ${VERSION}

external-secrets:
  enabled: true
  installCRDs: true
  namespace: grpl-system

externalsecrets:
  enabled: true
  installCRDs: true
  namespace: grpl-system

cert-manager:
  enabled: true
  installCRDs: true
  namespace: grpl-system

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
    apikey: "myapikey"
  aws:
    enabled: false

registry:
  enabled: false

ingress:
  enabled: false

EOF

helm_deploy() {
    i=$1
    v=${2:=$VERSION}
    if [ "$v" != "" ]; then 
      version="--version ${v}"
    else
      version=""
    fi
    echo
    echo "------"
    echo "helm upgrade --install $i oci://public.ecr.aws/${awsregistry}/$i -n ${NS} ${version} --create-namespace # + values-override.yaml"
    echo "------"
    helm upgrade --install $i oci://public.ecr.aws/${awsregistry}/$i -n ${NS} ${version} --create-namespace -f ./values-override.yaml
}

kubectl run grpl-dns-aws-route53-upsert-${GRAPPLE_DNS} --image=grpl/dns-aws-route53-upsert --env="GRAPPLE_DNS=${GRAPPLE_DNS}" --env="CIVO_MASTER_IP=${CIVO_MASTER_IP}" --restart=Never

echo 
echo ----
echo "deploy grsf-init"

helm_deploy grsf-init 

echo "wait for cert-manager to be ready"
if helm get -n kube-system notes traefik >/dev/null 2>&1; then 
    CRD=Middleware && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi
if kubectl get deploy -n grpl-system grsf-init-cert-manager >/dev/null 2>&1; then 
    kubectl wait deployment -n ${NS} grsf-init-cert-manager --for condition=Available=True --timeout=300s
    CRD=ClusterIssuer && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi

# remove the DNS job again
kubectl delete po grpl-dns-aws-route53-upsert-${GRAPPLE_DNS} 

echo "wait for crossplane to be ready"
if kubectl get deploy -n grpl-system crossplane >/dev/null 2>&1; then 
    CRD=Provider && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi

echo "wait for external-secrets to be ready"
if kubectl get deploy -n grpl-system grsf-init-external-secrets-webhook >/dev/null 2>&1; then 
    CRD=ExternalSecrets && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
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
    CRD=providerconfigs.civo.crossplane.io  && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi 

for i in $(kubectl get pkg -n ${NS} -o name); do 
    kubectl wait -n ${NS} $i --for condition=Healthy=True --timeout=300s;
done
if kubectl get -n ${NS} $(kubectl get deploy -n ${NS} -o name | grep provider-helm) >/dev/null 2>&1; then 
    CRD=providerconfigs.helm.crossplane.io  && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi 
if kubectl get -n ${NS} $(kubectl get deploy -n ${NS} -o name | grep provider-kubernetes) >/dev/null 2>&1; then 
    CRD=providerconfigs.kubernetes.crossplane.io  && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi 


echo 
echo ----
echo "deploy grsf-config"

helm_deploy grsf-config 


echo 
echo ----
echo "deploy grsf-integration"

helm_deploy grsf-integration


echo 
echo ----
echo "enable ssl"
kubectl apply -f ./clusterissuer.yaml


echo 
echo ----
echo "deploy test case"

echo "check all crossplane packages are ready"
for i in $(kubectl get pkg -o name); do kubectl wait --for=condition=Healthy $i; done

echo "check xrds are available"
CRD=grapi && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
CRD=compositegrappleapis && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
CRD=composition/grapi.grsf.grpl.io && echo "wait for $CRD to be deployed:" && until kubectl get $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
CRD=composition/muim.grsf.grpl.io && echo "wait for $CRD to be deployed:" && until kubectl get $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"

helm upgrade --install ${TESTNS} oci://public.ecr.aws/p7h7z5g3/gras-deploy -n ${TESTNS} -f ./test.yaml --create-namespace 

while ! kubectl wait deployment -n ${TESTNS} ${TESTNS}-${TESTNS}-grapi --for condition=Progressing=True 2>/dev/null; do echo -n .; sleep 2; done
sleep 10
kubectl cp -n ${TESTNS} ./db.json $(kubectl get po -n ${TESTNS} -l app.kubernetes.io/name=grapi -o name | sed "s,pod/,,g"):/tmp/db.json -c init-db


TESTNSDB=grpl-db

curl -fsSL https://kubeblocks.io/installer/install_cli.sh | bash
sleep 2
kbcli kubeblocks install --set image.registry="docker.io"

kubectl create ns ${TESTNSDB} 2>/dev/null || true
cat <<EOF | kubectl apply -f -n ${TESTNSDB} -
apiVersion: apps.kubeblocks.io/v1alpha1
kind: Cluster
metadata:
  name: grappledb
spec:
  clusterDefinitionRef: apecloud-mysql
  clusterVersionRef: ac-mysql-8.0.30
  componentSpecs:
  - componentDefRef: mysql
    name: mysql
    replicas: 3
    resources:
      limits:
        cpu: "1"
        memory: 1Gi
      requests:
        cpu: "0.5"
        memory: 500Mi
    volumeClaimTemplates:
    - name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
  terminationPolicy: Delete
EOF

kubectl rollout status -n ${TESTNSDB} --watch --timeout=600s sts grappledb

sleep 5 

helm upgrade --install ${TESTNSDB} oci://public.ecr.aws/p7h7z5g3/gras-deploy -n ${TESTNSDB} -f ./test2.yaml --create-namespace 


#!/bin/bash

NS=grpl-system
TESTNS=grpl-dbfile
TESTNSDB=grpl-db

kubectl delete gras --all -A 2>/dev/null || true
kubectl delete gruim --all -A 2>/dev/null || true
kubectl delete grapi --all -A 2>/dev/null || true

sleep 3

kubectl delete ns $TESTNS 2>/dev/null || true
kubectl delete ns $TESTNSDB 2>/dev/null || true
kubectl delete ns customers 2>/dev/null || true

sleep 3

curl -fsSL https://kubeblocks.io/installer/install_cli.sh | bash
sleep 2

kbcli kubeblocks uninstall --auto-approve=true || true

sleep 3

kubectl delete configurations --all -A 2>/dev/null || true

sleep 3

kubectl delete ns kb-system 2>/dev/null || true

# Uninstall charts
helm_uninstall grsf-monitoring grsf-monitoring 2>/dev/null || true
kubectl delete ns grsf-monitoring 2>/dev/null || true
sleep 3
helm_uninstall grsf-integration 2>/dev/null || true
sleep 3
helm_uninstall grsf-config 2>/dev/null || true
sleep 3
helm_uninstall grsf 2>/dev/null || true
sleep 3
helm_uninstall grsf-init 2>/dev/null || true
sleep 3
kubectl delete ns $NS 2>/dev/null || true


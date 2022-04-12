#!/bin/sh

HW_GO="1.1.1"
# -----------------------------------
echo "===>  Built the images of xApps"

cd ../'xApps of E Release'
git clone "https://gerrit.o-ran-sc.org/r/ric-app/hw-go" -b e-release
cd hw-go
docker build -t nexus3.o-ran-sc.org:10004/o-ran-sc/ric-app-hw-python:${HW_GO} .
cd ..

# -----------------------------------
echo "===>  On-boarding xApps"

export NODE_PORT=$(kubectl get --namespace ricinfra -o jsonpath="{.spec.ports[0].nodePort}" services r4-chartmuseum-chartmuseum)
export NODE_IP=$(kubectl get nodes --namespace ricinfra -o jsonpath="{.items[0].status.addresses[0].address}")
export CHART_REPO_URL=http://$NODE_IP:$NODE_PORT/charts
dms_cli onboard --config_file_path=hw-go/config/config-file.json --shcema_file_path=hw-go/config/schema.json
cd ~

# -----------------------------------
echo "======> Listing the xapp helm chart"
dms_cli get_charts_list

sleep 5

# -----------------------------------
echo "===>  Deploying xApps"
dms_cli install --xapp_chart_name=hw-go --version=1.0.0 --namespace=ricxapp

sleep 30
# -----------------------------------
echo "===>  Checking the pods of xApps"
kubectl get pod -n ricxapp

# -----------------------------------
echo "===>  Check the hw-go xApp endpoints in the routing table"
export Service_rtmgr=$(kubectl get services -n ricplt | grep "\-rtmgr-http" | cut -f1 -d ' ')
export Rtmgr_IP=$(kubectl get svc ${Service_rtmgr} -n ricplt -o yaml | grep clusterIP | awk '{print $2}')

curl -X GET "http://${Rtmgr_IP}:3800/ric/v1/getdebuginfo" -H "accept: application/json" | jq .
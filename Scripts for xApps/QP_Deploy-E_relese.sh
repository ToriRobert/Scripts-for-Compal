#!/bin/sh

QP="0.0.4"
# -----------------------------------
echo "===>  Built the images of xApps"

cd ../'xApps of E Release'/qp
docker build -t nexus3.o-ran-sc.org:10002/o-ran-sc/ric-app-qp:${QP} .

# -----------------------------------
echo "===>  On-boarding xApps"

export NODE_PORT=$(kubectl get --namespace ricinfra -o jsonpath="{.spec.ports[0].nodePort}" services r4-chartmuseum-chartmuseum)
export NODE_IP=$(kubectl get nodes --namespace ricinfra -o jsonpath="{.items[0].status.addresses[0].address}")
export CHART_REPO_URL=http://$NODE_IP:$NODE_PORT/charts
dms_cli onboard --config_file_path=xapp-descriptor/config.json --shcema_file_path=xapp-descriptor/schema.json
cd ~

# -----------------------------------
echo "======> Listing the xapp helm chart"
dms_cli get_charts_list

sleep 5

# -----------------------------------
echo "===>  Deploying xApps"
dms_cli install --xapp_chart_name=qp --version=0.0.4 --namespace=ricxapp

sleep 30
# -----------------------------------
echo "===>  Checking the pods of xApps"
kubectl get pod -n ricxapp

# -----------------------------------
echo "===>  Registering xApps"

export Service_appmgr=$(kubectl get services -n ricplt | grep "\-appmgr-http" | cut -f1 -d ' ')
export Appmgr_IP=$(kubectl get svc ${Service_appmgr} -n ricplt -o yaml | grep clusterIP | awk '{print $2}')

export Service_QP=$(kubectl get services -n ricxapp | grep "\-qp\-" | cut -f1 -d ' ')
export QP_IP=$(kubectl get svc ${Service_QP} -n ricxapp -o yaml | grep clusterIP | awk '{print $2}')

curl -X POST "http://${Appmgr_IP}:8080/ric/v1/register" -H 'accept: application/json' -H 'Content-Type: application/json' -d '{
  "appName": "qp",
  "appVersion": "0.0.4",
  "appInstanceName": "qp",
  "httpEndpoint": "",
  "rmrEndpoint": "${QP_IP}:4560",
  "config": " {\n    \"name\": \"qp\",\n    \"version\": \"0.0.4\",\n    \"containers\": [{\"image\":{\"name\":\"o-ran-sc/ric-app-qp\",\"registry\":\"nexus3.o-ran-sc.org:10002\",\"tag\":\"0.0.4\"},\"name\":\"qp\"}],\n    \"messaging\": {\n        \"ports\": [{\"container\":\"qp\",\"description\":\"rmr route port for qp\",\"name\":\"rmr-route\",\"port\":4561},{\"container\":\"qp\",\"description\":\"rmr receive data port for qp\",\"name\":\"rmr-data\",\"policies\":[],\"port\":4560,\"rxMessages\":[\"TS_UE_LIST\"],\"txMessages\":[\"TS_QOE_PREDICTION\"]}]\n    },\n    \"rmr\": {\n        \"protPort\": \"tcp:4560\",\n        \"maxSize\": 2072,\n        \"numWorkers\": 1,\n        \"txMessages\": [\"TS_QOE_PREDICTION\"],\n        \"rxMessages\": [\"TS_UE_LIST\"],\n        \"policies\": [1]\n    },\n    \"controls\": {\n        \"fileStrorage\": false\n    },\n    \"db\": {\n        \"waitForSdl\": false\n    }\n}\n"}  "
}'

# -----------------------------------
echo "===>  Check the QP xApp endpoints in the routing table"
export Service_rtmgr=$(kubectl get services -n ricplt | grep "\-rtmgr-http" | cut -f1 -d ' ')
export Rtmgr_IP=$(kubectl get svc ${Service_rtmgr} -n ricplt -o yaml | grep clusterIP | awk '{print $2}')

curl -X GET "http://${Rtmgr_IP}:3800/ric/v1/getdebuginfo" -H "accept: application/json" | jq .
#!/bin/sh

TS="1.2.1"
# -----------------------------------
echo "===>  Built the images of xApps"

cd ../'xApps of E Release'/ts
docker build -t nexus3.o-ran-sc.org:10002/o-ran-sc/ric-app-ts:${TS} .

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
dms_cli install --xapp_chart_name=trafficxapp --version=1.2.1 --namespace=ricxapp

sleep 30
# -----------------------------------
echo "===>  Checking the pods of xApps"
kubectl get pod -n ricxapp

# -----------------------------------
echo "===>  Registering xApps"

export Service_appmgr=$(kubectl get services -n ricplt | grep "\-appmgr-http" | cut -f1 -d ' ')
export Appmgr_IP=$(kubectl get svc ${Service_appmgr} -n ricplt -o yaml | grep clusterIP | awk '{print $2}')

export Service_TS=$(kubectl get services -n ricxapp | grep "\-trafficxapp\-" | cut -f1 -d ' ')
export TS_IP=$(kubectl get svc ${Service_TS} -n ricxapp -o yaml | grep clusterIP | awk '{print $2}')

curl -X POST "http://${Appmgr_IP}:8080/ric/v1/register" -H 'accept: application/json' -H 'Content-Type: application/json' -d '{
  "appName": "trafficxapp",
  "appVersion": "1.2.1",
  "appInstanceName": "trafficxapp",
  "httpEndpoint": "",
  "rmrEndpoint": "${TS_IP}:4560",
  "config": " {\n    \"name\": \"trafficxapp\",\n    \"version\": \"1.2.1\",\n    \"containers\": [{\"image\":{\"name\":\"o-ran-sc/ric-app-ts\",\"registry\":\"nexus3.o-ran-sc.org:10002\",\"tag\":\"1.2.1\"},\"name\":\"trafficxapp\"}],\n    \"messaging\": {\n        \"ports\": [{\"container\":\"trafficxapp\",\"description\":\"rmr route port for mc xapp\",\"name\":\"rmr-route\",\"port\":4561},{\"container\":\"trafficxapp\",\"description\":\"rmr receive data port for trafficxapp\",\"name\":\"rmr-data\",\"policies\":[20008],\"port\":4560,\"rxMessages\":[\"TS_QOE_PREDICTION\",\"A1_POLICY_REQ\",\"TS_ANOMALY_UPDATE\"],\"txMessages\":[\"TS_UE_LIST\",\"TS_ANOMALY_ACK\"]}]\n    },\n    \"rmr\": {\n        \"protPort\": \"tcp:4560\",\n        \"maxSize\": 2072,\n        \"numWorkers\": 1,\n        \"txMessages\": [\"TS_UE_LIST\",\"TS_ANOMALY_ACK\"],\n        \"rxMessages\": [\"TS_QOE_PREDICTION\",\"A1_POLICY_REQ\",\"TS_ANOMALY_UPDATE\"],\n        \"policies\": [20008]\n    },\n    \"controls\": {\n        \"ts_control_api\": \"grpc\",\n        \"ts_control_ep\": \"service-ricxapp-rc-grpc-server.ricxapp.svc.cluster.local:7777\"\n    }\n    \n}\n"}  "
}'

# -----------------------------------
echo "===>  Check the TS xApp endpoints in the routing table"
export Service_rtmgr=$(kubectl get services -n ricplt | grep "\-rtmgr-http" | cut -f1 -d ' ')
export Rtmgr_IP=$(kubectl get svc ${Service_rtmgr} -n ricplt -o yaml | grep clusterIP | awk '{print $2}')

curl -X GET "http://${Rtmgr_IP}:3800/ric/v1/getdebuginfo" -H "accept: application/json" | jq .
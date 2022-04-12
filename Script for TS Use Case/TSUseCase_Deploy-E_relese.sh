#!/bin/sh

AD="0.0.2"
RC="1.0.1"
TS="1.2.1"
QP="0.0.4"

# -----------------------------------
echo "===>  Built the images of xApps"

echo "-----------------------------------"
echo "===>  Built the image of AD xApp"

cd ../'xApps of E Release'/ad
docker build -t nexus3.o-ran-sc.org:10002/o-ran-sc/ric-app-ad:${AD} .
cd ..

echo "-----------------------------------"
echo "===>  Built the image of RC xApp"

git clone "https://gerrit.o-ran-sc.org/r/ric-app/rc" -b e-release
cd rc
docker build -t nexus3.o-ran-sc.org:10002/o-ran-sc/ric-app-rc:${RC} .
cd ..

echo "-----------------------------------"
echo "===>  Built the image of TS xApp"

cd ../'xApps of E Release'/ts
docker build -t nexus3.o-ran-sc.org:10002/o-ran-sc/ric-app-ts:${TS} .
cd ..

echo "-----------------------------------"
echo "===>  Built the image of QP xApp"

cd ../'xApps of E Release'/qp
docker build -t nexus3.o-ran-sc.org:10002/o-ran-sc/ric-app-qp:${QP} .
cd ..

# -----------------------------------
echo "===>  On-boarding xApps"
export NODE_PORT=$(kubectl get --namespace ricinfra -o jsonpath="{.spec.ports[0].nodePort}" services r4-chartmuseum-chartmuseum)
export NODE_IP=$(kubectl get nodes --namespace ricinfra -o jsonpath="{.items[0].status.addresses[0].address}")
export CHART_REPO_URL=http://$NODE_IP:$NODE_PORT/charts

echo "-----------------------------------"
echo "===>  On-boarding AD xApp"
dms_cli onboard --config_file_path=ad/xapp-descriptor/config.json --shcema_file_path=ad/xapp-descriptor/controls.json

echo "-----------------------------------"
echo "===>  On-boarding RC xApp"
dms_cli onboard --config_file_path=rc/xapp-descriptor/config.json --shcema_file_path=rc/xapp-descriptor/schema.json

echo "-----------------------------------"
echo "===>  On-boarding TS xApp"
dms_cli onboard --config_file_path=ts/xapp-descriptor/config.json --shcema_file_path=ts/xapp-descriptor/schema.json

echo "-----------------------------------"
echo "===>  On-boarding QP xApp"
dms_cli onboard --config_file_path=qp/xapp-descriptor/config.json --shcema_file_path=qp/xapp-descriptor/schema.json

# -----------------------------------
echo "======> Listing the xapp helm chart"
dms_cli get_charts_list

sleep 5

# -----------------------------------
echo "===>  Deploying xApps"

cd ~

echo "-----------------------------------"
echo "===>  Deploying AD xApp"
dms_cli install --xapp_chart_name=ad --version=0.0.2 --namespace=ricxapp
sleep 30

echo "-----------------------------------"
echo "===>  Deploying RC xApp"
dms_cli install --xapp_chart_name=rc --version=1.0.0 --namespace=ricxapp
sleep 30

echo "-----------------------------------"
echo "===>  Deploying TS xApp"
dms_cli install --xapp_chart_name=trafficxapp --version=1.2.1 --namespace=ricxapp
sleep 30

echo "-----------------------------------"
echo "===>  Deploying QP xApp"
dms_cli install --xapp_chart_name=qp --version=0.0.4 --namespace=ricxapp
sleep 30

# -----------------------------------
echo "===>  Checking the pods of xApps"
kubectl get pod -n ricxapp

# -----------------------------------
echo "===>  Registering xApps"

export Service_appmgr=$(kubectl get services -n ricplt | grep "\-appmgr-http" | cut -f1 -d ' ')
export Appmgr_IP=$(kubectl get svc ${Service_appmgr} -n ricplt -o yaml | grep clusterIP | awk '{print $2}')


echo "===>  Registering AD xApp"

export Service_AD=$(kubectl get services -n ricxapp | grep "\-ad\-" | cut -f1 -d ' ')
export AD_IP=$(kubectl get svc ${Service_AD} -n ricxapp -o yaml | grep clusterIP | awk '{print $2}')

curl -X POST "http://${Appmgr_IP}:8080/ric/v1/register" -H 'accept: application/json' -H 'Content-Type: application/json' -d '{
  "appName": "ad",
  "appVersion": "0.0.2",
  "appInstanceName": "ad",
  "httpEndpoint": "",
  "rmrEndpoint": "${AD_IP}:4560",
  "config": " {\n    \"name\": \"ad\",\n    \"version\": \"0.0.2\",\n    \"containers\": [{\"image\":{\"name\":\"o-ran-sc/ric-app-ad\",\"registry\":\"nexus3.o-ran-sc.org:10002\",\"tag\":\"0.0.2\"},\"name\":\"ad\"}],\n    \"messaging\": {\n        \"ports\": [{\"container\":\"ad\",\"description\":\"rmr receive data port for ad\",\"name\":\"rmr-data\",\"policies\":[],\"port\":4560,\"txMessages\":[\"TS_ANOMALY_UPDATE\"],\"rxMessages\":[\"TS_ANOMALY_ACK\"]},{\"container\":\"ad\",\"description\":\"rmr route port for ad\",\"name\":\"rmr-route\",\"port\":4561}]\n    },\n    \"rmr\": {\n        \"protPort\": \"tcp:4560\",\n        \"maxSize\": 2072,\n        \"numWorkers\": 1,\n        \"rxMessages\": [\"TS_ANOMALY_ACK\"],\n        \"txMessages\": [\"TS_ANOMALY_UPDATE\"],\n        \"policies\": []\n    },\n    \"controls\": {\n        \"fileStrorage\": false\n    },\n    \"db\": {\n        \"waitForSdl\": false\n    }\n}\n"}  "
}'

echo "===>  Registering TS xApp"

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

echo "===>  Registering QP xApp"

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

sleep 30
# -----------------------------------
echo "===>  Check the xApp endpoints in the routing table"
export Service_rtmgr=$(kubectl get services -n ricplt | grep "\-rtmgr-http" | cut -f1 -d ' ')
export Rtmgr_IP=$(kubectl get svc ${Service_rtmgr} -n ricplt -o yaml | grep clusterIP | awk '{print $2}')

curl -X GET "http://${Rtmgr_IP}:3800/ric/v1/getdebuginfo" -H "accept: application/json" | jq .
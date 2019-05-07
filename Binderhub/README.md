Binderhub commands
```
export CLUSTER_NAME=cnh-esschool2019-001
export NAMESPACE=bhub01
export CNAME=bhub01
```

```gcloud container  clusters create  --machine-type n1-standard-2 --num-nodes 2 --zone us-west1-b --cluster-version  latest ${CLUSTER_NAME}```

```kubectl get node```

```
kubectl create clusterrolebinding cluster-admin-binding   --clusterrole=cluster-admin   --user=cnh-google@mit.edu
```

```
gcloud beta container node-pools create user-pool \
  --zone us-west1-b \
  --cluster cnh-esschool2019-001 \
  --machine-type n1-standard-2 \
  --num-nodes 0 \
  --enable-autoscaling \
  --min-nodes 0 \
  --max-nodes 8 \
  --node-labels hub.jupyter.org/node-purpose=user \
  --node-taints hub.jupyter.org_dedicated=user:NoSchedule
```

```
kubectl --namespace kube-system create serviceaccount tiller
```

```
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
```

```
helm init --service-account tiller --wait
```

```
kubectl patch deployment tiller-deploy --namespace=kube-system --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'
```

update ```secrets.yaml``` and ```config.yaml```

```
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart
helm repo update
```

```
helm install jupyterhub/binderhub --version=0.2.0-3b53fce  --name=${CNAME} --namespace=${NAMESPACE} -f secret.yaml -f config.yaml
```

```
kubectl --namespace=${NAMESPACE} get svc proxy-public
```

edit ```config.yaml```

```
helm upgrade bhub01 jupyterhub/binderhub --version=0.2.0-3b53fce  -f secret.yaml -f config.yaml
```

Binderhub commands

```gcloud container  clusters create  --num-nodes 1 --zone us-west1-b --cluster-version  latest cnh-esschool2019-001```

```kubectl get node```

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
```

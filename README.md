
# CNF Software Deployment

## Prepare Nodes
``` shell
kubectl label nodes ubuntu-k3sworker1 type=control-plane
kubectl label nodes ubuntu-k3sworker2 type=control-plane
kubectl label nodes ubuntu-k3sworker3 type=data-plane
```

## Begin CNF Build
### 1. Add NameSpace
```shell
kubectl create namespace cnf-gateway
```

###  2. Add ImageSecret
```shell
kubectl apply -n cnf-gateway -f vals/far-secret.yaml
```

### 3. Login to F5 Repo for HELM
```shell
cat cne_pull_64.json | helm registry login -u _json_key_base64 --password-stdin https://repo.f5.com
```
### 4. Install CRDs
```shell
helm install f5-cnf-crds-n6lan oci://repo.f5.com/charts/f5-cnf-crds-n6lan --version 0.161.0-0.1.2
```

### 5. Install Cert-Manager
```shell 
helm install f5-cert-manager oci://repo.f5.com/charts/f5-cert-manager --version 0.22.22-0.0.2 -f vals/values-certmanager.yaml -n cnf-gateway
```

### 6. Install CRDConversion
```shell 
helm install f5-crdconversion oci://repo.f5.com/charts/f5-crdconversion --version 0.9.4-0.0.3 -f vals/values-crdconversion.yaml -n cnf-gateway
```

### 7. Install RabbitMQ
```shell
helm install rabbitmq oci://repo.f5.com/charts/rabbitmq --version 0.2.8-0.0.2 -f vals/values-rabbit.yaml -n cnf-gateway
```

### 8. Install DSSM
```shell
kubectl apply -f vals/dssm-certs.yaml -n cnf-gateway

helm install f5-dssm oci://repo.f5.com/charts/f5-dssm --version 0.67.7-0.0.1 -f vals/values-dssm.yaml -n cnf-gateway
```

### 9. Install FluentD
```shell
helm install f5-toda-fluentd oci://repo.f5.com/charts/f5-toda-fluentd --version 1.23.36 -f vals/values-fluentd.yaml -n cnf-gateway
```

### 10. Install CWC
``` shell
sudo apt install make

helm pull oci://repo.f5.com/utils/f5-cert-gen --version 0.9.2

tar xvf f5-cert-gen-0.9.2.tgz

sh cert-gen/gen_cert.sh -s=api-server -a=f5-cnf-cwc.cnf-gateway -n=1

kubectl apply -f cwc-license-certs.yaml -n cnf-gateway
kubectl apply -f vals/cpcl-key.yaml -n cnf-gateway

helm install cwc oci://repo.f5.com/charts/cwc --version 0.14.15-0.0.6 -f vals/values-cwc.yaml -n cnf-gateway

```

### 11. Install Networks
```shell
kubectl apply -f vals/networks.yaml -n cnf-gateway
```

### 12. Apply OtelCerts & OtelSecrets
```shell
kubectl apply -f vals/otelcerts.yaml
# kubectl apply -f vals/otelsecrets.yaml
```

### 13. Apply Zebos ConfigMap

``` shell
kubectl create configmap cnf-bgp --from-file=cr/ZebOS.conf -n cnf-gateway

# use below if making changes to ZebOS

kubectl create configmap cnf-bgp --from-file=cr/ZebOS.conf -n cnf-gateway -o yaml --dry-run=client | kubectl apply -f -
```

### 13 Apply Static Routes

```shell
kubectl apply -f cr/cr-static-route.yaml
```
### 13. Install F5-Ingress
```shell
helm install f5ingress oci://repo.f5.com/charts/f5ingress --version v0.480.0-0.1.30 -f vals/values-f5ingress.yaml -n cnf-gateway
```

*Execute the below and confirm all pods are running.*
```shell
kubectl get pods -n cnf-gateway
```

>[!NOTE] 
>This concludes the software installation. 
>We will now move onto applying Custom Resources to build the configuration that will run on the installation. This would be similar to applying VIP's (L7/L4) etc. on a BIGIP.


---
# CNF Configuration

## License

### 1. Check Current Status

``` shell
curl -sk --cert /home/ubuntu/cnfbuild/api-server-secrets/ssl/client/certs/client_certificate.pem --key /home/ubuntu/cnfbuild/api-server-secrets/ssl/client/secrets/client_key.pem --cacert /home/ubuntu/cnfbuild/api-server-secrets/ssl/ca/certs/ca_certificate.pem https://10.1.1.8:30881/status
```

## Configuration

### 1. Install VLANS
Creating the VLAN's on CNF also includes applying SelfIP's and Port Lockdown configuration
```shell
kubectl apply -f cr/cr-vlans.yaml -n cnf-gateway
```
### 2. Install FW Policy
``` shell
kubectl apply -f cr/cr-fw-pol.yaml -n cnf-gateway
```
### 3. Install NAT Policy
``` shell
kubectl apply -f cr/cr-nat-pol.yaml -n cnf-gateway
```
### 4. Install DNS Resolver
``` shell
 kubectl apply -f cr/cr-dns-transparent-cache.yaml -n cnf-gateway
```
### 5. Install NAT64 VIP
``` shell
kubectl apply -f cr/cr-vip-nat64.yaml -n cnf-gateway
```



## Visual Performance

### 1. Create Namespace
```shell
kubectl apply -f cnf-prom-mtls.yaml
```
### 2. Apply  Prometheus MTLS Certificate
``` shell
kubectl apply -f cr/performanceMetrics/cnf-prom-mtls.yaml
```
### 3. Apply Prometheus Template
```shell
kubectl apply -f cr/performanceMetrics/cnf-prom-temp.yaml
```
### 4. Apply Grafana Template
```shell
kubectl apply -f cr/performanceMetrics/cnf-graf-temp.yaml
```
### 5. Connect to Grafana

Under the access methods on k3s-Worker-1 you should see a link for Grafana. This will for traffic to Node Address (10.1.1.7) on port 32000.


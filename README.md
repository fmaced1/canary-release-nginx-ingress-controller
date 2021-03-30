# Canary release com o nginx no k8s

## Sobre <a name = "sobre"></a>

Canary release usando nginx-ingress controller, metallb no k8s

### Pré requisitos

- Ter um cluster kubernetes provisionado (Nesse exemplo, fiz em um cluster on premises).

## Instalação

Instale o nginx ingress controller:
```bash
kubectl apply -f nginx-ingress-controller/ingress-nginx-manifests.yaml -f nginx-ingress-controller/expose-ingress-nginx.yaml

kubectl rollout status deploy nginx-ingress-controller -n ingress-nginx -w
```

Ajuste o range de ips que serão alocados para o MetalLB gerenciar:
```yaml
# metallb/configmap-metallb.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.x.y-192.168.x.z # ajuste aqui o range de ips
```

Instale o MetalLB para ter um loadbalancer:
```bash
kubectl apply -f metallb/configmap-metallb.yaml
kubectl apply -f metallb/metallb-manifests.yaml
```

## Canary release

Faça o deploy da aplicação v1:
```bash
# app-v1.yaml contém o deploy e o svc
# ingress-v1.yaml contém a rota
kubectl apply -f nginx-canary/apps/app-v1.yaml -f nginx-canary/apps/ingress-v1.yaml
```

Agora faça o deploy da segunda versão:
```bash
# app-v2.yaml contém o deploy e o svc
kubectl apply -f nginx-canary/apps/app-v2.yaml
```

```bash
kubectl get svc ingress-nginx -n ingress-nginx
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
ingress-nginx   LoadBalancer   10.106.17.108   192.168.x.y   80:31574/TCP   53m
```

Como não temos um dns, vamos colocar o nome da maquina no /etc/hosts apontando para um nome qualquer:
```bash
export IP_LOADBALANCER_METALLB="192.168.x.y"
echo "$IP_LOADBALANCER_METALLB k8s.local" >> /etc/hosts
```

Depois disso conseguimos fazer uma requisição para a rota da aplicação, deixe esse comando rodando em outro terminal:
```bash
count=0; while sleep 0.3; do let count+=1 ;echo $count - $(curl -s k8s.local); done
# output
1 - Host: my-app-v1-84ff7f48cc-kcn57, Version: v1.0.0
2 - Host: my-app-v1-84ff7f48cc-kcn57, Version: v1.0.0
3 - Host: my-app-v1-84ff7f48cc-kcn57, Version: v1.0.0
```

Agora vamos dividir o tráfego, 10% para o svc app-v2 e o resto continua no svc da app-v1:
```bash
kubectl apply -f nginx-canary/by-weight/ingress-v2-canary.yaml
```

### Veja no terminal que estamos usando para fazer as requisições, algumas estão indo para a app-v2:
```bash
bash canary/nginx-canary/curl-canary.sh k8s.local
...
v1: 290 v2: 30 - Host: my-app-v1-84ff7f48cc-4d9kq, Version: v1.0.0
v1: 291 v2: 30 - Host: my-app-v1-84ff7f48cc-4d9kq, Version: v1.0.0
v1: 292 v2: 30 - Host: my-app-v1-84ff7f48cc-4d9kq, Version: v1.0.0
v1: 293 v2: 30 - Host: my-app-v1-84ff7f48cc-4d9kq, Version: v1.0.0
v1: 294 v2: 30 - Host: my-app-v1-84ff7f48cc-4d9kq, Version: v1.0.0
v1: 295 v2: 30 - Host: my-app-v1-84ff7f48cc-4d9kq, Version: v1.0.0
v1: 296 v2: 30 - Host: my-app-v1-84ff7f48cc-4d9kq, Version: v1.0.0
v1: 297 v2: 30 - Host: my-app-v1-84ff7f48cc-4d9kq, Version: v1.0.0
v1: 297 v2: 31 - Host: my-app-v2-dfdff8845-n6bml, Version: v2.0.0
v1: 298 v2: 31 - Host: my-app-v1-84ff7f48cc-4d9kq, Version: v1.0.0
v1: 299 v2: 31 - Host: my-app-v1-84ff7f48cc-4d9kq, Version: v1.0.0
v1: 300 v2: 31 - Host: my-app-v1-84ff7f48cc-4d9kq, Version: v1.0.0
v1: 300 v2: 32 - Host: my-app-v2-dfdff8845-n6bml, Version: v2.0.0
```

Quando estiver satisfeito com a app-v2, exclua o ingress-canary:
```bash
kubectl delete -f nginx-canary/by-weight/ingress-v2-canary.yaml
```

E vire todo o tráfego para a app-v2
```bash
kubectl apply -f nginx-canary/apps/ingress-v2.yaml
```
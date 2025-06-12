 k get statefulset -n minio-tenant myminio-pool-0 -oyaml
  selector:
    matchLabels:
      v1.min.io/console: myminio-console
      v1.min.io/pool: pool-0
      v1.min.io/tenant: myminio
  serviceName: myminio-hl
  =======================================================
  k get svc -n minio-tenant
NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
minio             ClusterIP   10.43.134.69    <none>        80/TCP     13h
myminio-console   ClusterIP   10.43.171.206   <none>        9090/TCP   13h
myminio-hl        ClusterIP   None            <none>        9000/TCP   13h
========================================================================
k get pods -n minio-tenant
NAME               READY   STATUS    RESTARTS   AGE
myminio-pool-0-0   2/2     Running   0          13h
========================================================================
  configSecret:
    name: myminio-env-configuration
    accessKey: minio
    secretKey: minio123

# Minio CLI connection with port-forwarding
kubectl -n minio-tenant port-forward svc/minio 9000:80

# in another terminal
mc alias set local-minio http://127.0.0.1:9000 minio minio123
mc mb local-minio/velero  
mc ls local-minio/

# Using AWS CLI 
AWS_ACCESS_KEY_ID=minio AWS_SECRET_ACCESS_KEY=minio123 \                                                             ─╯
  aws --endpoint-url http://127.0.0.1:9000 s3api list-buckets

AWS_ACCESS_KEY_ID=minio AWS_SECRET_ACCESS_KEY=minio123 aws --endpoint-url http://192.168.1.30:30080 s3api create-bucket --bucket minio-tf-state

AWS_ACCESS_KEY_ID=minio AWS_SECRET_ACCESS_KEY=minio123 aws --endpoint-url http://192.168.1.30:30080 s3api list-buckets

From inside the cluster, any Pod can reach MinIO’s S3 API at:

http://minio.minio-tenant.svc.cluster.local:80

So, for example, a Velero config (in your `BackupStorageLocation`) would look like:

provider: aws
objectStorage:
  bucket: velero
  prefix: backups
  config:
    region: "us-east-1"                  # you can put any dummy “region”
    s3ForcePathStyle: "true"
    s3Url: "http://minio.minio-tenant.svc.cluster.local:80"

# Install Velero
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts

https://github.com/topics/velero-plugin

kubectl create namespace velero

cat <<EOF > credentials-velero
[default]
aws_access_key_id = "minio"
aws_secret_access_key = "minio123"
EOF

kubectl -n velero create secret generic cloud-credentials \
  --from-file=credentials-velero

# Values.yaml for Velero

https://velero.io/docs/v1.6/api-types/backupstoragelocation/

helm upgrade -i verlero vmware-tanzu/velero --namespace velero --create-namespace -f values-velero.yaml

kubectl get deployment/verlero-velero -n velero

kubectl get secret/verlero-velero -n velero

Once velero server is up and running you need the client before you can use it
1. wget https://github.com/vmware-tanzu/velero/releases/download/v1.16.0/velero-v1.16.0-darwin-amd64.tar.gz
2. tar -xvf velero-v1.16.0-darwin-amd64.tar.gz -C velero-client

```bash
❯ velero version
Client:
        Version: v1.16.1
        Git commit: 2eb97fa8b187f9ed0aeb49f216565eddf93a0b08
Server:
        Version: v1.16.0

❯ k logs -n velero verlero-velero-6cf6cb7886-4d4dp | grep 'level=info msg="BackupStorageLocations is valid, marking as available"'

❯ velero backup-location get
NAME          PROVIDER   BUCKET/PREFIX   PHASE       LAST VALIDATED                  ACCESS MODE   DEFAULT
local-minio   aws        velero          Available   2025-06-01 18:28:53 -0400 EDT   ReadWrite     true

❯ kubectl -n velero get backupstoragelocation

NAME          PHASE       LAST VALIDATED   AGE   DEFAULT
local-minio   Available   10s              21m   true

❯ kubectl -n velero describe backupstoragelocation local-minio

kubectl -n velero run test-s3 --restart=Never \
  --image=bitnami/aws-cli:2.15.0 \
  --env="AWS_ACCESS_KEY_ID=minio" \
  --env="AWS_SECRET_ACCESS_KEY=minio123" \
  --command -- /bin/sh -c 'sleep 3600'

k exec -n velero -it test-s3 -- /bin/sh
  # $ aws --endpoint-url http://minio.minio-tenant.svc.cluster.local:80 s3 ls
    # 2025-06-01 20:02:46 velero
  # $ aws --endpoint-url http://minio.minio-tenant.svc.cluster.local:80 s3 ls s3://velero/backups/nginx-backup/

k apply -f with-pv.yaml 

velero backup create nginx-backup --selector app=nginx -oyaml
```

```yaml
❯ cat bakup-nginx.yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: nginx-backup
  namespace: velero
spec:
  includedNamespaces:
  - '*'
  storageLocation: local-minio
  labelSelector:
    matchLabels:
      app: nginx
  metadata: {}
  ttl: 720h0m0s
status: {}
```

```bash
# testing backup
k get pv -n nginx-example                                                                                                ─╯
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                 STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-32e4d535-e5c3-4fcd-867b-727275f47229   50Mi       RWO            Delete           Bound    nginx-example/nginx-logs              longhorn       <unset>                          117m
pvc-92133d0b-f3be-4fcc-9fef-f3e8ed26f30b   10Gi       RWO            Delete           Bound    minio-tenant/data0-myminio-pool-0-0   longhorn       <unset>                          18h

curl 192.168.1.31:30180                                                                                                  ─╯
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

velero backup create nginx-backup --selector app=nginx -oyaml > backup-nginx.yaml

velero restore create --from-backup nginx-backup -oyaml > restore-nginx.yaml

❯ k get restore -n velero
NAME                          AGE
nginx-backup-20250601205832   24s


```

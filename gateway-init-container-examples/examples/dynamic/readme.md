## Dynamic
This example loads private keys, stored passwords, trusted certificates (.cer), cluster-wide properties and custom scripts. It assumes that you have a script to load in gateway resources from an external location. To keep things simple, we've pre-populated the pki folder.

## Running this example
This example works with resources in the [gateway](../../gateway/) check out the [readme](../../readme.md) for more details.

### Files
- Dockerfile
 - image: [python:slim](https://hub.docker.com/layers/library/python/slim/images/sha256-dd5373185c7a15f37665b9dc97c981e65f2ba8d2dca02f6cfd680d803756e6b9?context=explore)

### Folders
- PKI
  - contains .p12 files and .cer files
    - .cer files are automatically converted into Trusted Certificates for the API Gateway
    - .p12 files are password locked and require additional configuration
- Scripts
  - *.sh
    - bash scripts are executed as is.
  - *.py
    - only python files that contain ```preboot_``` are executed.
- Config
  - Contains the correct folder structure that must be copied to /opt/docker/custom
  - These folders can be prepopulated

### Additional Configuration

[init env secret](../../gateway/init.env)
```
BOOTSTRAP_DIR=/config/config/bundle
SSG_CLUSTER_PASSWORD=mypassword
PRIVATEKEY.gatewaybrcmlabs.PASSWORD=CAdemo123
PRIVATEKEY.gateway1brcmlabs.PASSWORD=7layer
PRIVATEKEY.DEFAULT.PASSWORD=CAdemo123
STOREDSECRET.Test=Test123
CLUSTERPROP.Test=Test321
KEY_DIR=pki
```

- BOOTSTRAP_DIR is the folder that bundles will be written to, this should be the same as the shared volume configured in your Gateway Deployment. This example is pre-configured with this already set.
- SSG_CLUSTER_PASSWORD is the pass phrase that the bundles will be encrpyted with, this needs to match what is configured in the API Gateway.
- KEY_DIR is the directory that the python script scans for files. It accepts .p12 and .cer
- PRIVATEKEY.name.PASSWORD=password - name needs to match filename without the extension in KEY_DIR
- STOREDSECRET.name=value
- CLUSTERPROP.name=value

***Any .cer files in KEY_DIR will be automatically bundled.***

### Verify

- ```$ kubectl get svc -n layer7```

``` 
NAME          TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)                         AGE
ssg-gateway   LoadBalancer   10.68.5.205   <external-ip>   8443:32423/TCP,9443:30140/TCP   85s
```

- Note the EXTERNAL-IP for ssg-gateway
- Open Policy Manager and connect to the EXTERNAL-IP for ssg-gateway on port 9443
  - username: admin
  - password: mypassword
- Verify that 2 additional keys have been loaded
  - Tasks ==> Certificates, Keys and Secrets ==> Manage Private Keys
    - gatewaybrcmlabs
    - gateway1brcmlabs
- Verify that the listen ports have been updated
  - Tasks ==> Transports == Manage Listen Ports
    - 8443 - uses gatewaybrcmlabs
    - 9443 - uses gateway1brcmlabs
- You can also verify that there is a Stored Password called Test and a Cluster-Wide Property called Test

Confirm that the correct keys are being used with curl

``` 
NAME          TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)                         AGE
ssg-gateway   LoadBalancer   10.68.5.205   <external-ip>   8443:32423/TCP,9443:30140/TCP   85s
```

- ```$ curl -kv https://<external-ip>:8443/helloworld```

```
...
* Server certificate:
*  subject: C=GB; ST=London; L=Test; O=Test; OU=Test; CN=gateway.brcmlabs.com
*  start date: Oct  5 10:37:10 2022 GMT
*  expire date: Oct  5 10:37:10 2023 GMT
*  issuer: C=GB; ST=London; L=Test; O=Test; OU=Test; CN=gateway.brcmlabs.com
*  SSL certificate verify result: self signed certificate (18), continuing anyway.
...
Hello World!
```

- ```$ curl -kv https://<external-ip>:9443/helloworld```
```
...
* Server certificate:
*  subject: C=GB; ST=London; L=Test; O=Test; OU=Test; CN=gateway1.brcmlabs.com
*  start date: Oct  5 10:37:34 2022 GMT
*  expire date: Oct  5 10:37:34 2023 GMT
*  issuer: C=GB; ST=London; L=Test; O=Test; OU=Test; CN=gateway1.brcmlabs.com
*  SSL certificate verify result: self signed certificate (18), continuing anyway.
...
Hello World!
```
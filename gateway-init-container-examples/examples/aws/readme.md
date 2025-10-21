## AWS  Example
This example simply uses a Kubernetes initContainer(amazon/aws-cli:latest) to fetch an AWS secret (store node.properties as key values) from AWS Secrets Manager as singleline json and then 
covert it into a multi-line node.properties before mounting to shared volume "shared-secret" at /opt/docker/conf

The Gateway deployment mounts shared volume "shared-secret" at /opt/SecureSpan/Gateway/node/default/etc/conf/node.properties subpath node.properties.

## Running this example
Steps was copied from https://github.com/aws/secrets-store-csi-driver-provider-aws/tree/main?tab=readme-ov-file#usage

Prerequisite: install awscli and eksctl

Set the region name, name of your cluster to use in the bash commands that follow:
```
REGION=<REGION>
CLUSTERNAME=<CLUSTERNAME>
```

#### Set up an AWS secret with all key values in node.properties.
Unlike interactive password changes in Policy Manager, the container startup scripts validate the following username and password against a restricted character set (for parsing/scripting safety):
```
admin.user, admin.pass, node.db.config.main.user, node.db.config.main.pass
```
They may contain alphanumeric ASCII characters and any of the following symbols:

! @ . = - _ ^ + ; : # , %. Do NOT use space characters.

Convert multiple line node.properties into single line json format as secret-string.

For example
node.properties for derby database, store as a secret "gateway.node.properties" in AWS secret Manager.
To update secret can replace create-secret with update-secret.
```
node.cluster.pass=7layer
admin.user=admin
admin.pass=autotest
node.db.type=derby
node.db.config.main.user=gateway

aws --region "$REGION" secretsmanager  create-secret --name gateway.node.properties --secret-string '{"node.cluster.pass":"7layer","admin.user":"admin","admin.pass":"autotest","node.db.type":"derby","node.db.config.main.user":"gateway"}'
```

#### Create an access policy for the pod to access AWS secrets manager secret gateway.node.properties for read and write


```
POLICY_ARN=$(aws --region "$REGION" --query Policy.Arn --output text iam create-policy --policy-name aws-secret-access-policy --policy-document '{
    "Version": "2012-10-17",
    "Statement": [ {
        "Effect": "Allow",
        "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
        "Resource": ["arn:*:secretsmanager:*:*:secret:gateway.node.properties-??????"]
    } ]
}')

```
#### Create service account to access AWS secret Manager

```
eksctl create iamserviceaccount --name gw-sa --region="$REGION" --cluster "$CLUSTERNAME" --attach-policy-arn "$POLICY_ARN" --approve --override-existing-serviceaccounts --namespace <placeholder>

```

This example works with resources in the [gateway](../../gateway/) check out the [readme](../../readme.md) for more details.
use gateway helm chart gateway/helm/aws-secret-gateway-values.yaml as example.
Update the serviceAccount.name, service-id and AWS_REGION with yours. 



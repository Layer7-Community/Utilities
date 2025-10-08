## AWS  Example
This example simply uses a Kubernetes initContainer(amazon/aws-cli:2.15.0) to fetch an AWS secret (store node.properties as key values) from AWS Secrets Manager as singleline json and then 
covert it into a shared volume /opt/docker/custom/custom-properties as multi-line node.properties. 
The Gateway Helm Chart is then configured to use bootstrap script to copy this node.properties to /opt/SecureSpan/Gateway/node/default/etc/conf/node.properties.

## Running this example
https://github.com/aws/secrets-store-csi-driver-provider-aws/tree/main?tab=readme-ov-file
#### Set up an AWS secret with all key values in node.properties. 
For example
Node.properties for derby database, store as a secret "gateway.node.properties" in AWS secret Manager
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
POLICY_ARN=$(aws --region "$REGION" --query Policy.Arn --output text iam create-policy --policy-name nginx-deployment-policy --policy-document '{
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
use gateway helm chart aws-secret-gateway-values.yaml

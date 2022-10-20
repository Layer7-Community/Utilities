# Install/Uninstall this project into a Kubernetes Cluster
# This is for demonstration purposes only and does not represent
# any form of a production ready implementation.
# It is recommended that this demo is run against sandbox environments only

install:
	kubectl apply -k ./gateway
	helm repo add layer7 https://caapim.github.io/apim-charts/
	helm repo update
simple:
	helm install ssg --set license.accept=true -f ./gateway/helm/simple-gateway-values.yaml -n layer7 layer7/gateway
dynamic:
	helm install ssg --set license.accept=true -f ./gateway/helm/dynamic-gateway-values.yaml -n layer7 layer7/gateway
uninstall:
	kubectl delete namespace layer7
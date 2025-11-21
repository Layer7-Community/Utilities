#!/bin/bash

helm uninstall gateway-prod
helm uninstall gateway-staging
helm uninstall gateway-dev

kubectl delete -k .

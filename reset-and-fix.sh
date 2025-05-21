#!/bin/bash
set -e

echo "===== STEP 1: Cleaning up existing resources ====="
# Delete existing Ingress and LoadBalancers
echo "Deleting existing Ingress..."
kubectl delete ingress chatwoot-ingress --ignore-not-found=true

echo "Deleting existing LoadBalancers..."
kubectl delete service chatwoot-loadbalancer --ignore-not-found=true
kubectl delete service ingress-nginx-loadbalancer -n ingress-nginx --ignore-not-found=true

echo "===== STEP 2: Reinstalling Ingress Controller ====="
# Check if ingress-nginx namespace exists, if not create it
if ! kubectl get namespace ingress-nginx &>/dev/null; then
  echo "Creating ingress-nginx namespace..."
  kubectl create namespace ingress-nginx
fi

echo "Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

echo "Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo "===== STEP 3: Creating a single LoadBalancer for Ingress Controller ====="
cat <<EOF > ingress-loadbalancer.yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-loadbalancer
  namespace: ingress-nginx
  annotations:
    service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-algorithm: "round_robin"
    service.beta.kubernetes.io/do-loadbalancer-disable-proxy-protocol: "true"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
EOF

echo "Applying LoadBalancer configuration..."
kubectl apply -f ingress-loadbalancer.yaml

echo "Waiting for LoadBalancer to get an external IP..."
while [ -z "$(kubectl get service ingress-nginx-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)" ]; do
  echo "Waiting for external IP..."
  sleep 10
done

EXTERNAL_IP=$(kubectl get service ingress-nginx-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "LoadBalancer external IP: $EXTERNAL_IP"

echo "===== STEP 4: Updating ConfigMap with correct IP ====="
echo "Updating ConfigMap..."
kubectl patch configmap chatwoot-config --type=merge -p "{\"data\":{\"DOMAIN\":\"$EXTERNAL_IP\",\"FRONTEND_URL\":\"http://$EXTERNAL_IP\",\"VITE_APP_URL\":\"http://$EXTERNAL_IP\"}}"

echo "===== STEP 5: Creating Ingress with proper configuration ====="
cat <<EOF > ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: chatwoot-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: chatwoot-rails
            port:
              number: 3000
      - path: /cable
        pathType: Prefix
        backend:
          service:
            name: chatwoot-rails
            port:
              number: 3000
      - path: /vite
        pathType: Prefix
        backend:
          service:
            name: chatwoot-vite
            port:
              number: 3036
      - path: /mailhog
        pathType: Prefix
        backend:
          service:
            name: chatwoot-mailhog
            port:
              number: 8025
EOF

echo "Applying Ingress configuration..."
kubectl apply -f ingress.yaml

echo "===== STEP 6: Restarting deployments ====="
echo "Restarting deployments..."
kubectl rollout restart deployment chatwoot-rails
kubectl rollout restart deployment chatwoot-vite

echo "Waiting for deployments to restart..."
kubectl rollout status deployment chatwoot-rails
kubectl rollout status deployment chatwoot-vite

echo "===== STEP 7: Verifying setup ====="
echo "Checking pods..."
kubectl get pods

echo "Checking services..."
kubectl get services

echo "Checking Ingress..."
kubectl get ingress

echo "Checking LoadBalancer..."
kubectl get service ingress-nginx-loadbalancer -n ingress-nginx

echo "===== DONE ====="
echo "Setup complete! Your application should be accessible at: http://$EXTERNAL_IP"
echo "Please wait 5-10 minutes for DNS propagation and for all components to stabilize."
echo "If you're still having issues, check the logs with:"
echo "kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx"
echo "kubectl logs -l app=chatwoot-rails"

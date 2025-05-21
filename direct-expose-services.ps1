# Delete existing Ingress and LoadBalancers
Write-Host "Cleaning up existing resources..."
kubectl delete ingress chatwoot-ingress --ignore-not-found=true
kubectl delete service ingress-nginx-loadbalancer -n ingress-nginx --ignore-not-found=true

# Apply direct LoadBalancer services
Write-Host "Creating direct LoadBalancer services..."
kubectl apply -f k8s/direct-expose.yaml

# Wait for LoadBalancer IPs
Write-Host "Waiting for LoadBalancer IPs..."
Start-Sleep -Seconds 30

# Get LoadBalancer IPs
$RAILS_IP = kubectl get service chatwoot-rails-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
$VITE_IP = kubectl get service chatwoot-vite-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Write-Host "Rails LoadBalancer IP: $RAILS_IP"
Write-Host "Vite LoadBalancer IP: $VITE_IP"

# Update ConfigMap with the correct IPs
Write-Host "Updating ConfigMap with the correct IPs..."
kubectl patch configmap chatwoot-config --type=merge -p "{\"data\":{\"DOMAIN\":\"$RAILS_IP\",\"FRONTEND_URL\":\"http://$RAILS_IP\",\"VITE_APP_URL\":\"http://$VITE_IP:3036\"}}"

# Restart the deployments
Write-Host "Restarting deployments..."
kubectl rollout restart deployment chatwoot-rails
kubectl rollout restart deployment chatwoot-vite

# Wait for deployments to restart
Write-Host "Waiting for deployments to restart..."
kubectl rollout status deployment/chatwoot-rails
kubectl rollout status deployment/chatwoot-vite

Write-Host ""
Write-Host "Setup complete!"
Write-Host "Your application should now be accessible at: http://$RAILS_IP"
Write-Host "Vite assets should be served from: http://$VITE_IP:3036"
Write-Host "Please wait a few minutes for the changes to take effect and then try accessing the application."
Write-Host ""
Write-Host "If you're still having issues, check the logs with:"
Write-Host "kubectl logs -l app=chatwoot-rails --tail=100"
Write-Host "kubectl logs -l app=chatwoot-vite --tail=100"

# EKS Deployment Debug - Session Summary (April 6, 2026)

## Current Status
**Issue:** Database password authentication failures in microservices
- All microservices (order-service, product-service, user-service) fail with: "password authentication failed for user 'postgres'"
- PostgreSQL cluster itself is healthy (postgres-cluster-1, postgres-cluster-2 Running)
- api-gateway and frontend are Running (they don't need DB)

## What Was Tried
1. ✅ Updated deployments to use `postgres-credentials` secret instead of `db-credentials`
2. ✅ Added env var mapping: POSTGRES_USER → DB_USER, POSTGRES_PASSWORD → DB_PASSWORD
3. ✅ Verified secret password is `postgres` (base64 decoded correctly)
4. ✅ Verified deployments have correct env var configuration
5. ✅ Applied updated manifests and restarted deployments
6. ❌ Pods still crash with auth failure

## Key Findings
- Secret `postgres-credentials` exists with:
  - POSTGRES_USER: postgres
  - POSTGRES_PASSWORD: postgres
- Deployments correctly map:
  - DB_USER from secretKeyRef POSTGRES_USER
  - DB_PASSWORD from secretKeyRef POSTGRES_PASSWORD
- Application code expects DB_USER and DB_PASSWORD env vars
- But connection still fails with auth error

## Next Steps for Tomorrow
1. Verify CloudNativePG cluster password is actually set to `postgres`
2. Check if pods have correct env vars at runtime (exec into running pod)
3. Test direct connection to PostgreSQL from a debug pod
4. Verify CloudNativePG cluster initialization used correct password
5. Check if there's a mismatch between secret and actual DB password

## Commands to Run Tomorrow
```bash
# Check actual env vars in a running pod
kubectl exec <pod-name> -n production -- env | grep DB_

# Connect to PostgreSQL from debug pod
kubectl run debug --rm -it --image=postgres:15 --restart=Never -n production -- psql -h postgres-rw -U postgres -d products_db

# Check CloudNativePG cluster status
kubectl get cluster postgres-cluster -n production -o yaml | grep -A5 "superuserSecret"
```

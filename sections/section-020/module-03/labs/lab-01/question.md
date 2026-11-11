---
draft: true
---
# Repair Authenticated Image Pulls

Solve this question on: `terminal`

The namespace `starfleet-035-020-03-01` contains a private registry and a failing `release-check` Pod. ConfigMap `registry-info` gives the registry server and image. The disposable registry account is `builder` with password `training-password`. The nodes already know how to reach this registry.

Allow about 15 minutes for the tasks. Cluster startup and registry seeding add time.

## Tasks

1. Create Secret `registry-credentials` of type `kubernetes.io/dockerconfigjson` with the supplied credential for the exact server in `registry-info`.
2. Set ServiceAccount `probe-runner` to use that image pull Secret.
3. Recreate `release-check` with that ServiceAccount, the private image from `registry-info`, and `imagePullPolicy: Always`. Keep its `client` container running with `sh -c 'sleep 36000'`.

## Constraints

Preserve the registry, its authentication, the seeded image, node configuration and unrelated workloads. Do not preload the private image or put credentials into node configuration. The registry uses HTTP only inside this disposable training network; a real registry needs trusted TLS.

## How the answer is checked

The grader creates a fresh Pod without explicit imagePullSecrets and checks that it inherits the ServiceAccount credential, pulls the private image and executes it. A wrong credential must fail even if image layers are cached, because Always resolves the image through the registry.

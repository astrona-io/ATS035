---
draft: true
---
# Prove An Authenticated Registry Pull

Configure a ServiceAccount pull secret for the private registry installed in this lab. Fresh Pods must authenticate and run the private image; incorrect credentials must fail. The registry uses disposable credentials and HTTP inside the isolated kind environment.

`astrona test -c .` verifies the broken starting state, applies the solution, tests incorrect credentials, restores access and runs the final graders.

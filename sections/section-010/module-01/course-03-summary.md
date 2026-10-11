---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Summary

Images combine filesystem layers and startup configuration. Tags can change, while digests identify particular content. A running container and its selected image are different lifecycle objects.

Image retrieval depends on the reference, registry access, platform compatibility and node preparation. A successful build or available local artifact does not prove that every intended node can retrieve and run the same artifact.

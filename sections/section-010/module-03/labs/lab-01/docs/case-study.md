---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Starting Environment

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The `shuttle` pod runs BusyBox by tag. The required pod does not exist.

Read the digest that the node reports for the BusyBox image and start a pod that refers to the image by that digest.

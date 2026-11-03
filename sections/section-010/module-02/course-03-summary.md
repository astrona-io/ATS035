---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Summary

The base image decides most of the content of an image, and the pod specification decides what the process may do with that content. Both reduce attack surface, and neither replaces the other.

## What you learned

A Debian image holds the GNU C library, a full shell and the `apt` package manager. An Alpine image holds the `musl` library, BusyBox and `apk`. A distroless image holds only what a program needs at run time and has no shell or package manager. The `scratch` image is empty and runs only static binaries. A program built against `glibc` does not start on a `musl` image, while a static Go binary runs on all four.

You can count the packages with `apk info` and the commands in `/bin`, and you can check whether an interpreter exists with `which`. A count is a hint about exposure and not a risk score, because one outdated package can matter more than many current ones.

At run time, a process has a user ID, Linux capabilities, a root filesystem and a seccomp filter. Without settings, the process runs as the image user, often root, holds a default capability set, can write to the root filesystem and runs without a seccomp filter. The files `/proc/1/status` and the `id` command show these values from inside the container.

A pod restricts them with `runAsNonRoot` and a numeric `runAsUser`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]` and the `RuntimeDefault` seccomp profile. A program that must write gets a writable volume at one path.

- Choose the smallest base image that runs the program, and test the program on it.
- Run as a numeric non-root user with all capabilities dropped.
- Keep the root filesystem read-only and add a writable volume only where needed.
- Apply the `RuntimeDefault` seccomp profile.

<!-- astrona:playground:destroy -->

---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Hardening A Dockerfile

A multi-stage build keeps the compiler out of the final image, but many other Dockerfile mistakes put weight and risk back in: a root user, a floating base image, an installed package that is not needed, a credential copied in and deleted again. Most of these mistakes are visible in the text of the Dockerfile, which means a linter can find them before the image is built. This part reads one weak Dockerfile, lints it, fixes it and then shows why a secret needs a different mechanism than a file copy.

## A Dockerfile with common mistakes

Read the Dockerfile below before you run anything. It builds a small Python service, and it has five problems that you can find by reading it.

<!-- astrona:playground:renew -->

Save this as `Dockerfile.weak`:

```dockerfile
FROM python:latest
RUN apt-get update && apt-get install -y curl vim
ADD . /app
WORKDIR /app
RUN pip install -r requirements.txt
CMD ["python", "server.py"]
```

The problems are these:

- `python:latest` has a floating tag, so a build next week can produce a different image, and the full Debian-based Python image is large.
- `apt-get install` adds `curl` and `vim`, which the service does not need at run time. It also installs recommended packages and leaves the package index in the layer.
- `ADD . /app` copies everything in the build folder, including `.git`, local notes and any credential file that happens to be there. `COPY` is the correct instruction for local files, because `ADD` can also download URLs and unpack archives.
- There is no `USER` instruction, so the process runs as root, user ID 0, inside the container.
- The package versions in `requirements.txt` are not shown here, and the base image has no digest.

## Lint the Dockerfile

Hadolint is a Dockerfile linter. It parses the file, applies its rules and prints one finding for each violation, with the rule ID, such as `DL3007`, and the line number. It also runs ShellCheck on the shell commands in `RUN` instructions. It needs no engine and no build, so it fits in a pipeline step before the image build. Install hadolint on your machine from its release page, then run it:

```sh
hadolint Dockerfile.weak
```

Hadolint prints findings for the lines above. Look for the rules that match the problems: `DL3007` for the `latest` tag, `DL3008` for apt packages without pinned versions, `DL3015` for the missing `--no-install-recommends`, `DL3020` for `ADD` where `COPY` is enough, `DL3042` for pip without `--no-cache-dir`, and `DL3002` for the last user being root. The exact text of each message depends on the hadolint version. A rule that you accept as an exception can be skipped with `--ignore DL3008`, and `--failure-threshold error` sets the lowest severity that makes the command exit with a non-zero code.

Trivy can lint the same file with its misconfiguration scanner (`trivy config .`), whose Dockerfile checks have IDs that begin with `DS`, for example for the root user and the `latest` tag. Two linters rarely report the same set, so a pipeline can run either one as long as the team treats the findings as a gate.

## Fix the file

Create a `.dockerignore` file next to the Dockerfile. The build engine reads it before it sends the build context, which is the folder content that the build can copy from. Files that match are not available to `COPY`:

```text
.git
.env
*.pem
*.key
__pycache__
Dockerfile*
```

Save this as `Dockerfile.fixed`. It uses a build stage to install the Python packages into a virtual environment and a slim final stage that copies only that environment and the code:

```dockerfile
FROM docker.io/library/python:3.13-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN python -m venv /venv && /venv/bin/pip install --no-cache-dir -r requirements.txt

FROM docker.io/library/python:3.13-slim
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin app
COPY --from=build /venv /venv
COPY --chown=app:app server.py /app/server.py
ENV PATH="/venv/bin:$PATH"
USER 10001
WORKDIR /app
CMD ["python", "server.py"]
```

The base image tag now names a version and a smaller variant. The numeric `USER 10001` matters in Kubernetes: with `runAsNonRoot: true`, the kubelet (the node agent) can only verify a numeric user, and it rejects a name that it cannot map to a user ID. A production file would also pin the base image by digest, as in `FROM docker.io/library/python:3.13-slim@sha256:<digest>`, and let an update tool change the digest in a reviewed commit. Run the linter again:

```sh
hadolint Dockerfile.fixed
```

The findings for the tag, the root user and `ADD` no longer appear. What remains, if anything, is the warning about the missing digest or other style rules, which you decide on per project.

## Secrets stay in layers

Deleting a secret in a later instruction does not remove it from the image, because each layer is an archive of its own. Save this as `Dockerfile.leak`, and create a file named `token.txt` that contains any text:

```dockerfile
FROM docker.io/library/alpine:3.22
COPY token.txt /token.txt
RUN wc -c /token.txt && rm /token.txt
```

Build it and read the history with the full instruction text:

```sh
podman build -f Dockerfile.leak -t leaky:1 .
podman history --no-trunc leaky:1
```

The history lists the `COPY token.txt /token.txt` instruction as its own layer. The final filesystem has no `/token.txt`, but anyone who pulls the image can unpack that layer and read the file. The same is true for a token passed with `ARG` or `ENV`: the value is recorded in the image config and in the history.

The correct mechanism is a **secret mount**. The build engine mounts the secret as a file for the duration of one `RUN` instruction and never writes it into a layer. Save this as `Dockerfile.secret`:

```dockerfile
FROM docker.io/library/alpine:3.22
RUN --mount=type=secret,id=token wc -c /run/secrets/token
```

Build it with the secret supplied from the file, and read the history:

```sh
podman build -f Dockerfile.secret --secret id=token,src=token.txt -t safe:1 .
podman history --no-trunc safe:1
```

The build succeeds and the `RUN` instruction can read the secret at `/run/secrets/token`. The history shows the instruction and its mount option but not the content, and the secret is not in any layer. For a multi-stage build, a secret that is only used in the build stage also never reaches the final stage, but a secret mount is the safer choice because it also keeps the value out of the intermediate stage's layers.

You can now find the common Dockerfile mistakes by reading and by linting, and you know how to keep a credential out of the layers. A hardened image still has to run under the right settings in the cluster, and the cluster must be able to pull it. The next part runs a minimal image in the playground cluster.

## Common pitfalls

> [!WARNING]
> - **Removing a secret with `rm` in a later instruction.** The earlier layer keeps it. Use a secret mount, and never `ARG` or `ENV`, for credentials.
> - **Using a user name in `USER` with `runAsNonRoot`.** The kubelet cannot verify a name. Use a numeric user ID.
> - **Running `apt-get update` and `apt-get install` in separate `RUN` instructions or cleaning the index in a later one.** The index stays in an earlier layer. Do all three steps in one `RUN`.
> - **Treating a clean lint as a secure image.** Hadolint checks the Dockerfile text. It does not look at the packages in the base image.

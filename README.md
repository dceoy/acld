# acld

Run a minimal Linux desktop, Claude Desktop, or AI coding-agent environment using Apple Container, XFCE, TigerVNC, and noVNC.

## Requirements

- Apple silicon Mac
- macOS 26 or later
- Apple `container` CLI
- `make` from the macOS command line developer tools

## Architecture

```text
macOS browser
  -> localhost:6080
  -> noVNC / websockify
  -> TigerVNC X server
  -> XFCE desktop
  -> Apple Container Linux VM
```

The repository intentionally keeps the implementation small:

- `Containerfile.base` provides the minimal desktop
- `Containerfile.claude` adds Claude Desktop and development tools
- `Containerfile.agents` provides a Debian-based Herdr environment with AI coding and DevOps tools
- `entrypoint.sh` starts the desktop services
- `acld.sh` wraps Apple `container` operations
- one host workspace bind mount and one persistent home volume

## Quick start

Start the minimal desktop:

```sh
make up
```

Open the printed noVNC URL, normally `http://localhost:6080/vnc.html`, and enter the displayed VNC password.

The command is safe to rerun and does not create a duplicate container.

## Image variants

List available variants:

```sh
make variants
```

| Variant   | Containerfile           | Image                               | Container      | Purpose                                  |
| --------- | ----------------------- | ----------------------------------- | -------------- | ---------------------------------------- |
| `base`    | `Containerfile.base`    | `ghcr.io/dceoy/acld-base:latest`    | `acld-base`    | Minimal XFCE desktop                     |
| `claude`  | `Containerfile.claude`  | `ghcr.io/dceoy/acld-claude:latest`  | `acld-claude`  | Claude Desktop and development tools     |
| `agents`  | `Containerfile.agents`  | `ghcr.io/dceoy/acld-agents:latest`  | `acld-agents`  | Herdr with the full development toolchain |

The former `ai` variant has been renamed to `claude` so the variant name describes the installed application explicitly. This also changes the default container name from `acld-ai` to `acld-claude` and the default home volume from `acld-ai-home` to `acld-claude-home`. To keep using the existing Claude Desktop settings and login state, reuse the old volume explicitly:

```sh
make up VARIANT=claude HOME_VOLUME=acld-ai-home
```

### Minimal desktop

```sh
make up
make up VARIANT=base
```

### Claude Desktop

```sh
make up VARIANT=claude
```

### AI coding agents with Herdr

```sh
make up VARIANT=agents PORT=6082 MEMORY=8G
make shell VARIANT=agents
herdr
```

The agents image is built directly from Debian 13 and includes Herdr, Claude Code, Codex CLI, OpenCode, GitHub CLI, Oracle, agent-browser, Docker Engine/CLI with Buildx and Compose, uv, pnpm, Playwright, AWS CLI, Terraform, Terragrunt, Trivy, and related development utilities.

## Variant overrides

`VARIANT` selects the Containerfile, image tag, and container name together. The values remain independently overridable:

```sh
make build VARIANT=agents
make status VARIANT=agents
make down VARIANT=agents
make clean VARIANT=agents
```

Custom definitions can be selected explicitly:

```sh
make up \
  VARIANT=custom \
  CONTAINERFILE=Containerfile.custom \
  IMAGE=acld:custom \
  NAME=acld-custom
```

To run variants simultaneously, use different host ports:

```sh
make up VARIANT=base PORT=6080
make up VARIANT=claude PORT=6081
make up VARIANT=agents PORT=6082 MEMORY=8G
```

## Make targets

```text
make <target> [VARIABLE=value ...]
```

| Target     | Description                                           |
| ---------- | ----------------------------------------------------- |
| `up`       | Start the selected desktop; safe to rerun             |
| `down`     | Stop the selected container                           |
| `status`   | Show container status and service endpoints           |
| `shell`    | Open an interactive shell                             |
| `pull`     | Pull the selected image                               |
| `build`    | Build the selected image locally                      |
| `clean`    | Remove the selected container, image, and home volume |
| `variants` | List available `Containerfile.*` variants             |
| `help`     | Show command usage                                    |

## Configuration

| Variable        | Default                                | Description                                          |
| --------------- | -------------------------------------- | ---------------------------------------------------- |
| `VARIANT`       | `base`                                 | Selects the Containerfile, image, and container name |
| `CONTAINERFILE` | `Containerfile.${VARIANT}`             | Container build definition                           |
| `IMAGE`         | `ghcr.io/dceoy/acld-${VARIANT}:latest` | OCI image reference                                  |
| `NAME`          | `acld-${VARIANT}`                      | Container name                                       |
| `HOST_IP`       | `127.0.0.1`                            | Host bind address                                    |
| `PORT`          | `6080`                                 | noVNC host port                                      |
| `CPUS`          | `4`                                    | CPU allocation                                       |
| `MEMORY`        | `4G`                                   | Memory allocation                                    |
| `VNC_GEOMETRY`  | `1440x900`                             | Desktop resolution                                   |
| `VNC_DEPTH`     | `24`                                   | VNC color depth                                      |
| `VNC_PASSWORD`  | generated when empty                   | VNC password                                         |
| `WORKSPACE_DIR` | current directory                      | Host directory mounted at `/workspace`               |
| `HOME_VOLUME`   | `acld-${VARIANT}-home`                 | Persistent volume mounted at `/home/agent`           |

Example:

```sh
make up VARIANT=agents MEMORY=8G WORKSPACE_DIR="$HOME/projects/demo"
```

## Persistent storage

Each desktop uses two mounts:

- the selected host workspace is mounted read-write at `/workspace`
- a named Apple Container volume is mounted at `/home/agent`

The home volume preserves desktop settings, Claude Desktop configuration, agent configuration, browser state, and development-tool state across `down` and `up` cycles.

Changing `WORKSPACE_DIR` or `HOME_VOLUME` takes effect after recreating the container:

```sh
make down VARIANT=agents
make up VARIANT=agents WORKSPACE_DIR="$HOME/projects/demo"
```

## Shell access

```sh
make shell
make shell VARIANT=claude
make shell VARIANT=agents
```

## Security

- noVNC binds to `127.0.0.1` on the host by default. Do not expose it on an untrusted network.
- Use a strong explicit `VNC_PASSWORD` before any non-loopback exposure.
- The workspace mount is read-write; expose only directories the desktop may modify.
- The persistent home volume contains authenticated browser and coding-agent state and is not encrypted by acld.
- Do not add Chromium `--no-sandbox` unless the container runtime prevents the normal browser sandbox from starting and the security tradeoff is explicitly accepted.

## Scope

This project is a minimal desktop launcher for local development and experimentation. GPU acceleration, Wayland compositors, and multi-container orchestration are out of scope.

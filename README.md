# hermes-adapter

The **Hermes Agent** runtime for the [Language Operator](https://github.com/language-operator/language-operator),
running as a native Kubernetes workload. [Hermes Agent](https://github.com/NousResearch/hermes-agent)
is Nous Research's open-source (MIT) self-improving agent.

It builds the runtime image and the Helm chart that registers the `hermes`
`LanguageAgentRuntime`.

Created from the [`opencode-adapter`](https://github.com/language-operator/opencode-adapter) template.

## Status

Bootstrapping. The image installs Hermes Agent and serves it in the browser terminal,
but config seeding from `/etc/agent/config.yaml` — model provider, MCP servers,
instructions — is not done yet; that, task mode and the final serving shape are
tracked in [#1](https://github.com/language-operator/hermes-adapter/issues/1).

## Architecture

The image is [`coding-runtime`](https://github.com/language-operator/coding-runtime)
plus Hermes Agent, installed from a pinned git tag into a venv at `/opt/hermes`. The
base owns the OS layer, the web terminal (xterm.js over a node-pty WebSocket bridge,
with a cross-origin guard and a 25s keepalive), `tini`, and the ETL that turns the
operator's `/etc/agent/config.yaml` into a normalized config. What lives here is the
three files that describe Hermes to it:

- **`runtime.json`** — the manifest: `HERMES_HOME` (`/workspace/.hermes`, on the
  workspace PVC), the serving surface, and how tmux launches Hermes.
- **`emit.mjs`** — the emitter: normalized config → Hermes's own files under
  `HERMES_HOME`. A stub that writes nothing until #1.
- **`launch-hermes.sh`** — what tmux runs: the `hermes` CLI, in the working directory
  the base has already chosen (the cloned repo when the agent sets `spec.repository`,
  else `/workspace`).

One container, running the base entrypoint: resolve the environment, seed config,
serve. tmux keeps the session alive across browser reconnects.

## Install

Prerequisite: the [`language-operator`](https://github.com/language-operator/language-operator)
chart must be installed first — it provides the `LanguageAgentRuntime` CRD.

```bash
helm install hermes oci://ghcr.io/language-operator/charts/hermes \
  --namespace language-operator
```

Then reference it from a `LanguageAgent`:

```yaml
apiVersion: langop.io/v1alpha1
kind: LanguageAgent
metadata:
  name: my-agent
spec:
  runtime: hermes
```

## Authentication

The runtime sets `auth.enabled: true`, so access is gated entirely by the cluster's
OIDC proxy: when the `LanguageCluster` has auth enabled the operator injects an
oauth2-proxy sidecar in front of the terminal. There is no built-in password — if
the cluster does not enable auth, the terminal is exposed unauthenticated on its
ingress.

## Development

```bash
make build      # docker build -t ghcr.io/language-operator/hermes-adapter:latest .
make test       # build, then run the coding-runtime conformance suite
make publish    # build and push the image to ghcr.io
make dev        # build, import into k3s, and upgrade the runtime release (inner loop)

helm lint chart
helm template hermes chart
```

## CI

- `build-image.yaml` — builds and pushes the image to `ghcr.io` on push to `main` and `v*` tags.
- `release-chart.yaml` — packages `chart/` and pushes it to `oci://ghcr.io/language-operator/charts`.
- `test.yaml` — builds the image, runs the `coding-runtime` conformance suite against
  it under the operator's posture (read-only root, uid 1000, all capabilities dropped),
  and lints/templates the chart on every PR. The suite is taken out of the image rather
  than fetched, so the checks always match the runtime being checked.

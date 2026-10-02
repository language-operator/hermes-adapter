# -----------------------------------------------------------------------------
# Hermes Agent adapter.
#
# The OS layer, the web terminal, tini, and the /etc/agent/config.yaml ETL all
# live in coding-runtime. What is left here is Hermes Agent (Nous Research) plus
# the three files that describe it to the base: a manifest, an emitter, and a
# launcher.
#
# The base is pinned by tag *and* digest. Never :latest, and never a `main`
# build — metadata-action stamps those with the version literal `main`, which no
# `requires.codingRuntime` range can satisfy, so every boot would warn about a
# version mismatch that is not real.
# -----------------------------------------------------------------------------
ARG BASE=ghcr.io/language-operator/coding-runtime:0.1.4@sha256:2f31ef9b04e72bec3a4bb79db59a82a4aa74f89538cfc118d75e0a852734b0aa
ARG HERMES_VERSION=v2026.9.24

FROM ${BASE}
ARG HERMES_VERSION

# Hermes Agent, from a git tag: PyPI lags the tagged releases. Installed into an
# image-owned venv on the base's Debian python3 (Hermes wants >=3.11,<3.14),
# never a uv-downloaded interpreter. Pinned — do not track `main`, so runtime
# behaviour is reproducible.
USER root
ENV UV_PYTHON_DOWNLOADS=never
RUN uv venv --python /usr/bin/python3 /opt/hermes \
    && uv pip install --python /opt/hermes/bin/python --no-cache \
        "hermes-agent @ git+https://github.com/NousResearch/hermes-agent@${HERMES_VERSION}" \
    && ln -s /opt/hermes/bin/hermes /usr/local/bin/hermes

# runtime.json  — what this adapter is: config dir, serving surface, tmux launch.
# emit.mjs      — normalized operator config -> Hermes's config (stub until #1).
# launch-hermes — what tmux runs inside the terminal.
COPY runtime.json /etc/coding-runtime/runtime.json
COPY emit.mjs /opt/adapter/emit.mjs
COPY --chmod=755 launch-hermes.sh /usr/local/bin/launch-hermes

# The operator pins the agent container to uid 1000 with no override, and the
# base already has a matching passwd entry. Do not create a user here.
USER node

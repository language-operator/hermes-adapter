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

# Hermes Agent, from a git tag: PyPI lags the tagged releases, and upstream
# refuses to build a wheel at all (setup.py guards bdist_wheel/sdist) because
# its bundled assets are resolved from the source-checkout layout. So this does
# what upstream's own image does: a checkout at /opt/hermes, its locked
# dependencies from uv.lock (hash-verified, --frozen), and Hermes itself as an
# editable install into /opt/hermes/.venv. Core dependencies only — no extras,
# and no Node web/TUI bundles: the default `hermes` interface is the classic
# Python CLI.
#
# On the base's Debian python3 (Hermes wants >=3.11,<3.14), never a
# uv-downloaded interpreter. Pinned — do not track `main`, so runtime behaviour
# is reproducible. /opt/hermes stays root-owned; the root filesystem is
# read-only at runtime, so nothing may try to write bytecode there.
USER root
ENV UV_PYTHON_DOWNLOADS=never \
    PYTHONDONTWRITEBYTECODE=1
RUN git clone --quiet --depth 1 --branch "${HERMES_VERSION}" \
        https://github.com/NousResearch/hermes-agent.git /opt/hermes \
    && cd /opt/hermes \
    && UV_PROJECT_ENVIRONMENT=/opt/hermes/.venv uv sync --frozen --no-dev --no-cache \
        --python /usr/bin/python3 \
    && rm -rf /opt/hermes/.git \
    && ln -s /opt/hermes/.venv/bin/hermes /usr/local/bin/hermes \
    && HERMES_HOME=/tmp/hermes-smoke hermes --version \
    && rm -rf /tmp/hermes-smoke

# runtime.json  — what this adapter is: config dir, serving surface, tmux launch.
# emit.mjs      — normalized operator config -> Hermes's config (stub until #1).
# launch-hermes — what tmux runs inside the terminal.
COPY runtime.json /etc/coding-runtime/runtime.json
COPY emit.mjs /opt/adapter/emit.mjs
COPY --chmod=755 launch-hermes.sh /usr/local/bin/launch-hermes

# The operator pins the agent container to uid 1000 with no override, and the
# base already has a matching passwd entry. Do not create a user here.
USER node

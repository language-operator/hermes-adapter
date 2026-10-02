#!/bin/sh
# What tmux runs. The base already starts tmux in the working directory (the
# cloned repo when the agent sets spec.repository, else /workspace), and
# HERMES_HOME comes from runtime.json, so Hermes's config, sessions and memory
# all land on the workspace PVC.
#
# Config is not yet seeded from /etc/agent/config.yaml — emit.mjs is a stub
# until issue #1 — and neither is resuming a slept agent's conversation.
set -eu

exec hermes "$@"

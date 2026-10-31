# Pocket Dogfight dedicated server (headless Godot, WebSocket transport).
# Works on Render or any Docker host. Listens on $PORT (default 8080).
FROM ubuntu:24.04
ARG GODOT_VERSION=4.3-stable
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /opt && mv /opt/Godot_v${GODOT_VERSION}_linux.x86_64 /opt/godot && chmod +x /opt/godot && rm /tmp/godot.zip
WORKDIR /app
COPY project.godot export_presets.cfg icon.svg default_bus_layout.tres ./
COPY scenes ./scenes
COPY scripts ./scripts
COPY resources ./resources
# Import once at build time so the first start is fast.
RUN /opt/godot --headless --path /app --import --quit || true
ENV PORT=8080 PD_TRANSPORT=websocket
EXPOSE 8080
CMD ["/bin/sh", "-c", "/opt/godot --headless --path /app -- --server --port=${PORT} --transport=websocket"]

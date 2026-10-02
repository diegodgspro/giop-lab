FROM debian:bookworm-slim

ARG GLPI_AGENT_VERSION=1.20
ARG GLPI_AGENT_DEB_SHA256=fd36518282f08d3ccd6bb728e8be98963ce2d41359308cef21f8e7976c4ad37b
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && curl -fsSL "https://github.com/glpi-project/glpi-agent/releases/download/${GLPI_AGENT_VERSION}/glpi-agent_${GLPI_AGENT_VERSION}-1_all.deb" -o /tmp/glpi-agent.deb \
 && echo "${GLPI_AGENT_DEB_SHA256}  /tmp/glpi-agent.deb" | sha256sum -c - \
 && apt-get install -y --no-install-recommends /tmp/glpi-agent.deb \
 && glpi-agent --version \
 && rm -f /tmp/glpi-agent.deb \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/glpi-agent-lab-entrypoint
RUN chmod 0755 /usr/local/bin/glpi-agent-lab-entrypoint
ENTRYPOINT ["/usr/local/bin/glpi-agent-lab-entrypoint"]

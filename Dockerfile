ARG webhook_go_version=2.13.0
ARG r10k_version=5.0.0-latest

FROM ghcr.io/voxpupuli/webhook-go:${webhook_go_version} AS webhook-go

FROM ghcr.io/voxpupuli/r10k:${r10k_version} AS r10k

COPY --from=webhook-go /webhook-go /usr/local/bin/webhook-go

EXPOSE 4000/tcp

ENTRYPOINT ["/usr/local/bin/webhook-go", "--config", "/etc/voxpupuli/webhook.yml", "server"]

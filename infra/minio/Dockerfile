FROM golang:1.24.8-bookworm AS server-build
WORKDIR /src
RUN git init && git remote add origin https://github.com/minio/minio.git \
    && git fetch --depth 1 origin 9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a \
    && git checkout --detach FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = 9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a \
    && CGO_ENABLED=0 GOTOOLCHAIN=local go build -mod=readonly -trimpath -o /out/minio .

FROM golang:1.24.8-bookworm AS client-build
WORKDIR /src
RUN git init && git remote add origin https://github.com/minio/mc.git \
    && git fetch --depth 1 origin 7394ce0dd2a80935aded936b09fa12cbb3cb8096 \
    && git checkout --detach FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = 7394ce0dd2a80935aded936b09fa12cbb3cb8096 \
    && CGO_ENABLED=0 GOTOOLCHAIN=local go build -mod=readonly -trimpath -o /out/mc .

FROM debian:bookworm-slim AS server
LABEL org.opencontainers.image.source="https://github.com/minio/minio" \
      org.opencontainers.image.revision="9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a" \
      org.opencontainers.image.licenses="AGPL-3.0-only"
COPY --from=server-build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=server-build /src/LICENSE /usr/share/doc/minio/LICENSE
COPY --from=server-build /src/NOTICE /usr/share/doc/minio/NOTICE
COPY --from=server-build /out/minio /usr/local/bin/minio
ENTRYPOINT ["/usr/local/bin/minio"]

FROM debian:bookworm-slim AS client
LABEL org.opencontainers.image.source="https://github.com/minio/mc" \
      org.opencontainers.image.revision="7394ce0dd2a80935aded936b09fa12cbb3cb8096" \
      org.opencontainers.image.licenses="AGPL-3.0-only"
COPY --from=client-build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=client-build /src/LICENSE /usr/share/doc/mc/LICENSE
COPY --from=client-build /out/mc /usr/local/bin/mc
ENTRYPOINT ["/usr/local/bin/mc"]

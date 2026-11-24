FROM python:3.13-alpine@sha256:9ef1a599f863231c3d91e941389bfdc4a2d6070557243d54df1a4e57015b960e
RUN apk add --no-cache curl openssl && addgroup -g 10001 push && adduser -D -u 10001 -G push push \
    && mkdir /state && chown 10001:10001 /state
WORKDIR /app
COPY --chown=10001:10001 server.py /app/server.py
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 NOTIFICATION_DB=/state/notifications.sqlite3
USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health',timeout=2).read()"]
CMD ["python", "/app/server.py"]

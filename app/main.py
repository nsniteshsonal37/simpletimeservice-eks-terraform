from datetime import datetime, timezone

from fastapi import FastAPI, Request

from observability import configure_observability

app = FastAPI()
configure_observability(app)


@app.get("/")
def read_root(request: Request):
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        ip = forwarded_for.split(",")[0].strip()
    else:
        ip = request.client.host

    stamp = datetime.now(timezone.utc).isoformat()
    return {"timestamp": stamp, "ip": ip}


@app.get("/health")
def health():
    return {"status": "ok"}
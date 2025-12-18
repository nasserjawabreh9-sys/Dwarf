from backend.app import app

@app.get("/")
def root():
    return {"status":"ok"}

@app.get("/healthz")
def healthz():
    return {"ok":True}

"""Minimal FastAPI dashboard for monitoring AstraForge."""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, Any

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates

if TYPE_CHECKING:
    from astraforge.core.engine import TradingEngine

TEMPLATES_DIR = Path(__file__).parent / "templates"


def create_app(engine: TradingEngine | None = None) -> FastAPI:
    app = FastAPI(title="AstraForge AI", version="1.0.0")
    templates = Jinja2Templates(directory=str(TEMPLATES_DIR))
    app.state.engine = engine

    @app.get("/api/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "app": "AstraForge AI"}

    @app.get("/api/status")
    async def api_status() -> JSONResponse:
        eng: TradingEngine | None = app.state.engine
        if eng is None:
            return JSONResponse({"error": "engine_not_ready"}, status_code=503)
        st = await eng.get_status_model()
        return JSONResponse(st.model_dump(mode="json"))

    @app.get("/api/trades")
    async def api_trades() -> JSONResponse:
        eng: TradingEngine | None = app.state.engine
        if eng is None:
            return JSONResponse({"trades": []})
        trades = await eng.state.recent_trades(50)
        return JSONResponse({"trades": [t.model_dump(mode="json") for t in trades]})

    @app.get("/api/equity")
    async def api_equity() -> JSONResponse:
        eng: TradingEngine | None = app.state.engine
        if eng is None:
            return JSONResponse({"points": []})
        points = await eng.state.equity_history(200)
        return JSONResponse({"points": [p.model_dump(mode="json") for p in points]})

    @app.get("/api/decisions")
    async def api_decisions() -> JSONResponse:
        eng: TradingEngine | None = app.state.engine
        if eng is None:
            return JSONResponse({"decisions": []})
        return JSONResponse({"decisions": await eng.state.recent_decisions(30)})

    @app.get("/", response_class=HTMLResponse)
    async def index(request: Request) -> Any:
        eng: TradingEngine | None = app.state.engine
        status: dict[str, Any] = {}
        if eng is not None:
            try:
                status = (await eng.get_status_model()).model_dump(mode="json")
            except Exception:  # noqa: BLE001
                status = {"error": "unavailable"}
        return templates.TemplateResponse(
            "index.html",
            {"request": request, "status": status},
        )

    return app


def main() -> None:
    import uvicorn
    from astraforge.core.config import get_settings

    settings = get_settings()
    app = create_app(None)
    uvicorn.run(app, host=settings.dashboard_host, port=settings.dashboard_port)


if __name__ == "__main__":
    main()

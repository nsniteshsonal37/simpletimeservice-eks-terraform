import logging
import os
from time import perf_counter

from fastapi import FastAPI, Request
from opentelemetry import _logs, trace
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor, ConsoleLogExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter


HEALTH_PATH = "/health"


def configure_observability(app: FastAPI) -> logging.Logger:
    service_name = os.getenv("OTEL_SERVICE_NAME", "simpletimeservice")
    resource = Resource.create({"service.name": service_name})
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")

    tracer_provider = TracerProvider(resource=resource)
    if otlp_endpoint:
        span_exporter = OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True)
    else:
        span_exporter = ConsoleSpanExporter()
    tracer_provider.add_span_processor(BatchSpanProcessor(span_exporter))
    trace.set_tracer_provider(tracer_provider)

    logger_provider = LoggerProvider(resource=resource)
    if otlp_endpoint:
        log_exporter = OTLPLogExporter(endpoint=otlp_endpoint, insecure=True)
    else:
        log_exporter = ConsoleLogExporter()
    logger_provider.add_log_record_processor(BatchLogRecordProcessor(log_exporter))
    _logs.set_logger_provider(logger_provider)

    LoggingInstrumentor().instrument(set_logging_format=True)

    app_logger = logging.getLogger("simpletimeservice")
    app_logger.setLevel(logging.INFO)
    app_logger.propagate = False
    if not any(isinstance(handler, LoggingHandler) for handler in app_logger.handlers):
        app_logger.addHandler(LoggingHandler(level=logging.INFO, logger_provider=logger_provider))

    # Disable uvicorn access logs so request logging comes only from the app middleware.
    uvicorn_access = logging.getLogger("uvicorn.access")
    uvicorn_access.handlers.clear()
    uvicorn_access.disabled = True
    uvicorn_access.propagate = False

    @app.middleware("http")
    async def request_logging_middleware(request: Request, call_next):
        if request.url.path == HEALTH_PATH:
            return await call_next(request)

        start = perf_counter()
        try:
            response = await call_next(request)
            status_code = response.status_code
        except Exception:
            status_code = 500
            elapsed_ms = (perf_counter() - start) * 1000
            app_logger.exception(
                "request failed",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": status_code,
                    "duration_ms": round(elapsed_ms, 2),
                    "client_ip": request.client.host if request.client else "unknown",
                },
            )
            raise

        elapsed_ms = (perf_counter() - start) * 1000
        app_logger.info(
            "request completed",
            extra={
                "method": request.method,
                "path": request.url.path,
                "status_code": status_code,
                "duration_ms": round(elapsed_ms, 2),
                "client_ip": request.client.host if request.client else "unknown",
            },
        )
        return response

    FastAPIInstrumentor.instrument_app(app, excluded_urls=HEALTH_PATH)
    return app_logger

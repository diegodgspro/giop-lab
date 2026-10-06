FROM python:3.13-slim
WORKDIR /service
COPY control-center/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10002 --create-home giop
COPY control-center/app ./app
COPY ai-assistant/giop_ai_contract ./giop_ai_contract
USER 10002
EXPOSE 8091
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8091", "--workers", "1", "--no-access-log"]

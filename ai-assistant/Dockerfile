FROM python:3.13-slim
WORKDIR /service
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10003 --create-home giop
COPY app ./app
COPY giop_ai_contract ./giop_ai_contract
COPY prompts ./prompts
USER 10003
EXPOSE 8092
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8092", "--workers", "1", "--no-access-log"]

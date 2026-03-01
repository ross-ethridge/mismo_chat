FROM pytorch/pytorch:2.7.0-cuda12.6-cudnn9-runtime

WORKDIR /app

RUN pip install --no-cache-dir --break-system-packages fastapi uvicorn diffusers transformers accelerate

COPY app.py .

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]

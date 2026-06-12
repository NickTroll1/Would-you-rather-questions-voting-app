FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install dependencies in a separate layer so code changes do not invalidate them.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Drop privileges before copying application code.
RUN useradd --create-home --shell /usr/sbin/nologin appuser
COPY app.py questions.json ./
COPY templates/ ./templates/
USER appuser

EXPOSE 8080

# Use a production WSGI server, not the Flask development server.	
CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:8080", "app:app"]


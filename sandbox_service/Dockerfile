FROM mcr.microsoft.com/playwright/python:v1.65.0-noble

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/home/pwuser \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

WORKDIR /srv/app
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app

# Never run Chromium as root and never disable Chromium's sandbox.
USER pwuser
EXPOSE 8787
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8787", "--no-access-log"]

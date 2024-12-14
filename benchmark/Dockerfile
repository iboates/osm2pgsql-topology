FROM python:3.12

COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

# COPY benchmark.py benchmark.py

ENTRYPOINT "python" "benchmark.py"
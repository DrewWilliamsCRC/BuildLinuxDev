FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    postgresql-client \
    libpq-dev \
    gcc \
    python3-dev && \
    rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create a startup script
COPY <<'EOF' /app/start.sh
#!/bin/bash
set -e

# Wait for database to be ready
until PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c '\q'; do
  echo "Postgres is unavailable - sleeping"
  sleep 1
done

echo "Postgres is up - executing command"

# Initialize database schema
PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
    CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        status VARCHAR(50) DEFAULT 'pending'
    );
    
    INSERT INTO tasks (title, description, status) 
    VALUES 
        ('Task 1', 'This is the first task', 'pending'),
        ('Task 2', 'This is the second task', 'in_progress')
    ON CONFLICT DO NOTHING;
EOSQL

# Start the application
exec gunicorn --bind 0.0.0.0:5000 --workers 3 --timeout 60 --access-logfile - --error-logfile - app:app
EOF

RUN chmod +x /app/start.sh

EXPOSE 5000

# Add a healthcheck
HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=5 \
    CMD curl -f http://localhost:5000/api/health || exit 1

# Use the startup script
CMD ["/app/start.sh"] 
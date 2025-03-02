from flask import Flask, jsonify
from flask_cors import CORS
import os
import psycopg2
import redis
import socket
import time
import logging
from psycopg2 import OperationalError
from contextlib import contextmanager

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Database configuration
DB_HOST = os.environ.get('POSTGRES_HOST', 'db')
DB_USER = os.environ.get('POSTGRES_USER', 'postgres')
DB_PASS = os.environ.get('POSTGRES_PASSWORD', 'postgres')
DB_NAME = os.environ.get('POSTGRES_DB', 'postgres')

# Redis configuration
REDIS_HOST = os.environ.get('REDIS_HOST', 'redis')

# Connection timeouts and retry settings
DB_TIMEOUT = 5  # seconds
REDIS_TIMEOUT = 5  # seconds
MAX_RETRIES = 5
RETRY_DELAY = 1  # seconds

@contextmanager
def get_db_connection():
    conn = None
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            connect_timeout=DB_TIMEOUT
        )
        conn.autocommit = True  # Ensure schema creation works
        yield conn
    except Exception as e:
        logger.error(f"Database connection error: {str(e)}")
        if conn is not None:
            conn.rollback()
        raise e
    finally:
        if conn is not None:
            conn.close()

def get_redis_connection():
    return redis.Redis(
        host=REDIS_HOST,
        port=6379,
        db=0,
        socket_timeout=REDIS_TIMEOUT,
        socket_connect_timeout=REDIS_TIMEOUT,
        retry_on_timeout=True,
        decode_responses=True
    )

def retry_operation(operation, max_retries=MAX_RETRIES, delay=RETRY_DELAY):
    last_error = None
    for attempt in range(max_retries):
        try:
            return operation()
        except Exception as e:
            last_error = e
            logger.warning(f"Retry attempt {attempt + 1}/{max_retries} failed: {str(e)}")
            if attempt < max_retries - 1:
                time.sleep(delay)
    logger.error(f"All retry attempts failed: {str(last_error)}")
    raise last_error

@app.route('/api/health')
def health_check():
    status = {
        'status': 'error',
        'services': {
            'database': 'error',
            'redis': 'error'
        }
    }
    
    # Check database connection
    try:
        def check_db():
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute('SELECT 1')
                    return True
        
        if retry_operation(check_db):
            status['services']['database'] = 'connected'
            logger.info("Database health check passed")
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Database health check failed: {error_msg}")
        status['services']['database'] = f'error: {error_msg}'
        return jsonify(status), 500
    
    # Check Redis connection
    try:
        def check_redis():
            redis_client = get_redis_connection()
            return redis_client.ping()
        
        if retry_operation(check_redis):
            status['services']['redis'] = 'connected'
            logger.info("Redis health check passed")
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Redis health check failed: {error_msg}")
        status['services']['redis'] = f'error: {error_msg}'
        return jsonify(status), 500
    
    # If we get here, all services are healthy
    status['status'] = 'healthy'
    return jsonify(status)

@app.route('/health')
def health_check_alt():
    return health_check()

@app.route('/api/tasks')
def get_tasks():
    try:
        def get_tasks_with_retry():
            # Try to get from Redis cache first
            redis_client = get_redis_connection()
            cached_tasks = redis_client.get('tasks')
            
            if cached_tasks:
                logger.debug("Returning cached tasks")
                return eval(cached_tasks)
            
            # If not in cache, get from database
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute('SELECT id, title, description, status FROM tasks')
                    tasks = []
                    for row in cur.fetchall():
                        tasks.append({
                            'id': row[0],
                            'title': row[1],
                            'description': row[2],
                            'status': row[3]
                        })
            
            # Cache the results
            redis_client.setex('tasks', 30, str(tasks))
            logger.debug("Tasks fetched from database and cached")
            return tasks
        
        tasks = retry_operation(get_tasks_with_retry)
        return jsonify(tasks)
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Error fetching tasks: {error_msg}")
        return jsonify({'error': error_msg}), 500

@app.route('/tasks')
def get_tasks_alt():
    return get_tasks()

if __name__ == '__main__':
    logger.info("Starting API server...")
    app.run(host='0.0.0.0', port=5000)
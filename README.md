# Linux Development Environment Setup

This Ansible project automates the setup of a Linux development environment with Docker, Python, and a sample Flask application.

## Prerequisites

- Ansible 2.9 or higher
- Python 3.x
- SSH access to target server
- Environment variables configured (see `.env.template`)

## Project Structure

```
.
├── .env                    # Environment variables (your configuration)
├── .env.template          # Template for environment variables
├── .gitignore            # Git ignore rules
├── .venv/                # Python virtual environment
├── README.md             # Project documentation
├── ansible.cfg           # Ansible configuration
├── docker-compose-demo/  # Sample application
│   ├── api/             # Flask API application
│   │   ├── app.py      # Main application code
│   │   ├── Dockerfile  # Python application container
│   │   └── requirements.txt
│   ├── docker-compose.yml
│   └── .env            # Docker environment variables
├── inventory/           # Ansible inventory
│   ├── group_vars/     # Group variables
│   │   └── all.yml    # Variables for all groups
│   └── hosts.ini      # Inventory file
├── playbooks/         # Ansible playbooks
│   └── main.yml      # Main playbook
├── requirements.txt   # Python dependencies
├── roles/            # Ansible roles
│   └── dev_environment/  # Development environment role
│       ├── defaults/    # Role default variables
│       │   └── main.yml
│       └── tasks/       # Role tasks
│           ├── main.yml          # Task orchestration
│           ├── python_bootstrap.yml  # Python setup
│           ├── ssh.yml           # SSH configuration
│           ├── python.yml        # Python packages
│           ├── docker.yml        # Docker setup
│           └── application.yml   # Application deployment
└── setup.sh          # Setup script
```

## Configuration

1. Copy `.env.template` to `.env` and fill in your values:
```bash
cp .env.template .env
```

2. Edit the environment variables in `.env`:
```
# Server Configuration
SERVER_IP=your_server_ip          # IP address of your target server
SSH_USERNAME=your_ssh_username    # SSH username for server access
SSH_PASSWORD=your_secure_password # SSH password (use strong password)
ANSIBLE_SUDO_PASS=your_sudo_password
SERVER_PORT=8080                  # Port for the Flask application

# Database Configuration
POSTGRES_USER=your_db_user
POSTGRES_PASSWORD=your_secure_db_password
POSTGRES_DB=your_db_name
POSTGRES_HOST=db                  # Leave as 'db' for Docker Compose

# Redis Configuration
REDIS_HOST=redis                  # Leave as 'redis' for Docker Compose

# Python Configuration
PYTHONPATH=/app
FLASK_APP=app.py
FLASK_ENV=development            # Change to 'production' for production
FLASK_DEBUG=1                    # Set to 0 for production
```

**Important Notes:**
1. All environment variables should be managed through the root `.env` file
2. Do not create additional `.env` files in subdirectories
3. Use strong passwords for all credential fields
4. The `.env` file is git-ignored for security
5. In production, consider using a secure secrets management system

## Usage

1. Run the setup script to prepare the environment:
```bash
./setup.sh
```

2. Run the playbook:
```bash
ansible-playbook -i inventory/hosts.ini playbooks/main.yml
```

The setup process will:
1. Install Python and required packages
2. Configure SSH keys and authentication
3. Install Docker and Docker Compose
4. Deploy the sample Flask application with PostgreSQL and Redis

## Application Components

The deployed application includes:
- Flask API (port 5000)
- PostgreSQL database (port 5432)
- Redis cache (port 6379)

### Available Endpoints

- `/health` or `/api/health` - System health check
- `/tasks` or `/api/tasks` - Task management API

## Health Checks

The deployment includes health checks for all services:
- Flask API: Checks application status
- PostgreSQL: Verifies database connectivity
- Redis: Ensures cache service is responsive

Monitor container health with:
```bash
docker ps
```

Access the API health endpoint:
```bash
curl http://localhost:5000/health
```

## Troubleshooting

1. If SSH connection fails:
   - Verify SSH key permissions (should be 600)
   - Check server IP and credentials in .env
   - Ensure target server is reachable
   - Verify SSH service is running on target

2. If containers fail to start:
   - Check Docker service status: `systemctl status docker`
   - Verify port availability: `netstat -tulpn`
   - Review container logs: `docker logs <container_name>`
   - Check disk space: `df -h`

3. If Python packages fail to install:
   - Verify Python version: `python3 --version`
   - Check pip installation: `pip3 --version`
   - Review pip logs: `pip3 install --verbose`

## License

MIT License

## Author

Your Name 
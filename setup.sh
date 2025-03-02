#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Check if Python and pip are available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 is not installed${NC}"
    exit 1
fi

# Install required Python packages
echo -e "${GREEN}Installing required Python packages...${NC}"
python3 -m pip install pyyaml ansible

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found. Please copy .env.template to .env and fill in your values.${NC}"
    exit 1
fi

# Source environment variables
set -a
source .env
set +a

# Create project structure
echo -e "${GREEN}Creating project structure...${NC}"
mkdir -p inventory/group_vars
mkdir -p playbooks
mkdir -p roles/dev_environment/{defaults,files,handlers,tasks,templates,vars}

# Create initial main.yml if it doesn't exist
if [ ! -f main.yml ]; then
    echo -e "${GREEN}Creating initial main.yml...${NC}"
    cat > main.yml << 'EOF'
---
- name: Ensure Python 3 is installed
  hosts: dev_server
  gather_facts: no
  become: yes
  tasks:
    - name: Debug connection variables
      raw: echo "Connected successfully to {{ inventory_hostname }} as {{ ansible_user }}"
      register: debug_connection
      changed_when: false
      check_mode: no

- name: Configure Development Environment
  hosts: dev_server
  become: yes
  become_method: sudo
  gather_facts: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600
EOF
fi

# Create initial inventory.ini if it doesn't exist
if [ ! -f inventory/hosts.ini ]; then
    echo -e "${GREEN}Creating initial inventory.ini...${NC}"
    cat > inventory/hosts.ini << EOF
[dev_server]
${SERVER_IP}
EOF
fi

# Move existing files to their new locations
echo -e "${GREEN}Moving files to their new locations...${NC}"
cp main.yml playbooks/ 2>/dev/null || :
cp inventory.ini inventory/hosts.ini 2>/dev/null || :

# Create ansible.cfg
echo -e "${GREEN}Creating ansible.cfg...${NC}"
cat > ansible.cfg << EOF
[defaults]
inventory = inventory/hosts.ini
remote_user = ${SSH_USERNAME}
host_key_checking = False
roles_path = roles
interpreter_python = auto_silent

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
EOF

# Create group_vars/all.yml
echo -e "${GREEN}Creating group variables...${NC}"
cat > inventory/group_vars/all.yml << EOF
---
# Connection and Authentication
ansible_host: "{{ lookup('env', 'SERVER_IP') }}"
ansible_user: "{{ lookup('env', 'SSH_USERNAME') }}"
ansible_password: "{{ lookup('env', 'SSH_PASSWORD') }}"
ansible_become: yes
ansible_become_method: sudo
ansible_become_pass: "{{ lookup('env', 'ANSIBLE_SUDO_PASS') }}"

# Additional Variables
server_ip: "{{ lookup('env', 'SERVER_IP') }}"
ssh_username: "{{ lookup('env', 'SSH_USERNAME') }}"
ssh_password: "{{ lookup('env', 'SSH_PASSWORD') }}"
EOF

# Create role structure
echo -e "${GREEN}Setting up role structure...${NC}"

# Create main role tasks
cat > roles/dev_environment/tasks/main.yml << EOF
---
- name: Include Python setup tasks
  import_tasks: python.yml

- name: Include Docker setup tasks
  import_tasks: docker.yml

- name: Include application setup tasks
  import_tasks: application.yml
EOF

# Create initial task files
for task_file in python.yml docker.yml application.yml python_bootstrap.yml; do
    touch "roles/dev_environment/tasks/${task_file}"
done

# Update main playbook to use role
cat > playbooks/main.yml << EOF
---
- name: Ensure Python 3 is installed
  hosts: dev_server
  gather_facts: no
  become: yes
  tasks:
    - import_tasks: "{{ playbook_dir }}/../roles/dev_environment/tasks/python_bootstrap.yml"

- name: Configure Development Environment
  hosts: dev_server
  become: yes
  roles:
    - dev_environment
EOF

# Make setup script executable
chmod +x setup.sh

echo -e "${GREEN}Setup complete! You can now run:${NC}"
echo -e "To load environment variables and run the playbook:"
echo -e "${GREEN}set -a; source .env; set +a; ansible-playbook -i inventory/hosts.ini playbooks/main.yml${NC}"
echo -e "\nOr if you prefer to enter the sudo password manually:"
echo -e "${GREEN}ansible-playbook -i inventory/hosts.ini playbooks/main.yml --ask-become-pass${NC}" 
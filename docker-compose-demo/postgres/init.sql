-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'pending'
);

-- Insert some initial tasks
INSERT INTO tasks (title, description, status) VALUES
    ('Learn Docker', 'Learn Docker and container orchestration', 'pending'),
    ('Master Ansible', 'Learn Ansible for automation', 'in_progress'),
    ('Build CI/CD Pipeline', 'Create a complete CI/CD workflow', 'pending')
ON CONFLICT DO NOTHING; 
#!/bin/bash

# 更新系统包
echo "正在更新系统包..."
apt-get update
apt-get upgrade -y

# 安装必要的系统包
echo "正在安装必要的系统包..."
apt-get install -y python3.11 python3.11-venv python3-pip postgresql postgresql-contrib nginx supervisor

# 创建项目目录
echo "正在创建项目目录..."
mkdir -p /var/www/dreameducation
mkdir -p /var/log/dreameducation
chown -R www-data:www-data /var/www/dreameducation
chown -R www-data:www-data /var/log/dreameducation

# 配置PostgreSQL
echo "正在配置数据库..."
sudo -u postgres psql -c "CREATE DATABASE dreameducation;"
sudo -u postgres psql -c "CREATE USER dreameducation_user WITH PASSWORD 'your_db_password';"
sudo -u postgres psql -c "ALTER ROLE dreameducation_user SET client_encoding TO 'utf8';"
sudo -u postgres psql -c "ALTER ROLE dreameducation_user SET default_transaction_isolation TO 'read committed';"
sudo -u postgres psql -c "ALTER ROLE dreameducation_user SET timezone TO 'UTC';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE dreameducation TO dreameducation_user;"

# 配置Nginx
echo "正在配置Nginx..."
cat > /etc/nginx/sites-available/dreameducation << EOF
server {
    listen 80;
    server_name your_domain.com;

    location /static/ {
        alias /var/www/dreameducation/static/;
    }

    location /media/ {
        alias /var/www/dreameducation/media/;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# 启用站点配置
ln -s /etc/nginx/sites-available/dreameducation /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# 配置Supervisor
echo "正在配置Supervisor..."
cat > /etc/supervisor/conf.d/dreameducation.conf << EOF
[program:dreameducation]
directory=/var/www/dreameducation
command=/var/www/dreameducation/venv/bin/gunicorn DreamEducation.wsgi:application --workers 3 --bind 127.0.0.1:8000
user=www-data
autostart=true
autorestart=true
stderr_logfile=/var/log/dreameducation/gunicorn.err.log
stdout_logfile=/var/log/dreameducation/gunicorn.out.log
EOF

# 重启服务
echo "正在重启服务..."
systemctl restart nginx
supervisorctl reread
supervisorctl update
supervisorctl restart dreameducation

echo "服务器初始化完成！" 
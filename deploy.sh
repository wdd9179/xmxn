#!/bin/bash

# 检查是否提供了必要的参数
if [ "$#" -ne 2 ]; then
    echo "使用方法: $0 <服务器IP> <域名>"
    exit 1
fi

SERVER_IP=$1
DOMAIN_NAME=$2

echo "开始部署项目到服务器 $SERVER_IP ..."

# 创建生产环境配置文件
echo "正在创建生产环境配置文件..."
cat > DreamEducation/DreamEducation/settings_prod.py << EOF
from .settings import *

DEBUG = False
ALLOWED_HOSTS = ['$DOMAIN_NAME']

# 数据库配置
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'dreameducation',
        'USER': 'dreameducation_user',
        'PASSWORD': 'your_db_password',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

# 静态文件配置
STATIC_ROOT = '/var/www/dreameducation/static'
MEDIA_ROOT = '/var/www/dreameducation/media'

# 安全设置
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True

# 日志配置
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': 'ERROR',
            'class': 'logging.FileHandler',
            'filename': '/var/log/dreameducation/error.log',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'ERROR',
            'propagate': True,
        },
    },
}
EOF

# 复制服务器初始化脚本到服务器
echo "正在复制初始化脚本到服务器..."
scp server_setup.sh root@$SERVER_IP:/root/

# 在服务器上执行初始化脚本
echo "正在服务器上执行初始化脚本..."
ssh root@$SERVER_IP "bash /root/server_setup.sh"

# 部署项目代码
echo "正在部署项目代码..."
ssh root@$SERVER_IP << EOF
cd /var/www/dreameducation
git clone https://github.com/wdd9179/xmxn.git .
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install gunicorn psycopg2-binary

# 收集静态文件
python manage.py collectstatic --noinput --settings=DreamEducation.settings_prod

# 执行数据库迁移
python manage.py migrate --settings=DreamEducation.settings_prod

# 创建超级用户
echo "创建超级用户..."
python manage.py createsuperuser --settings=DreamEducation.settings_prod

# 设置文件权限
sudo chown -R www-data:www-data /var/www/dreameducation
sudo chown -R www-data:www-data /var/log/dreameducation

# 重启服务
sudo supervisorctl restart dreameducation
sudo systemctl restart nginx
EOF

echo "部署完成！"
echo "请访问 http://$DOMAIN_NAME 检查网站是否正常运行" 
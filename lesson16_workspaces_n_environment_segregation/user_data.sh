#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install nginx
apt-get install -y nginx

# Create custom index page
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Workspace Lab - ${workspace}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 2.5em; margin-bottom: 20px; }
        .info { background: rgba(255,255,255,0.2); padding: 15px; border-radius: 5px; margin: 10px 0; }
        .label { font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 OpenTofu Workspace Lab</h1>
        <div class="info">
            <span class="label">Environment:</span> ${workspace}
        </div>
        <div class="info">
            <span class="label">Instance:</span> ${instance_index} of ${instance_count}
        </div>
        <div class="info">
            <span class="label">Hostname:</span> $(hostname)
        </div>
        <div class="info">
            <span class="label">Private IP:</span> $(hostname -I | awk '{print $1}')
        </div>
        <div class="info">
            <span class="label">Timestamp:</span> $(date)
        </div>
    </div>
</body>
</html>
EOF

# Start nginx
systemctl enable nginx
systemctl start nginx
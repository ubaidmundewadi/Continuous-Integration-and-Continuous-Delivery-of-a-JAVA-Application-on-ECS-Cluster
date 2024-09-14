# Reference existing key pair
variable "key_name" {
  default = "vprofile-prod-key" # Replace with the name of your existing key pair
}

# Create Security Group for Jenkins
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins server"

  ingress {
    description = "Allow SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["<YOUR_IP>/32"]  # Replace with your IP
  }

  ingress {
    description = "Allow Jenkins (HTTP) from my IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["<YOUR_IP>/32"]  # Replace with your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}

# Create Security Group for SonarQube
resource "aws_security_group" "sonar_sg" {
  name        = "sonarqube-sg"
  description = "Security group for SonarQube server"

  ingress {
    description = "Allow HTTP (SonarQube) from my IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["<YOUR_IP>/32"]  # Replace with your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sonarqube-sg"
  }
}



# Jenkins EC2 Instance
resource "aws_instance" "jenkins_server" {
  ami                    = "ami-0a0e5d9c7acc336f1" # Ubuntu 22.04 LTS (replace with correct AMI ID)
  instance_type          = "t2.small"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  tags = {
    Name = "jenkins-server"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    sudo apt install openjdk-11-jdk -y
    sudo apt install maven wget unzip -y
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update
    sudo apt-get install jenkins -y
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl -y
    sudo install -m 0755 -d /etc/apt/keyrings -y
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    sudo apt install awscli -y
  EOF
}

# SonarQube EC2 Instance
resource "aws_instance" "sonar_server" {
  ami                    = "ami-0a0e5d9c7acc336f1" # Ubuntu 22.04 LTS AMI (replace with correct AMI ID)
  instance_type          = "t2.medium"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.sonar_sg.id]

  tags = {
    Name = "sonar-server"
  }

  user_data = <<-EOF
    #!/bin/bash
    cp /etc/sysctl.conf /root/sysctl.conf_backup
    cat <<EOT> /etc/sysctl.conf
    vm.max_map_count=262144
    fs.file-max=65536
    ulimit -n 65536
    ulimit -u 4096
    EOT
    cp /etc/security/limits.conf /root/sec_limit.conf_backup
    cat <<EOT> /etc/security/limits.conf
    sonarqube   -   nofile   65536
    sonarqube   -   nproc    409
    EOT

    sudo apt-get update -y
    sudo apt-get install openjdk-11-jdk -y
    sudo update-alternatives --config java

    java -version

    sudo apt update
    wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -

    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
    sudo apt install postgresql postgresql-contrib -y
    #sudo -u postgres psql -c "SELECT version();"
    sudo systemctl enable postgresql.service
    sudo systemctl start  postgresql.service
    sudo echo "postgres:admin123" | chpasswd
    runuser -l postgres -c "createuser sonar"
    sudo -i -u postgres psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'admin123';"
    sudo -i -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
    sudo -i -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube to sonar;"
    systemctl restart  postgresql
    #systemctl status -l   postgresql
    netstat -tulpena | grep postgres
    sudo mkdir -p /sonarqube/
    cd /sonarqube/
    sudo curl -O https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-8.3.0.34182.zip
    sudo apt-get install zip -y
    sudo unzip -o sonarqube-8.3.0.34182.zip -d /opt/
    sudo mv /opt/sonarqube-8.3.0.34182/ /opt/sonarqube
    sudo groupadd sonar
    sudo useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
    sudo chown sonar:sonar /opt/sonarqube/ -R
    cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup
    cat <<EOT> /opt/sonarqube/conf/sonar.properties
    sonar.jdbc.username=sonar
    sonar.jdbc.password=admin123
    sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
    sonar.web.host=0.0.0.0
    sonar.web.port=9000
    sonar.web.javaAdditionalOpts=-server
    sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
    sonar.log.level=INFO
    sonar.path.logs=logs
    EOT

    cat <<EOT> /etc/systemd/system/sonarqube.service
    [Unit]
    Description=SonarQube service
    After=syslog.target network.target

    [Service]
    Type=forking

    ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
    ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

    User=sonar
    Group=sonar
    Restart=always

    LimitNOFILE=65536
    LimitNPROC=4096


    [Install]
    WantedBy=multi-user.target
    EOT

    systemctl daemon-reload
    systemctl enable sonarqube.service
    #systemctl start sonarqube.service
    #systemctl status -l sonarqube.service
    apt-get install nginx -y
    rm -rf /etc/nginx/sites-enabled/default
    rm -rf /etc/nginx/sites-available/default
    cat <<EOT> /etc/nginx/sites-available/sonarqube
    server{
        listen      80;
        server_name sonarqube.groophy.in;

        access_log  /var/log/nginx/sonar.access.log;
        error_log   /var/log/nginx/sonar.error.log;

        proxy_buffers 16 64k;
        proxy_buffer_size 128k;

        location / {
            proxy_pass  http://127.0.0.1:9000;
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
            proxy_redirect off;
                  
            proxy_set_header    Host            \$host;
            proxy_set_header    X-Real-IP       \$remote_addr;
            proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header    X-Forwarded-Proto http;
        }
    }
    EOT
    ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
    systemctl enable nginx.service
    #systemctl restart nginx.service
    sudo ufw allow 80,9000,9001/tcp

    echo "System reboot in 30 sec"
    sleep 30
    reboot
  EOF
}

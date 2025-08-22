# fail2ban-setup
Fail2ban 一键安装配置脚本

## 安装（默认 22 端口）
```
curl -sL https://raw.githubusercontent.com/yahuisme/fail2ban-setup/main/script.sh | sudo bash
```

## 指定端口（同时对 22 和指定端口生效）
```
curl -sL https://raw.githubusercontent.com/yahuisme/fail2ban-setup/main/script.sh | sudo bash -s -- -p 12345
```

## 手动解封
```
sudo fail2ban-client set sshd unbanip <IP 地址>
```

## 查看封禁列表
```
sudo fail2ban-client status sshd
```

# 启动说明

本文档记录在 **WSL2 + Docker** 环境下运行 Reactive Resume 的正确步骤及常见问题处理。

## 两种运行方式

| 方式 | 适用场景 | compose 文件 |
|------|----------|-------------|
| Docker 完整部署 | 直接运行，无需本地 Node.js | `compose.yml` |
| 本地开发模式 | 需要修改源码、热更新 | `compose.dev.yml` + `vp dev` |

---

## 方式一：Docker 完整部署（推荐）

所有服务（包括 app）都在 Docker 内运行，访问 `http://localhost:3000` 即可。

### 首次启动

```bash
# 1. 进入项目目录
cd /root/workspace/typescript/reactive-resume

# 2. 启动所有服务
sudo docker compose up -d

# 3. 等待约 30 秒后检查状态
sudo docker ps
```

### WSL2 网络问题修复

在 WSL2 环境下，`reactive_resume` 容器有时不会自动加入 Docker 内部网络，导致无法解析 `postgres`、`seaweedfs` 等服务名。

**症状**：日志中出现 `getaddrinfo EAI_AGAIN postgres` 错误，健康检查持续失败。

**修复步骤**：

```bash
# 手动将 app 容器连接到内部网络
sudo docker network connect reactive_resume_default reactive_resume-reactive_resume-1

# 重启 app 容器使其重新连接数据库
sudo docker restart reactive_resume-reactive_resume-1

# 等待约 20 秒，检查是否变为 healthy
sudo docker ps
```

### 重启（日常使用）

```bash
# 完整重启（推荐，避免网络问题）
sudo docker compose down && sudo docker compose up -d
```

> **注意**：不要只 `docker compose down` 不重启，也不要在已有容器的情况下再次 `up -d`，这会导致容器网络状态不一致。

---

## 方式二：本地开发模式

仅用 Docker 运行基础服务，app 本身在宿主机上以 `vp dev` 运行（支持热更新）。

### 前提条件

- Docker 已启动
- 已安装 Node.js 和 pnpm

### 首次启动

```bash
# 1. 启动基础服务（PostgreSQL + Browserless）
sudo docker compose -f compose.dev.yml up -d postgres browserless

# 2. 获取 Docker 网关 IP（用于 PRINTER_APP_URL）
sudo docker network inspect reactive_resume_default \
  --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}'
# 通常输出：172.18.0.1

# 3. 创建 .env 文件（仅首次）
cp .env.example .env
# 修改 PRINTER_APP_URL 为上面获取的网关 IP，例如：
# PRINTER_APP_URL="http://172.18.0.1:3000"

# 4. 安装依赖（仅首次或 pnpm-lock.yaml 有变更时）
pnpm install

# 5. 启动开发服务器
node_modules/.bin/vp dev
# 或者如果已全局安装 vp：vp dev
```

### 日常启动

```bash
# 确认基础服务正在运行
sudo docker compose -f compose.dev.yml up -d postgres browserless

# 启动 app
node_modules/.bin/vp dev
```

---

## 常见问题

### 端口 3000 被占用

```bash
# 查找并杀掉占用进程
kill $(lsof -ti:3000)
```

### 数据库迁移失败（ECONNREFUSED 127.0.0.1:5432）

- **Docker 完整部署**：参考上方"WSL2 网络问题修复"
- **本地开发模式**：确认 `docker compose -f compose.dev.yml up -d postgres` 已执行，且 `DATABASE_URL` 指向 `localhost:5432`

### 健康检查 - printer unhealthy

Browserless 连接超时不影响页面正常访问，只影响 PDF 导出功能。确认 `PRINTER_ENDPOINT` 配置正确即可。

### 查看 app 日志

```bash
# Docker 完整部署
sudo docker logs reactive_resume-reactive_resume-1 -f

# 查看所有容器状态
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

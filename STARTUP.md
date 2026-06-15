# 本地启动教程

本文档介绍在本机(以 **WSL2 + Docker** 为参考环境)运行本项目的步骤。

**基础设施统一使用公共组件 `/root/workspace/env/my-docker-config`** 提供的 PostgreSQL,本项目自身只需额外起一个 Browserless(用于 PDF 导出)。

> 包管理器:本项目强制使用 **pnpm**(`preinstall` 钩子已通过 `only-allow` 拦截 npm/yarn)。

---

## 目录

- [前置依赖](#前置依赖)
- [快速启动(推荐)](#快速启动推荐)
- [备选:本项目自带 compose.dev.yml](#备选本项目自带-composedevyml)
- [备选:Docker 完整部署](#备选docker-完整部署)
- [常见问题](#常见问题)
- [常用命令速查](#常用命令速查)

---

## 前置依赖

| 依赖             | 版本要求                               | 说明                                    |
| ---------------- | -------------------------------------- | --------------------------------------- |
| Node.js          | ≥ 20                                   | 推荐 22 LTS                             |
| pnpm             | 10.33.0(由 `packageManager` 锁定)      | 通过 corepack 自动启用即可              |
| Docker           | 任意较新版本                           | 公共组件和 Browserless 都在 Docker 里跑 |
| 公共基础设施仓库 | `/root/workspace/env/my-docker-config` | 提供 `infra-postgres` 等共享服务        |

启用 corepack 让 pnpm 按 `package.json` 锁定版本运行:

```bash
corepack enable
```

---

## 快速启动(推荐)

整体流程:**起公共 PostgreSQL → 建库 → 起本项目专用 Browserless → 配 .env → pnpm install → vp dev**。

### 1. 启动公共 PostgreSQL

通过 my-docker-config 的 `infra-up` 命令启动:

```bash
# 加载基础设施管理脚本(若未永久加载)
source /root/workspace/env/my-docker-config/infra/scripts/infra.sh

# 启动 postgres(profile: postgres)
infra-up postgres

# 验证状态
infra-status
```

公共组件默认使用以下凭据(见 `my-docker-config/infra/.env.example`):

- 用户名:`postgres`
- 密码:`root123`
- 端口:`localhost:5432`
- 网络:`infra_infra_net`,网关 `172.20.0.1`

### 2. 在 infra-postgres 中创建本项目数据库

```bash
sudo docker exec infra-postgres psql -U postgres -c "CREATE DATABASE reactive_resume;"
```

> 已存在则 `psql: ERROR: database "reactive_resume" already exists`,可忽略。

### 3. 启动 Browserless(本项目专用)

公共组件不包含 Browserless,这里单独起一个,**接到同一个 `infra_infra_net` 网络**,这样后续 PDF 导出时容器之间网络可达:

```bash
sudo docker run -d \
  --name reactive-browserless \
  --network infra_infra_net \
  -p 4000:3000 \
  -e TOKEN=1234567890 \
  -e CONCURRENT=10 \
  ghcr.io/browserless/chromium:latest
```

健康检查:

```bash
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:4000/?token=1234567890"
# 200 或 404 都说明服务在跑(404 是根路径默认行为)
```

### 4. 配置 `.env`

```bash
cp .env.example .env  # 仅首次
```

修改以下三项,使其指向公共 PostgreSQL 和本地 Browserless:

```dotenv
APP_URL="http://localhost:3000"
PRINTER_APP_URL="http://172.20.0.1:3000"
PRINTER_ENDPOINT="ws://localhost:4000?token=1234567890"
DATABASE_URL="postgresql://postgres:root123@localhost:5432/reactive_resume"
```

要点:

- **密码用 `root123`**(对齐公共组件,而不是 `.env.example` 默认的 `postgres`)。
- **库名用 `reactive_resume`**(步骤 2 已新建,避免污染公共 `postgres` 库)。
- **`PRINTER_APP_URL` 用 `172.20.0.1`**(`infra_infra_net` 的网关 IP),Browserless 容器通过它回访宿主机上的 app。如果你的网络不同,可以重新查询:
  ```bash
  sudo docker network inspect infra_infra_net \
    --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}'
  ```
- `STORAGE_*`、`MAIL_*` 等其他字段留空即可(自动回退本地文件系统 + 控制台日志邮件)。

### 5. 安装依赖

```bash
pnpm install
```

> 不要用 `npm install` 或 `yarn`,会被 `preinstall` 钩子拒绝。

### 6. 启动开发服务器

```bash
pnpm exec vp dev
```

启动后:

- 访问 [http://localhost:3000](http://localhost:3000)
- 首次启动时,Drizzle 迁移会通过 Nitro 插件自动执行(日志会出现 `Database migrations completed`)

### 日常重启

```bash
# 确认公共服务在运行(若已永久加载 infra.sh,可省略 source)
infra-up postgres
sudo docker start reactive-browserless

# 启动 app
pnpm exec vp dev
```

### 停止

```bash
# Ctrl+C 停 vp dev
sudo docker stop reactive-browserless
# 公共 postgres 是否停掉视你是否还需要它而定:
infra-down postgres   # 仅停 postgres
# 或保持运行,供其他项目共用
```

---

## 备选:本项目自带 compose.dev.yml

如果不想引入公共组件,也可以用本项目根目录的 `compose.dev.yml`,它会创建本项目专属的 postgres + browserless:

```bash
sudo docker compose -f compose.dev.yml up -d postgres browserless
```

注意此方式与公共 `infra-postgres` 在 5432 端口冲突,**两者只能选其一**。`.env` 的 `DATABASE_URL` 也需相应改回 `postgresql://postgres:postgres@localhost:5432/postgres`。

---

## 备选:Docker 完整部署

适合不需要改代码、只想试用的场景。所有服务(包括 app)都在 Docker 内。

```bash
sudo docker compose up -d
# 等待约 30 秒后访问 http://localhost:3000
sudo docker ps
```

### WSL2 网络问题修复

WSL2 下 app 容器有时不会自动加入 Docker 内部网络,导致无法解析 `postgres`/`seaweedfs` 等服务名。

**症状**:日志中出现 `getaddrinfo EAI_AGAIN postgres`,健康检查持续失败。

**修复**:

```bash
sudo docker network connect reactive_resume_default reactive_resume-reactive_resume-1
sudo docker restart reactive_resume-reactive_resume-1
```

---

## 常见问题

### 5432 端口被占用 / `Bind for 0.0.0.0:5432 failed`

通常是公共 `infra-postgres` 已在跑。解决办法:**不要再启动本项目的 postgres**,直接复用公共组件(见快速启动方式)。

### `password authentication failed for user "postgres"`

`.env` 的 `DATABASE_URL` 密码与公共组件不一致。公共组件使用 `root123`,而 `.env.example` 默认是 `postgres`。改成:

```dotenv
DATABASE_URL="postgresql://postgres:root123@localhost:5432/reactive_resume"
```

### `database "reactive_resume" does not exist`

执行步骤 2 创建数据库。

### `pnpm install` 报错 "Use pnpm"

说明你用了 npm 或 yarn。本项目通过 `preinstall: npx only-allow pnpm` 强制 pnpm:

```bash
corepack enable
pnpm install
```

### 健康检查显示 `printer unhealthy` / PDF 导出失败

- 确认 `PRINTER_APP_URL` 用的是 **`infra_infra_net` 网关 IP**(默认 `172.20.0.1`),而不是 `localhost`。
- 确认 `PRINTER_ENDPOINT` 端口是 Browserless 对外的 4000(`ws://localhost:4000?token=1234567890`)。
- 确认 Browserless 接到了 `infra_infra_net` 网络:`sudo docker inspect reactive-browserless --format '{{json .NetworkSettings.Networks}}'`。

### 邮箱验证

开发环境下邮箱验证邮件会打印到 `vp dev` 控制台。注册后点击页面上的「Continue」即可跳过验证流程。

### 端口 3000 被占用

```bash
kill $(lsof -ti:3000)
```

---

## 常用命令速查

| 任务               | 命令                                                   |
| ------------------ | ------------------------------------------------------ |
| 启动公共 postgres  | `infra-up postgres`                                    |
| 停止公共 postgres  | `infra-down postgres`                                  |
| 进入 postgres 终端 | `sudo docker exec -it infra-postgres psql -U postgres` |
| 启动 Browserless   | `sudo docker start reactive-browserless`               |
| 安装依赖           | `pnpm install`                                         |
| 添加依赖           | `pnpm add <pkg>`                                       |
| 启动开发服务器     | `pnpm exec vp dev`                                     |
| 类型检查           | `pnpm typecheck`                                       |
| 单元测试           | `pnpm exec vp test`                                    |
| Lint + 格式 + 类型 | `pnpm exec vp check`                                   |
| 数据库迁移生成     | `pnpm db:generate`                                     |
| 数据库迁移执行     | `pnpm db:migrate`                                      |
| 数据库可视化       | `pnpm db:studio`                                       |
| 生产构建           | `pnpm exec vp build`                                   |
| 启动生产服务       | `pnpm start`                                           |

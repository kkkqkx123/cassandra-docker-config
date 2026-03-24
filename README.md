# Apache Cassandra Docker 部署指南

## 📖 概述

本文档提供在 Windows 环境下使用 Docker 部署 Apache Cassandra 的完整指南。

---

## 🏷️ 镜像信息

### 官方镜像
- **镜像名称**: `cassandra:latest`
- **Docker Hub**: https://hub.docker.com/_/cassandra
- **已本地存在**: ✅ 是

### Bitnami 镜像 (可选)
- **镜像名称**: `bitnami/cassandra:latest`
- **Docker Hub**: https://hub.docker.com/r/bitnami/cassandra
- **特点**: 提供更多可配置环境变量，支持认证、加密等企业级功能

---

## 🔌 端口说明

| 端口 | 协议 | 说明 |
|------|------|------|
| 9042 | TCP | CQL 查询端口 (客户端连接) |
| 7000 | TCP | 节点间通信端口 (集群 Gossip) |
| 7199 | TCP | JMX 监控端口 |
| 9160 | TCP | Thrift RPC 端口 (已废弃，可选) |

---

## 📁 数据卷挂载

### 官方镜像推荐挂载点

| 容器内路径 | 说明 |
|------------|------|
| `/var/lib/cassandra/data` | 数据文件 |
| `/var/lib/cassandra/commitlog` | 提交日志 |
| `/var/lib/cassandra/saved_caches` | 缓存文件 |
| `/etc/cassandra` | 配置文件 (可选) |

### Bitnami 镜像推荐挂载点

| 容器内路径 | 说明 |
|------------|------|
| `/bitnami/cassandra` | 数据持久化根目录 |
| `/docker-entrypoint-initdb.d` | 初始化脚本目录 |

---

## ⚙️ 环境变量配置

### 官方镜像环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `CASSANDRA_CLUSTER_NAME` | 集群名称 (所有节点必须相同) | `Test Cluster` |
| `CASSANDRA_LISTEN_ADDRESS` | 监听传入连接的 IP | 容器 IP |
| `CASSANDRA_BROADCAST_ADDRESS` | 向其他节点广播的 IP | 同 LISTEN_ADDRESS |
| `CASSANDRA_RPC_ADDRESS` | Thrift RPC 绑定地址 | `0.0.0.0` |
| `CASSANDRA_START_RPC` | 是否启动 Thrift RPC | `false` |
| `CASSANDRA_SEEDS` | 种子节点 IP 列表 (逗号分隔) | - |
| `CASSANDRA_NUM_TOKENS` | 虚拟节点令牌数 | `256` |
| `CASSANDRA_DC` | 数据中心名称 | - |
| `CASSANDRA_RACK` | 机架名称 | - |
| `CASSANDRA_ENDPOINT_SNITCH` | 端点嗅探实现 | `SimpleSnitch` |
| `MAX_HEAP_SIZE` | JVM 最大堆大小 | `512M` |
| `HEAP_NEWSIZE` | JVM 新生代大小 | `100M` |

### Bitnami 镜像额外环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `CASSANDRA_USER` | 数据库用户名 | `cassandra` |
| `CASSANDRA_PASSWORD` | 数据库密码 | - |
| `ALLOW_EMPTY_PASSWORD` | 允许空密码 | `no` |
| `CASSANDRA_DATACENTER` | 数据中心名称 | `dc1` |
| `CASSANDRA_INTERNODE_ENCRYPTION` | 节点间加密 | `none` |
| `CASSANDRA_CLIENT_ENCRYPTION` | 客户端加密 | `false` |

---

## 🚀 快速启动

### 单节点部署

```powershell
# 使用官方镜像
docker run -d --name cassandra `
  -p 9042:9042 `
  -v ${PWD}/data:/var/lib/cassandra/data `
  -v ${PWD}/commitlog:/var/lib/cassandra/commitlog `
  -v ${PWD}/saved_caches:/var/lib/cassandra/saved_caches `
  -e CASSANDRA_CLUSTER_NAME=MyCluster `
  cassandra:latest
```

### 使用 docker-compose

```powershell
# 启动
docker-compose up -d

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 停止
docker-compose down
```

---

## 🔍 连接与测试

### 使用 cqlsh 连接

```powershell
# 进入容器执行 cqlsh
docker exec -it cassandra cqlsh

# 或使用本地 cqlsh (需安装 Cassandra)
cqlsh localhost 9042
```

### 基本 CQL 操作

```cql
-- 查看集群信息
DESCRIBE CLUSTER;

-- 创建 keyspace
CREATE KEYSPACE myks 
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

-- 创建表
USE myks;
CREATE TABLE users (id UUID PRIMARY KEY, name TEXT, email TEXT);

-- 插入数据
INSERT INTO users (id, name, email) 
VALUES (uuid(), 'John', 'john@example.com');

-- 查询数据
SELECT * FROM users;
```

---

## 📊 监控与维护

### 查看节点状态

```powershell
docker exec -it cassandra nodetool status
```

### 查看集群信息

```powershell
docker exec -it cassandra nodetool info
```

### 清理数据 (谨慎使用)

```powershell
# 清理指定表的数据
docker exec -it cassandra nodetool cleanup myks

# 压缩 SSTable
docker exec -it cassandra nodetool compact
```

---

## 🔐 安全配置

### 启用认证 (Bitnami 镜像)

```yaml
environment:
  - CASSANDRA_USER=admin
  - CASSANDRA_PASSWORD=your_secure_password
  - ALLOW_EMPTY_PASSWORD=no
```

### 启用加密

```yaml
environment:
  - CASSANDRA_CLIENT_ENCRYPTION=true
  - CASSANDRA_INTERNODE_ENCRYPTION=all
```

---

## ⚠️ 注意事项

1. **数据持久化**: 务必挂载数据卷，否则容器删除后数据丢失
2. **内存配置**: 生产环境建议调整 `MAX_HEAP_SIZE` 和 `HEAP_NEWSIZE`
3. **集群部署**: 多节点部署时需正确配置 `CASSANDRA_SEEDS`
4. **网络模式**: 集群部署建议使用 Docker 自定义网络
5. **资源限制**: 建议使用 `--memory` 和 `--cpus` 限制容器资源

---

## 📝 故障排查

### 容器无法启动

```powershell
# 查看日志
docker logs cassandra

# 检查端口占用
netstat -ano | findstr :9042
```

### 连接被拒绝

```powershell
# 检查容器状态
docker ps

# 检查网络配置
docker inspect cassandra | findstr IPAddress
```

### 重置数据

```powershell
# 停止并删除容器 (保留镜像)
docker-compose down

# 删除数据卷 (谨慎!)
Remove-Item -Recurse -Force .\data\
Remove-Item -Recurse -Force .\commitlog\

# 重新启动
docker-compose up -d
```

---

## 🔗 参考资源

- [Apache Cassandra 官方文档](https://cassandra.apache.org/doc/latest/)
- [Cassandra Docker Hub](https://hub.docker.com/_/cassandra)
- [Bitnami Cassandra Docker](https://github.com/bitnami/containers/tree/main/bitnami/cassandra)
- [CQL 参考手册](https://cassandra.apache.org/doc/latest/cql/index.html)

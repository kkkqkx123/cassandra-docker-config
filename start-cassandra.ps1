#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Apache Cassandra Docker 启动脚本 (Windows PowerShell)
    
.DESCRIPTION
    该脚本用于在 Windows 环境下启动、停止和管理 Cassandra Docker 容器
    
.PARAMETER Action
    操作类型：start, stop, restart, status, logs, clean, shell
    
.PARAMETER ClusterName
    集群名称 (默认：MyCluster)
    
.PARAMETER MemoryLimit
    内存限制 (默认：2g)
    
.EXAMPLE
    .\start-cassandra.ps1 -Action start
    .\start-cassandra.ps1 -Action start -ClusterName ProdCluster -MemoryLimit 4g
    .\start-cassandra.ps1 -Action logs
    .\start-cassandra.ps1 -Action shell
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('start', 'stop', 'restart', 'status', 'logs', 'clean', 'shell', 'exec')]
    [string]$Action = 'start',
    
    [Parameter(Mandatory = $false)]
    [string]$ClusterName = 'MyCluster',
    
    [Parameter(Mandatory = $false)]
    [string]$MemoryLimit = '2g',
    
    [Parameter(Mandatory = $false)]
    [string]$CpuLimit = '2.0',
    
    [Parameter(Mandatory = $false)]
    [string]$CassandraVersion = 'latest'
)

# 配置项
$ContainerName = 'cassandra'
$ImageName = "cassandra:$CassandraVersion"
$ProjectDir = $PSScriptRoot

# 数据卷目录
$DataDir = Join-Path $ProjectDir 'volumes\data'
$CommitLogDir = Join-Path $ProjectDir 'volumes\commitlog'
$SavedCachesDir = Join-Path $ProjectDir 'volumes\saved_caches'
$ConfigDir = Join-Path $ProjectDir 'volumes\config'

# 端口配置
$CqlPort = 9042
$JmxPort = 7199
$TransportPort = 7000

# 颜色输出函数
function Write-Info    { Write-Host "[INFO]    $($args -join ' ')" -ForegroundColor Cyan }
function Write-Success { Write-Host "[SUCCESS] $($args -join ' ')" -ForegroundColor Green }
function Write-Warning { Write-Host "[WARNING] $($args -join ' ')" -ForegroundColor Yellow }
function Write-Error   { Write-Host "[ERROR]   $($args -join ' ')" -ForegroundColor Red }

# 检查 Docker 是否可用
function Test-Docker {
    try {
        $null = docker --version
        return $true
    } catch {
        Write-Error "Docker 未安装或未添加到 PATH"
        return $false
    }
}

# 创建数据目录
function New-DataDirectories {
    Write-Info "创建数据目录..."
    
    $dirs = @($DataDir, $CommitLogDir, $SavedCachesDir, $ConfigDir)
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Info "  已创建：$dir"
        }
    }
}

# 启动 Cassandra 容器
function Start-CassandraContainer {
    Write-Info "检查 Docker 环境..."
    if (-not (Test-Docker)) {
        exit 1
    }
    
    # 检查镜像是否存在
    Write-Info "检查 Cassandra 镜像..."
    $imageExists = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -eq $ImageName }
    if (-not $imageExists) {
        Write-Warning "镜像 $ImageName 不存在，正在拉取..."
        docker pull $ImageName
        if ($LASTEXITCODE -ne 0) {
            Write-Error "拉取镜像失败"
            exit 1
        }
    } else {
        Write-Success "镜像 $ImageName 已存在"
    }
    
    # 检查容器是否已存在
    $existingContainer = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $ContainerName }
    if ($existingContainer) {
        Write-Warning "容器 $ContainerName 已存在"
        $running = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $ContainerName }
        if ($running) {
            Write-Info "容器正在运行中..."
            Write-Success "Cassandra 已在运行，访问方式:"
            Write-Host "  CQL 端口：localhost:$CqlPort"
            Write-Host "  JMX 端口：localhost:$JmxPort"
            return
        } else {
            Write-Info "启动已存在的容器..."
            docker start $ContainerName
            if ($LASTEXITCODE -eq 0) {
                Write-Success "容器启动成功"
            }
            return
        }
    }
    
    # 创建数据目录
    New-DataDirectories
    
    # 启动容器
    Write-Info "启动 Cassandra 容器..."
    Write-Info "  集群名称：$ClusterName"
    Write-Info "  内存限制：$MemoryLimit"
    Write-Info "  CPU 限制：$CpuLimit"
    
    docker run -d `
        --name $ContainerName `
        --memory $MemoryLimit `
        --cpus $CpuLimit `
        -p $CqlPort:$CqlPort `
        -p $JmxPort:$JmxPort `
        -p $TransportPort:$TransportPort `
        -v "${DataDir}:/var/lib/cassandra/data" `
        -v "${CommitLogDir}:/var/lib/cassandra/commitlog" `
        -v "${SavedCachesDir}:/var/lib/cassandra/saved_caches" `
        -v "${ConfigDir}:/etc/cassandra" `
        -e "CASSANDRA_CLUSTER_NAME=$ClusterName" `
        -e "CASSANDRA_LISTEN_ADDRESS=0.0.0.0" `
        -e "CASSANDRA_BROADCAST_ADDRESS=localhost" `
        -e "MAX_HEAP_SIZE=512M" `
        -e "HEAP_NEWSIZE=100M" `
        $ImageName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "容器启动失败"
        exit 1
    }
    
    Write-Success "容器启动成功!"
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Cassandra 启动信息" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  容器名称：$ContainerName"
    Write-Host "  集群名称：$ClusterName"
    Write-Host "  CQL 端口：localhost:$CqlPort"
    Write-Host "  JMX 端口：localhost:$JmxPort"
    Write-Host "  数据目录：$DataDir"
    Write-Host ""
    Write-Host "  连接命令:"
    Write-Host "    docker exec -it $ContainerName cqlsh"
    Write-Host "    cqlsh localhost $CqlPort"
    Write-Host "========================================" -ForegroundColor Green
    
    # 等待 Cassandra 启动
    Write-Host ""
    Write-Info "等待 Cassandra 启动 (约 30-60 秒)..."
    $maxRetries = 30
    $retryCount = 0
    while ($retryCount -lt $maxRetries) {
        Start-Sleep -Seconds 2
        $status = docker exec $ContainerName nodetool status 2>$null
        if ($status -match 'UN') {
            Write-Success "Cassandra 已就绪!"
            break
        }
        $retryCount++
        Write-Info "  等待中... ($retryCount/$maxRetries)"
    }
}

# 停止容器
function Stop-CassandraContainer {
    Write-Info "停止 Cassandra 容器..."
    $container = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $ContainerName }
    if ($container) {
        docker stop $ContainerName
        Write-Success "容器已停止"
    } else {
        Write-Warning "容器未运行"
    }
}

# 重启容器
function Restart-CassandraContainer {
    Stop-CassandraContainer
    Start-Sleep -Seconds 3
    Start-CassandraContainer
}

# 查看状态
function Get-CassandraStatus {
    Write-Info "Cassandra 容器状态:"
    docker ps -a --filter "name=$ContainerName" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    Write-Host ""
    $running = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $ContainerName }
    if ($running) {
        Write-Info "节点状态:"
        docker exec $ContainerName nodetool status 2>$null
    }
}

# 查看日志
function Get-CassandraLogs {
    param(
        [string]$Tail = '100',
        [switch]$Follow
    )
    
    $followFlag = if ($Follow) { '-f' } else { '' }
    docker logs $followFlag --tail $Tail $ContainerName
}

# 清理容器和数据
function Clean-Cassandra {
    Write-Warning "此操作将删除容器和所有数据!"
    $confirm = Read-Host "确认删除? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Info "操作已取消"
        return
    }
    
    Write-Info "停止并删除容器..."
    docker rm -f $ContainerName 2>$null
    
    Write-Info "删除数据目录..."
    $dirs = @($DataDir, $CommitLogDir, $SavedCachesDir)
    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            Remove-Item -Recurse -Force $dir
            Write-Info "  已删除：$dir"
        }
    }
    
    Write-Success "清理完成"
}

# 进入容器 shell
function Enter-CassandraShell {
    Write-Info "进入 Cassandra 容器..."
    $running = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $ContainerName }
    if (-not $running) {
        Write-Error "容器未运行"
        return
    }
    docker exec -it $ContainerName bash
}

# 执行 CQL 命令
function Invoke-CqlShell {
    Write-Info "启动 cqlsh..."
    $running = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $ContainerName }
    if (-not $running) {
        Write-Error "容器未运行"
        return
    }
    docker exec -it $ContainerName cqlsh
}

# 主逻辑
Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Cassandra Docker 管理脚本            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

switch ($Action) {
    'start'   { Start-CassandraContainer }
    'stop'    { Stop-CassandraContainer }
    'restart' { Restart-CassandraContainer }
    'status'  { Get-CassandraStatus }
    'logs'    { Get-CassandraLogs -Tail 100 }
    'clean'   { Clean-Cassandra }
    'shell'   { Enter-CassandraShell }
    'exec'    { Invoke-CqlShell }
    default   {
        Write-Error "未知操作：$Action"
        Write-Host "可用操作：start, stop, restart, status, logs, clean, shell, exec"
    }
}

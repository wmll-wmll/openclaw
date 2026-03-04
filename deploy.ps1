# 配置参数
$RemoteHost = "192.168.0.107"
$RemoteUser = "wmll"
$RemoteDir = "~/openclaw"
$LocalDir = "e:\GitHub\openclaw"
$ArchiveName = "openclaw-deploy.tar.gz"

# 1. 检查本地是否有未提交的更改（确保打包内容包含最新代码）
Write-Host "正在检查本地 Git 状态..." -ForegroundColor Cyan
git status

# 2. 打包本地代码（排除 .git 目录）
Write-Host "正在打包项目..." -ForegroundColor Cyan
try {
    # 使用 git archive 确保只打包版本库中的文件，避免打包无关文件
    git archive --format=tar.gz -o $ArchiveName HEAD
    # 如果有未提交的 Dockerfile 修改，git archive 不会包含，需要手动追加或先提交
    # 这里假设用户遵循规则已提交。如果有未提交的 Dockerfile，我们会单独上传覆盖。
}
catch {
    Write-Error "打包失败: $_"
    exit 1
}

# 3. 上传文件到远程服务器
Write-Host "正在上传部署包..." -ForegroundColor Cyan
try {
    # 创建远程目录
    ssh "${RemoteUser}@${RemoteHost}" "mkdir -p $RemoteDir"
    
    # 上传压缩包
    scp $ArchiveName "${RemoteUser}@${RemoteHost}:${RemoteDir}/${ArchiveName}"
    
    # 强制上传本地 Dockerfile (以防本地修改未提交)
    scp Dockerfile "${RemoteUser}@${RemoteHost}:${RemoteDir}/Dockerfile"
}
catch {
    Write-Error "上传失败: $_"
    exit 1
}

# 4. 在远程服务器执行部署逻辑
Write-Host "正在远程部署..." -ForegroundColor Cyan
$RemoteScript = @"
cd $RemoteDir

# 解压代码
tar -xzf $ArchiveName

# 确保数据目录存在
mkdir -p data/config data/workspace

# 检查 .env 文件，如果不存在则创建默认配置
if [ ! -f .env ]; then
    echo "创建默认 .env..."
    echo "OPENCLAW_GATEWAY_TOKEN=\$(openssl rand -hex 32)" > .env
    echo "OPENCLAW_CONFIG_DIR=./data/config" >> .env
    echo "OPENCLAW_WORKSPACE_DIR=./data/workspace" >> .env
fi

# 确保 Docker 镜像源配置正确（可选，如果之前已配置过 setup_mirror.sh）
# ...

# 重新构建并启动服务
echo "正在构建并启动 Docker 容器..."
sudo docker compose up -d --build

# 查看容器状态
docker compose ps
"@

try {
    # 使用 ssh -t 分配伪终端以支持 sudo 交互（如果需要）
    # 注意：如果 sudo 需要密码，脚本可能会暂停等待输入
    ssh -t "${RemoteUser}@${RemoteHost}" $RemoteScript
}
catch {
    Write-Error "远程部署命令执行失败: $_"
    exit 1
}

# 5. 清理本地临时文件
Remove-Item $ArchiveName -ErrorAction SilentlyContinue

Write-Host "=== 部署完成! ===" -ForegroundColor Green

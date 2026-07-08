# ============================================
# Focus Fitness OS - Node-RED 后端 Docker 镜像
# 基于固定版本，预装社区节点
# ============================================
FROM nodered/node-red:4.0.2

# 设置工作目录
WORKDIR /data

# 复制 package.json 并安装社区节点
COPY package.json /data/package.json
RUN npm install --production --no-save

# 复制项目文件
COPY settings.js /data/settings.js
COPY flows/ /data/flows/
# 将合并后的 flows.json 复制到 /data/ 根目录 (Node-RED flowFile 默认查找位置)
COPY flows/flows.json /data/flows.json

# 暴露端口
EXPOSE 1880

# 创建 SQLite 数据库目录
RUN mkdir -p /data/db

# 环境变量默认值 (NODE_RED_SECRET 和 JWT_SECRET 必须通过平台环境变量注入)
ENV FLOWS=flows.json \
    TZ=Asia/Shanghai \
    PORT=1880

# 健康检查 (使用 node 原生 http 模块检查 /health 端点)
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=15s \
    CMD node -e "require('http').get('http://localhost:'+(process.env.PORT||1880)+'/health',r=>{process.exit(r.statusCode===200?0:1)}).on('error',()=>process.exit(1))"

# 清除基础镜像的 ENTRYPOINT (entrypoint.sh 在容器中找不到)
ENTRYPOINT []

# 启动命令 - 直接使用 node-red
CMD ["node-red", "-u", "/data", "-s", "/data/settings.js"]

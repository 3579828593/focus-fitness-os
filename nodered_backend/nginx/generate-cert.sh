#!/bin/bash
# 生成自签名 TLS 证书（仅开发环境）
# 生产环境请使用 Let's Encrypt 或商业证书
#
# 使用方法:
#   cd nodered_backend/nginx
#   bash generate-cert.sh
#
# 权限说明: 若需直接执行，请先赋予可执行权限:
#   chmod +x generate-cert.sh
#   ./generate-cert.sh
#
# 依赖: openssl

set -e

# 证书输出目录
CERT_DIR="./certs"
mkdir -p "$CERT_DIR"

echo "生成自签名 TLS 证书..."
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout "$CERT_DIR/key.pem" \
  -out "$CERT_DIR/cert.pem" \
  -days 365 \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=Focus Fitness OS/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

echo "证书已生成:"
echo "  证书: $CERT_DIR/cert.pem"
echo "  私钥: $CERT_DIR/key.pem"
echo ""
echo "注意: 此证书仅用于开发环境。生产环境请使用受信任的 CA 证书。"

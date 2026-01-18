#!/bin/bash

# ============================================================================
# Android 签名密钥设置脚本
# Android Signing Key Setup Script
# ============================================================================
#
# 此脚本帮助你创建 Android 应用签名所需的密钥
# This script helps you create the signing key for Android app
#
# 使用方法 / Usage:
#   ./scripts/setup-android-signing.sh
#
# ============================================================================

set -e

# 颜色 / Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 路径 / Paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$RELEASE_DIR/.." && pwd)"
ANDROID_DIR="$PROJECT_ROOT/frontend/android"

KEYSTORE_PATH="$ANDROID_DIR/app/upload-keystore.jks"
KEY_PROPERTIES="$ANDROID_DIR/key.properties"

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Android 签名密钥设置${NC}"
echo -e "${CYAN}  Android Signing Key Setup${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# 检查是否已存在 / Check if already exists
if [ -f "$KEYSTORE_PATH" ]; then
    echo -e "${YELLOW}⚠️  密钥库已存在 / Keystore already exists:${NC}"
    echo "   $KEYSTORE_PATH"
    echo ""
    read -p "是否覆盖? / Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消 / Cancelled"
        exit 0
    fi
fi

# 收集信息 / Collect information
echo -e "${CYAN}请输入以下信息 / Please enter the following information:${NC}"
echo ""

read -p "密钥别名 / Key alias (default: cyberpath): " KEY_ALIAS
KEY_ALIAS=${KEY_ALIAS:-cyberpath}

read -sp "密钥库密码 / Keystore password (min 6 chars): " STORE_PASSWORD
echo
if [ ${#STORE_PASSWORD} -lt 6 ]; then
    echo -e "${RED}密码太短 / Password too short${NC}"
    exit 1
fi

read -sp "密钥密码 / Key password (press Enter to use same): " KEY_PASSWORD
echo
KEY_PASSWORD=${KEY_PASSWORD:-$STORE_PASSWORD}

echo ""
echo -e "${CYAN}证书信息 / Certificate information:${NC}"
read -p "姓名 / Name (CN): " CN
read -p "组织单位 / Organizational Unit (OU): " OU
read -p "组织 / Organization (O): " O
read -p "城市 / City (L): " L
read -p "省份 / State (ST): " ST
read -p "国家代码 / Country (C, e.g., CN): " C

# 生成密钥 / Generate key
echo ""
echo -e "${GREEN}正在生成密钥... / Generating key...${NC}"

keytool -genkey -v \
    -keystore "$KEYSTORE_PATH" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias "$KEY_ALIAS" \
    -storepass "$STORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "CN=$CN, OU=$OU, O=$O, L=$L, ST=$ST, C=$C"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 密钥库创建成功 / Keystore created successfully${NC}"
else
    echo -e "${RED}❌ 密钥库创建失败 / Keystore creation failed${NC}"
    exit 1
fi

# 创建 key.properties / Create key.properties
echo ""
echo -e "${GREEN}创建 key.properties... / Creating key.properties...${NC}"

cat > "$KEY_PROPERTIES" << EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=app/upload-keystore.jks
EOF

echo -e "${GREEN}✅ key.properties 创建成功${NC}"

# 更新 .gitignore / Update .gitignore
GITIGNORE="$ANDROID_DIR/.gitignore"
if [ -f "$GITIGNORE" ]; then
    if ! grep -q "key.properties" "$GITIGNORE"; then
        echo "" >> "$GITIGNORE"
        echo "# Signing" >> "$GITIGNORE"
        echo "key.properties" >> "$GITIGNORE"
        echo "*.jks" >> "$GITIGNORE"
        echo "*.keystore" >> "$GITIGNORE"
        echo -e "${GREEN}✅ 已更新 .gitignore${NC}"
    fi
fi

# 配置 build.gradle / Configure build.gradle
BUILD_GRADLE="$ANDROID_DIR/app/build.gradle"
if [ -f "$BUILD_GRADLE" ]; then
    if ! grep -q "signingConfigs" "$BUILD_GRADLE"; then
        echo ""
        echo -e "${YELLOW}⚠️  请手动更新 build.gradle / Please manually update build.gradle${NC}"
        echo ""
        echo "在 android { } 块中添加 / Add in android { } block:"
        echo ""
        cat << 'EOF'
    def keystoreProperties = new Properties()
    def keystorePropertiesFile = rootProject.file('key.properties')
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            // ...
        }
    }
EOF
    fi
fi

# 完成 / Done
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  设置完成 / Setup Complete${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo "密钥库位置 / Keystore location:"
echo "  $KEYSTORE_PATH"
echo ""
echo "配置文件 / Config file:"
echo "  $KEY_PROPERTIES"
echo ""
echo -e "${RED}⚠️  重要 / Important:${NC}"
echo "  1. 请备份密钥库文件 / Please backup the keystore file"
echo "  2. 不要将密钥提交到 Git / Do not commit keys to Git"
echo "  3. 安全保存密码 / Keep passwords safe"
echo ""

#!/bin/bash

# ============================================================================
# CyberPath 构建和发布脚本
# ============================================================================
#
# 使用方法：
#   ./scripts/build-and-release.sh [版本号]
#
# 示例：
#   ./scripts/build-and-release.sh 2.0.2
#
# 前提条件：
# 1. 已在 GitHub 创建 public 仓库：cyberpath-releases
# 2. 已配置 release 文件夹的远程仓库
# 3. 已安装 Flutter SDK
# 4. macOS: 已安装 create-dmg (brew install create-dmg)
#
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RELEASE_DIR="$PROJECT_ROOT/release"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# 版本号
VERSION=${1:-""}

if [ -z "$VERSION" ]; then
    echo -e "${RED}错误: 请提供版本号${NC}"
    echo "用法: $0 <版本号>"
    echo "示例: $0 2.0.2"
    exit 1
fi

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  CyberPath 构建和发布 v$VERSION${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# 确认
echo -e "${YELLOW}即将构建并发布版本 v$VERSION${NC}"
read -p "确认继续? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 1
fi

# 创建构建输出目录
BUILD_OUTPUT="$RELEASE_DIR/build"
mkdir -p "$BUILD_OUTPUT"

# ============================================================================
# 构建 macOS
# ============================================================================
echo ""
echo -e "${GREEN}[1/4] 构建 macOS 版本...${NC}"

cd "$FRONTEND_DIR"
flutter build macos --release

# 复制 app bundle
APP_NAME="cyberpath.app"
APP_PATH="$FRONTEND_DIR/build/macos/Build/Products/Release/$APP_NAME"

if [ -d "$APP_PATH" ]; then
    echo -e "${GREEN}  ✓ macOS 构建成功${NC}"
    
    # 创建 DMG（如果安装了 create-dmg）
    if command -v create-dmg &> /dev/null; then
        DMG_NAME="CyberPath-$VERSION-macos.dmg"
        echo "  创建 DMG: $DMG_NAME"
        
        create-dmg \
            --volname "CyberPath $VERSION" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "$APP_NAME" 150 185 \
            --app-drop-link 450 185 \
            "$BUILD_OUTPUT/$DMG_NAME" \
            "$APP_PATH" \
            2>/dev/null || true
            
        if [ -f "$BUILD_OUTPUT/$DMG_NAME" ]; then
            echo -e "${GREEN}  ✓ DMG 创建成功: $DMG_NAME${NC}"
        else
            echo -e "${YELLOW}  ⚠ DMG 创建失败，请手动打包${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ 未安装 create-dmg，跳过 DMG 创建${NC}"
        echo "  安装: brew install create-dmg"
    fi
else
    echo -e "${RED}  ✗ macOS 构建失败${NC}"
fi

# ============================================================================
# 构建 Windows（仅在 Windows 上可用）
# ============================================================================
echo ""
echo -e "${GREEN}[2/4] 构建 Windows 版本...${NC}"

if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    flutter build windows --release
    echo -e "${GREEN}  ✓ Windows 构建成功${NC}"
else
    echo -e "${YELLOW}  ⚠ 跳过 Windows 构建（需要在 Windows 上执行）${NC}"
fi

# ============================================================================
# 构建 Android
# ============================================================================
echo ""
echo -e "${GREEN}[3/4] 构建 Android 版本...${NC}"

cd "$FRONTEND_DIR"
flutter build apk --release

APK_PATH="$FRONTEND_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    APK_NAME="CyberPath-$VERSION.apk"
    cp "$APK_PATH" "$BUILD_OUTPUT/$APK_NAME"
    echo -e "${GREEN}  ✓ Android 构建成功: $APK_NAME${NC}"
else
    echo -e "${YELLOW}  ⚠ Android 构建失败或跳过${NC}"
fi

# ============================================================================
# 显示构建结果
# ============================================================================
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  构建完成${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "构建产物位于: $BUILD_OUTPUT"
echo ""
ls -la "$BUILD_OUTPUT" 2>/dev/null || echo "（无文件）"
echo ""

# ============================================================================
# 发布说明
# ============================================================================
echo -e "${YELLOW}下一步操作：${NC}"
echo ""
echo "1. 在 GitHub 创建 Release:"
echo "   - 打开: https://github.com/YOUR_USERNAME/cyberpath-releases/releases/new"
echo "   - Tag: v$VERSION"
echo "   - Title: CyberPath v$VERSION"
echo "   - 上传 $BUILD_OUTPUT 中的安装包"
echo ""
echo "2. 更新后端版本配置:"
echo "   - 编辑: backend/app/api/v1/app_update.py"
echo "   - 修改 CURRENT_VERSION = \"$VERSION\""
echo ""
echo "3. 提交 release 仓库更新:"
echo "   cd $RELEASE_DIR"
echo "   git add ."
echo "   git commit -m \"Release v$VERSION\""
echo "   git push origin main"
echo ""

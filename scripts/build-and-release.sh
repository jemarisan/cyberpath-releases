#!/bin/bash

# ============================================================================
# CyberPath 构建、打包、签名脚本
# Build, Package and Sign Script for CyberPath
# ============================================================================
#
# 使用方法 / Usage:
#   ./scripts/build-and-release.sh <版本号>
#   ./scripts/build-and-release.sh <version>
#
# 示例 / Example:
#   ./scripts/build-and-release.sh 2.0.2
#
# 前提条件 / Prerequisites:
# - Flutter SDK installed
# - macOS: Xcode, create-dmg (brew install create-dmg)
# - Windows: Visual Studio, Inno Setup (optional)
# - Android: Android SDK
#
# ============================================================================

set -e

# 颜色定义 / Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 项目路径 / Project paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$RELEASE_DIR/.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# 输出目录（安装包落地路径）/ Output directory
OUTPUT_DIR="$RELEASE_DIR/packages"

# 版本号 / Version
VERSION=${1:-""}

# GitHub 仓库配置 / GitHub repository config
GITHUB_OWNER="jemarisan"
GITHUB_REPO="cyberpath-releases"

# ============================================================================
# 函数定义 / Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[$(date +%H:%M:%S)] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 检查命令是否存在 / Check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        return 1
    fi
    return 0
}

# 获取文件大小 / Get file size
get_file_size() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f%z "$1" 2>/dev/null || echo "0"
    else
        stat -c%s "$1" 2>/dev/null || echo "0"
    fi
}

# 格式化文件大小 / Format file size
format_size() {
    local size=$1
    if [ $size -gt 1073741824 ]; then
        echo "$(echo "scale=2; $size/1073741824" | bc) GB"
    elif [ $size -gt 1048576 ]; then
        echo "$(echo "scale=2; $size/1048576" | bc) MB"
    elif [ $size -gt 1024 ]; then
        echo "$(echo "scale=2; $size/1024" | bc) KB"
    else
        echo "$size B"
    fi
}

# ============================================================================
# 主流程 / Main
# ============================================================================

# 检查版本号 / Check version
if [ -z "$VERSION" ]; then
    print_error "请提供版本号 / Please provide version number"
    echo ""
    echo "用法 / Usage: $0 <version>"
    echo "示例 / Example: $0 2.0.2"
    exit 1
fi

print_header "CyberPath Build & Release v$VERSION"

echo "项目根目录 / Project root: $PROJECT_ROOT"
echo "前端目录 / Frontend dir: $FRONTEND_DIR"
echo "输出目录 / Output dir: $OUTPUT_DIR"
echo ""

# 确认 / Confirm
echo -e "${YELLOW}即将构建并打包版本 v$VERSION${NC}"
echo -e "${YELLOW}About to build and package version v$VERSION${NC}"
read -p "确认继续? / Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消 / Cancelled"
    exit 1
fi

# 创建输出目录 / Create output directory
mkdir -p "$OUTPUT_DIR"

# 更新 pubspec.yaml 版本号 / Update version in pubspec.yaml
print_step "更新版本号 / Updating version number..."
cd "$FRONTEND_DIR"

# 提取 build number (移除点号)
BUILD_NUMBER=$(echo "$VERSION" | tr -d '.')

# 更新 pubspec.yaml
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^version: .*/version: $VERSION+$BUILD_NUMBER/" pubspec.yaml
else
    sed -i "s/^version: .*/version: $VERSION+$BUILD_NUMBER/" pubspec.yaml
fi

print_success "版本已更新为 $VERSION+$BUILD_NUMBER"

# ============================================================================
# 构建 macOS / Build macOS
# ============================================================================

if [[ "$OSTYPE" == "darwin"* ]]; then
    print_header "Building macOS"
    
    print_step "Running flutter build macos --release..."
    flutter build macos --release
    
    APP_PATH="$FRONTEND_DIR/build/macos/Build/Products/Release/cyberpath.app"
    DMG_NAME="CyberPath-$VERSION-macos.dmg"
    DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
    
    if [ -d "$APP_PATH" ]; then
        print_success "macOS build completed"
        
        # 代码签名 (如果有证书) / Code signing (if certificate available)
        if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
            print_step "Signing application..."
            codesign --deep --force --verify --verbose \
                --sign "Developer ID Application" \
                "$APP_PATH" 2>/dev/null && print_success "App signed" || print_warning "Signing skipped"
        else
            print_warning "No signing certificate found, skipping code signing"
        fi
        
        # 创建 DMG / Create DMG
        if check_command create-dmg; then
            print_step "Creating DMG package..."
            
            # 删除旧的 DMG
            rm -f "$DMG_PATH"
            
            create-dmg \
                --volname "CyberPath $VERSION" \
                --volicon "$FRONTEND_DIR/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" \
                --window-pos 200 120 \
                --window-size 660 400 \
                --icon-size 100 \
                --icon "cyberpath.app" 180 185 \
                --hide-extension "cyberpath.app" \
                --app-drop-link 480 185 \
                --no-internet-enable \
                "$DMG_PATH" \
                "$APP_PATH" \
                2>/dev/null || {
                    # 简单方式创建 DMG
                    print_warning "create-dmg failed, using simple method..."
                    hdiutil create -volname "CyberPath $VERSION" \
                        -srcfolder "$APP_PATH" \
                        -ov -format UDZO \
                        "$DMG_PATH"
                }
            
            if [ -f "$DMG_PATH" ]; then
                local size=$(get_file_size "$DMG_PATH")
                print_success "DMG created: $DMG_NAME ($(format_size $size))"
            fi
        else
            print_warning "create-dmg not found. Install with: brew install create-dmg"
            
            # 使用 hdiutil 创建简单 DMG
            print_step "Creating DMG with hdiutil..."
            hdiutil create -volname "CyberPath $VERSION" \
                -srcfolder "$APP_PATH" \
                -ov -format UDZO \
                "$DMG_PATH" 2>/dev/null && print_success "DMG created" || print_error "DMG creation failed"
        fi
    else
        print_error "macOS build failed - app not found"
    fi
fi

# ============================================================================
# 构建 Windows / Build Windows
# ============================================================================

if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    print_header "Building Windows"
    
    print_step "Running flutter build windows --release..."
    cd "$FRONTEND_DIR"
    flutter build windows --release
    
    WINDOWS_BUILD="$FRONTEND_DIR/build/windows/x64/runner/Release"
    EXE_NAME="CyberPath-$VERSION-windows.exe"
    EXE_PATH="$OUTPUT_DIR/$EXE_NAME"
    
    if [ -d "$WINDOWS_BUILD" ]; then
        print_success "Windows build completed"
        
        # 如果安装了 Inno Setup，创建安装程序
        if check_command iscc; then
            print_step "Creating installer with Inno Setup..."
            # TODO: 创建 Inno Setup 脚本
            print_warning "Inno Setup script not configured"
        else
            # 简单打包为 ZIP
            ZIP_NAME="CyberPath-$VERSION-windows.zip"
            print_step "Creating ZIP package..."
            cd "$WINDOWS_BUILD"
            zip -r "$OUTPUT_DIR/$ZIP_NAME" . -x "*.pdb"
            print_success "ZIP created: $ZIP_NAME"
        fi
    else
        print_error "Windows build failed"
    fi
else
    print_warning "Skipping Windows build (not on Windows)"
fi

# ============================================================================
# 构建 Android / Build Android
# ============================================================================

print_header "Building Android"

cd "$FRONTEND_DIR"

# 检查是否有签名配置 / Check for signing config
KEYSTORE_PATH="$PROJECT_ROOT/android/app/upload-keystore.jks"
KEY_PROPERTIES="$PROJECT_ROOT/android/key.properties"

if [ -f "$KEYSTORE_PATH" ] && [ -f "$KEY_PROPERTIES" ]; then
    print_step "Building signed APK..."
    flutter build apk --release
else
    print_warning "No signing key found, building debug APK"
    print_warning "To create a signed APK, run: ./scripts/setup-android-signing.sh"
    flutter build apk --release
fi

APK_SOURCE="$FRONTEND_DIR/build/app/outputs/flutter-apk/app-release.apk"
APK_NAME="CyberPath-$VERSION.apk"
APK_PATH="$OUTPUT_DIR/$APK_NAME"

if [ -f "$APK_SOURCE" ]; then
    cp "$APK_SOURCE" "$APK_PATH"
    local size=$(get_file_size "$APK_PATH")
    print_success "APK created: $APK_NAME ($(format_size $size))"
else
    print_error "Android build failed - APK not found"
fi

# ============================================================================
# 构建摘要 / Build Summary
# ============================================================================

print_header "Build Summary | 构建摘要"

echo "输出目录 / Output directory: $OUTPUT_DIR"
echo ""
echo "构建产物 / Build artifacts:"
echo "----------------------------------------"

if [ -d "$OUTPUT_DIR" ]; then
    ls -lh "$OUTPUT_DIR" 2>/dev/null | grep -v "^total" | while read line; do
        echo "  $line"
    done
fi

echo ""
echo "----------------------------------------"

# ============================================================================
# 下一步操作 / Next Steps
# ============================================================================

print_header "Next Steps | 下一步操作"

echo -e "${CYAN}1. 在 GitHub 创建 Release / Create GitHub Release:${NC}"
echo "   https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/new"
echo ""
echo -e "${CYAN}2. 填写 Release 信息 / Fill in Release info:${NC}"
echo "   Tag: v$VERSION"
echo "   Title: CyberPath v$VERSION"
echo ""
echo -e "${CYAN}3. 上传安装包 / Upload packages:${NC}"
for file in "$OUTPUT_DIR"/*; do
    if [ -f "$file" ]; then
        echo "   - $(basename "$file")"
    fi
done
echo ""
echo -e "${CYAN}4. 更新后端版本配置 / Update backend config:${NC}"
echo "   File: backend/app/api/v1/app_update.py"
echo "   CURRENT_VERSION = \"$VERSION\""
echo "   CURRENT_BUILD = $BUILD_NUMBER"
echo ""
echo -e "${CYAN}5. 提交 release 仓库 / Commit release repo:${NC}"
echo "   cd $RELEASE_DIR"
echo "   git add ."
echo "   git commit -m \"Release v$VERSION\""
echo "   git push origin main"
echo ""

print_success "构建完成！/ Build completed!"

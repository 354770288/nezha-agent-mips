#!/bin/sh
# Nezha Agent 一键安装管理脚本 for OpenWrt (MIPS)
# 支持 tmpfs 临时安装模式

INSTALL_DIR="/etc/nezha"
TMPFS_INSTALL_DIR="/tmp/nezha"
CONFIG_FILE="${INSTALL_DIR}/config.yml"
AGENT_BIN="${INSTALL_DIR}/nezha-agent"
SERVICE_FILE="/etc/init.d/nezha-service"
DOWNLOAD_URL="https://github.com/354770288/nezha-agent-mips/releases/download/v1.13.1/nezha-agent-linux-mipsle"
TMPFS_BOOTSTRAP="/etc/init.d/nezha-tmpfs-bootstrap"
INSTALL_MODE_FILE="${INSTALL_DIR}/.install_mode"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 显示菜单
show_menu() {
    clear
    echo "======================================"
    echo "  Nezha Agent 一键管理脚本 (OpenWrt)"
    echo "======================================"
    echo "1. 安装 Nezha Agent (普通模式)"
    echo "2. 安装 Nezha Agent (tmpfs 模式)"
    echo "3. 修改配置"
    echo "4. 查看服务状态"
    echo "5. 重启服务"
    echo "6. 卸载服务"
    echo "0. 退出"
    echo "======================================"
    if [ -f "$INSTALL_MODE_FILE" ]; then
        mode=$(cat "$INSTALL_MODE_FILE")
        print_message "$YELLOW" "当前安装模式: $mode"
        echo "======================================"
    fi
    echo -n "请选择操作 [0-6]: "
}

# 普通安装
install_agent() {
    print_message "$YELLOW" "\n开始安装 Nezha Agent (普通模式)..."
    
    # 检查是否已安装
    if [ -f "$AGENT_BIN" ]; then
        print_message "$RED" "检测到已安装 Nezha Agent！"
        echo -n "是否覆盖安装？(y/n): "
        read confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            print_message "$YELLOW" "取消安装"
            return
        fi
    fi
    
    # 创建安装目录
    print_message "$GREEN" "创建安装目录..."
    mkdir -p "$INSTALL_DIR"
    
    # 下载 Nezha Agent
    print_message "$GREEN" "下载 Nezha Agent..."
    cd "$INSTALL_DIR"
    wget -O nezha-agent "$DOWNLOAD_URL" --no-check-certificate
    
    if [ $? -ne 0 ]; then
        print_message "$RED" "下载失败！请检查网络连接"
        return 1
    fi
    
    # 赋予执行权限
    chmod +x "$AGENT_BIN"
    
    # 获取用户配置
    print_message "$GREEN" "\n请输入配置信息："
    echo -n "请输入 Server 地址(例如: data.example.com:8008): "
    read server_addr
    echo -n "请输入 UUID: "
    read uuid
    echo -n "请输入 Client Secret: "
    read client_secret
    
    # 创建配置文件
    print_message "$GREEN" "创建配置文件..."
    cat > "$CONFIG_FILE" <<EOF
client_secret: $client_secret
debug: false
disable_auto_update: false
disable_command_execute: false
disable_force_update: false
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 1
server: $server_addr
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: false
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: $uuid
EOF
    
    # 创建服务脚本
    print_message "$GREEN" "创建系统服务..."
    cat > "$SERVICE_FILE" <<'EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /etc/nezha/nezha-agent -c /etc/nezha/config.yml
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    killall nezha-agent
}

restart() {
    stop
    sleep 2
    start
}
EOF
    
    # 赋予服务脚本执行权限
    chmod +x "$SERVICE_FILE"
    
    # 记录安装模式
    echo "normal" > "$INSTALL_MODE_FILE"
    
    # 启用并启动服务
    print_message "$GREEN" "启用并启动服务..."
    /etc/init.d/nezha-service enable
    /etc/init.d/nezha-service start
    
    # 验证安装
    sleep 3
    if ps aux | grep nezha-agent | grep -v grep > /dev/null; then
        print_message "$GREEN" "\n安装成功！Nezha Agent 正在运行"
    else
        print_message "$RED" "\n安装完成但服务未启动，请检查配置"
    fi
}

# tmpfs 模式安装
install_agent_tmpfs() {
    print_message "$YELLOW" "\n开始安装 Nezha Agent (tmpfs 模式)..."
    print_message "$YELLOW" "注意: tmpfs 模式下程序运行在内存中，重启后需要重新下载"
    
    # 检查是否已安装
    if [ -f "$INSTALL_MODE_FILE" ]; then
        print_message "$RED" "检测到已安装 Nezha Agent！"
        echo -n "是否覆盖安装？(y/n): "
        read confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            print_message "$YELLOW" "取消安装"
            return
        fi
        # 清理旧安装
        cleanup_all_installations
    fi
    
    # 创建持久化配置目录 (只存配置文件)
    print_message "$GREEN" "创建配置目录..."
    mkdir -p "$INSTALL_DIR"
    
    # 获取用户配置
    print_message "$GREEN" "\n请输入配置信息："
    echo -n "请输入 Server 地址(例如: data.example.com:8008): "
    read server_addr
    echo -n "请输入 UUID: "
    read uuid
    echo -n "请输入 Client Secret: "
    read client_secret
    
    # 创建配置文件 (保存在持久化存储)
    print_message "$GREEN" "创建配置文件..."
    cat > "$CONFIG_FILE" <<EOF
client_secret: $client_secret
debug: false
disable_auto_update: false
disable_command_execute: false
disable_force_update: false
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 1
server: $server_addr
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: false
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: $uuid
EOF
    
    # 记录安装模式
    echo "tmpfs" > "$INSTALL_MODE_FILE"
    
    # 创建 tmpfs 引导服务 (开机自动下载并启动)
    print_message "$GREEN" "创建 tmpfs 引导服务..."
    cat > "$TMPFS_BOOTSTRAP" <<'BOOTSTRAP_EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

TMPFS_DIR="/tmp/nezha"
CONFIG_FILE="/etc/nezha/config.yml"
DOWNLOAD_URL="https://github.com/354770288/nezha-agent-mips/releases/download/v1.13.1/nezha-agent-linux-mipsle"
LOG_FILE="/tmp/nezha-bootstrap.log"

download_and_start() {
    echo "$(date): Starting Nezha Agent bootstrap..." > "$LOG_FILE"
    
    # 创建 tmpfs 目录
    mkdir -p "$TMPFS_DIR"
    
    # 检查配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$(date): ERROR - Config file not found!" >> "$LOG_FILE"
        return 1
    fi
    
    # 下载 Agent
    echo "$(date): Downloading Nezha Agent..." >> "$LOG_FILE"
    wget -O "$TMPFS_DIR/nezha-agent" "$DOWNLOAD_URL" --no-check-certificate >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        echo "$(date): ERROR - Download failed!" >> "$LOG_FILE"
        return 1
    fi
    
    # 赋予执行权限
    chmod +x "$TMPFS_DIR/nezha-agent"
    
    echo "$(date): Download completed, starting agent..." >> "$LOG_FILE"
    
    return 0
}

start_service() {
    # 先下载
    download_and_start
    
    if [ $? -eq 0 ]; then
        # 启动服务
        procd_open_instance
        procd_set_param command "$TMPFS_DIR/nezha-agent" -c "$CONFIG_FILE"
        procd_set_param respawn ${respawn_threshold:-3600} ${respawn_timeout:-5} ${respawn_retry:-5}
        procd_set_param stdout 1
        procd_set_param stderr 1
        procd_close_instance
        
        echo "$(date): Nezha Agent started successfully" >> "$LOG_FILE"
    else
        echo "$(date): Failed to start Nezha Agent" >> "$LOG_FILE"
    fi
}

stop_service() {
    killall nezha-agent 2>/dev/null
    echo "$(date): Nezha Agent stopped" >> "$LOG_FILE"
}

restart() {
    stop
    sleep 2
    start
}
BOOTSTRAP_EOF
    
    # 赋予执行权限
    chmod +x "$TMPFS_BOOTSTRAP"
    
    # 启用引导服务
    print_message "$GREEN" "启用 tmpfs 引导服务..."
    /etc/init.d/nezha-tmpfs-bootstrap enable
    
    # 立即执行一次安装
    print_message "$GREEN" "首次下载和启动服务..."
    /etc/init.d/nezha-tmpfs-bootstrap start
    
    # 验证安装
    sleep 5
    if ps aux | grep nezha-agent | grep -v grep > /dev/null; then
        print_message "$GREEN" "\n安装成功！Nezha Agent 正在运行 (tmpfs 模式)"
        print_message "$YELLOW" "提示: 每次重启后会自动从网络下载并启动"
        print_message "$YELLOW" "日志文件: /tmp/nezha-bootstrap.log"
    else
        print_message "$RED" "\n服务启动失败，请查看日志: cat /tmp/nezha-bootstrap.log"
    fi
}

# 修改配置
modify_config() {
    print_message "$YELLOW" "\n修改配置..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        print_message "$RED" "配置文件不存在！请先安装"
        return
    fi
    
    # 读取当前配置
    current_server=$(grep "^server:" "$CONFIG_FILE" | awk '{print $2}')
    current_uuid=$(grep "^uuid:" "$CONFIG_FILE" | awk '{print $2}')
    
    print_message "$GREEN" "当前配置："
    echo "Server: $current_server"
    echo "UUID: $current_uuid"
    echo ""
    
    # 获取新配置
    echo -n "请输入新的 Server 地址(回车保持不变): "
    read new_server
    echo -n "请输入新的 UUID(回车保持不变): "
    read new_uuid
    echo -n "请输入新的 Client Secret(回车保持不变): "
    read new_secret
    
    # 更新配置
    if [ -n "$new_server" ]; then
        sed -i "s|^server:.*|server: $new_server|" "$CONFIG_FILE"
    fi
    
    if [ -n "$new_uuid" ]; then
        sed -i "s|^uuid:.*|uuid: $uuid|" "$CONFIG_FILE"
    fi
    
    if [ -n "$new_secret" ]; then
        sed -i "s|^client_secret:.*|client_secret: $new_secret|" "$CONFIG_FILE"
    fi
    
    print_message "$GREEN" "配置已更新！"
    echo -n "是否重启服务使配置生效？(y/n): "
    read restart_confirm
    if [ "$restart_confirm" = "y" ] || [ "$restart_confirm" = "Y" ]; then
        restart_service
    fi
}

# 查看服务状态
check_status() {
    print_message "$YELLOW" "\n查看服务状态..."
    
    if [ ! -f "$INSTALL_MODE_FILE" ]; then
        print_message "$RED" "Nezha Agent 未安装！"
        return
    fi
    
    mode=$(cat "$INSTALL_MODE_FILE")
    print_message "$GREEN" "安装模式: $mode"
    
    # 检查进程
    if ps aux | grep nezha-agent | grep -v grep > /dev/null; then
        print_message "$GREEN" "服务状态: 运行中"
        echo ""
        ps aux | grep nezha-agent | grep -v grep
    else
        print_message "$RED" "服务状态: 未运行"
    fi
    
    # 根据模式显示不同信息
    if [ "$mode" = "tmpfs" ]; then
        print_message "$YELLOW" "\ntmpfs 模式信息:"
        echo "程序位置: $TMPFS_INSTALL_DIR"
        echo "配置位置: $CONFIG_FILE"
        if [ -f "/tmp/nezha-bootstrap.log" ]; then
            echo -e "\n最近日志:"
            tail -n 10 /tmp/nezha-bootstrap.log
        fi
        
        # 检查引导服务
        if ls /etc/rc.d/*nezha-tmpfs-bootstrap* > /dev/null 2>&1; then
            print_message "$GREEN" "开机自启: 已启用"
        else
            print_message "$YELLOW" "开机自启: 未启用"
        fi
    else
        print_message "$YELLOW" "\n普通模式信息:"
        echo "程序位置: $AGENT_BIN"
        echo "配置位置: $CONFIG_FILE"
        
        # 检查服务
        if [ -f "$SERVICE_FILE" ]; then
            if ls /etc/rc.d/*nezha-service* > /dev/null 2>&1; then
                print_message "$GREEN" "开机自启: 已启用"
            else
                print_message "$YELLOW" "开机自启: 未启用"
            fi
        fi
    fi
}

# 重启服务
restart_service() {
    print_message "$YELLOW" "\n重启服务..."
    
    if [ ! -f "$INSTALL_MODE_FILE" ]; then
        print_message "$RED" "服务未安装！"
        return
    fi
    
    mode=$(cat "$INSTALL_MODE_FILE")
    
    if [ "$mode" = "tmpfs" ]; then
        if [ -f "$TMPFS_BOOTSTRAP" ]; then
            /etc/init.d/nezha-tmpfs-bootstrap restart
        else
            print_message "$RED" "tmpfs 引导服务不存在！"
            return
        fi
    else
        if [ -f "$SERVICE_FILE" ]; then
            /etc/init.d/nezha-service restart
        else
            print_message "$RED" "服务文件不存在！"
            return
        fi
    fi
    
    sleep 3
    if ps aux | grep nezha-agent | grep -v grep > /dev/null; then
        print_message "$GREEN" "服务重启成功！"
    else
        print_message "$RED" "服务重启失败！请检查日志"
        if [ "$mode" = "tmpfs" ]; then
            echo "查看日志: cat /tmp/nezha-bootstrap.log"
        else
            echo "查看日志: logread"
        fi
    fi
}

# 清理所有安装
cleanup_all_installations() {
    # 停止所有服务
    if [ -f "$SERVICE_FILE" ]; then
        /etc/init.d/nezha-service stop 2>/dev/null
        /etc/init.d/nezha-service disable 2>/dev/null
        rm -f "$SERVICE_FILE"
    fi
    
    if [ -f "$TMPFS_BOOTSTRAP" ]; then
        /etc/init.d/nezha-tmpfs-bootstrap stop 2>/dev/null
        /etc/init.d/nezha-tmpfs-bootstrap disable 2>/dev/null
        rm -f "$TMPFS_BOOTSTRAP"
    fi
    
    # 杀死进程
    killall nezha-agent 2>/dev/null
    
    # 删除 tmpfs 目录
    rm -rf "$TMPFS_INSTALL_DIR"
}

# 卸载服务
uninstall_agent() {
    print_message "$RED" "\n卸载 Nezha Agent..."
    echo -n "确认要卸载吗？此操作不可恢复 (y/n): "
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_message "$YELLOW" "取消卸载"
        return
    fi
    
    print_message "$GREEN" "正在卸载..."
    
    # 清理所有安装
    cleanup_all_installations
    
    # 删除持久化目录和配置
    print_message "$GREEN" "删除配置文件..."
    rm -rf "$INSTALL_DIR"
    
    print_message "$GREEN" "卸载完成！"
}

# 主循环
main() {
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                install_agent
                ;;
            2)
                install_agent_tmpfs
                ;;
            3)
                modify_config
                ;;
            4)
                check_status
                ;;
            5)
                restart_service
                ;;
            6)
                uninstall_agent
                ;;
            0)
                print_message "$GREEN" "退出脚本"
                exit 0
                ;;
            *)
                print_message "$RED" "无效选择，请重新输入"
                ;;
        esac
        
        echo ""
        echo -n "按回车键继续..."
        read
    done
}

# 运行主程序
main

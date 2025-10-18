#!/bin/sh
# Nezha Agent 一键安装管理脚本 for OpenWrt (MIPS)

INSTALL_DIR="/etc/nezha"
CONFIG_FILE="${INSTALL_DIR}/config.yml"
AGENT_BIN="${INSTALL_DIR}/nezha-agent"
SERVICE_FILE="/etc/init.d/nezha-service"
DOWNLOAD_URL="https://github.com/354770288/nezha-agent-mips/releases/download/v1.13.1/nezha-agent-linux-mipsle"

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

# 检查 nezha-agent 是否可运行
check_agent_executable() {
    if [ ! -f "$AGENT_BIN" ]; then
        return 1
    fi
    
    # 运行 --help 命令并检查输出
    local help_output=$("$AGENT_BIN" --help 2>&1)
    
    # 检查输出是否包含关键信息
    if echo "$help_output" | grep -q "NAME:" && echo "$help_output" | grep -q "nezha-agent - 哪吒监控 Agent"; then
        return 0
    else
        return 1
    fi
}

# 显示菜单
show_menu() {
    clear
    echo "======================================"
    echo "  Nezha Agent 一键管理脚本 (OpenWrt)"
    echo "======================================"
    echo "1. 安装 Nezha Agent"
    echo "2. 修改配置"
    echo "3. 查看服务状态"
    echo "4. 重启服务"
    echo "5. 卸载服务"
    echo "0. 退出"
    echo "======================================"
    echo -n "请选择操作 [0-5]: "
}

# 安装 Nezha Agent
install_agent() {
    print_message "$YELLOW" "\n开始安装 Nezha Agent..."
    
    local need_download=1
    
    # 检查是否已存在 nezha-agent 文件
    if [ -f "$AGENT_BIN" ]; then
        print_message "$YELLOW" "检测到已存在 Nezha Agent 文件，正在验证..."
        
        # 检查是否可运行
        if check_agent_executable; then
            print_message "$GREEN" "现有 Nezha Agent 可正常运行！"
            echo -n "是否跳过下载，直接进行配置？(y/n): "
            read skip_download
            if [ "$skip_download" = "y" ] || [ "$skip_download" = "Y" ]; then
                need_download=0
            fi
        else
            print_message "$RED" "现有 Nezha Agent 无法正常运行，将重新下载..."
            need_download=1
        fi
    fi
    
    # 创建安装目录
    print_message "$GREEN" "创建安装目录..."
    mkdir -p "$INSTALL_DIR"
    
    # 下载 Nezha Agent
    if [ $need_download -eq 1 ]; then
        print_message "$GREEN" "下载 Nezha Agent..."
        
        # 如果存在旧文件，直接删除
        if [ -f "$AGENT_BIN" ]; then
            print_message "$YELLOW" "删除旧程序文件..."
            rm -f "$AGENT_BIN"
        fi
        
        cd "$INSTALL_DIR"
        wget -O nezha-agent "$DOWNLOAD_URL" --no-check-certificate
        
        if [ $? -ne 0 ]; then
            print_message "$RED" "下载失败！请检查网络连接"
            return 1
        fi
        
        # 赋予执行权限
        chmod +x "$AGENT_BIN"
        
        # 验证下载的文件是否可运行
        print_message "$YELLOW" "验证下载的文件..."
        if ! check_agent_executable; then
            print_message "$RED" "下载的文件无法正常运行！"
            rm -f "$AGENT_BIN"
            return 1
        fi
        
        print_message "$GREEN" "程序下载成功且验证通过！"
    fi
    
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
    
    # 启用并启动服务
    print_message "$GREEN" "启用并启动服务..."
    /etc/init.d/nezha-service enable
    /etc/init.d/nezha-service start
    
    # 验证安装
    sleep 3
    if ps | grep -v grep | grep nezha-agent > /dev/null; then
        print_message "$GREEN" "\n安装成功！Nezha Agent 正在运行"
    else
        print_message "$RED" "\n安装完成但服务未启动，请检查配置"
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
        sed -i "s|^uuid:.*|uuid: $new_uuid|" "$CONFIG_FILE"
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
    
    if [ ! -f "$AGENT_BIN" ]; then
        print_message "$RED" "Nezha Agent 未安装！"
        return
    fi
    
    # 检查进程
    if ps | grep -v grep | grep nezha-agent > /dev/null; then
        print_message "$GREEN" "服务状态: 运行中"
        echo ""
        ps | grep nezha-agent | grep -v grep
    else
        print_message "$RED" "服务状态: 未运行"
    fi
    
    # 检查自启动状态
    if [ -f "$SERVICE_FILE" ]; then
        if ls /etc/rc.d/*nezha-service* > /dev/null 2>&1; then
            print_message "$GREEN" "开机自启: 已启用"
        else
            print_message "$YELLOW" "开机自启: 未启用"
        fi
    fi
}

# 重启服务
restart_service() {
    print_message "$YELLOW" "\n重启服务..."
    
    if [ ! -f "$SERVICE_FILE" ]; then
        print_message "$RED" "服务未安装！"
        return
    fi
    
    /etc/init.d/nezha-service restart
    
    sleep 3
    if ps | grep -v grep | grep nezha-agent > /dev/null; then
        print_message "$GREEN" "服务重启成功！"
    else
        print_message "$RED" "服务重启失败！请检查日志: logread"
    fi
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
    
    # 停止服务
    if [ -f "$SERVICE_FILE" ]; then
        print_message "$GREEN" "停止服务..."
        /etc/init.d/nezha-service stop
        /etc/init.d/nezha-service disable
    fi
    
    # 删除服务文件
    print_message "$GREEN" "删除服务文件..."
    rm -f "$SERVICE_FILE"
    
    # 删除安装目录
    print_message "$GREEN" "删除安装文件..."
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
                modify_config
                ;;
            3)
                check_status
                ;;
            4)
                restart_service
                ;;
            5)
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

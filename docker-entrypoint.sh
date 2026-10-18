#!/bin/sh
set -e

echo "=========================================="
echo "启动 Mihomo + Metacubexd 集成容器"
echo "=========================================="
echo "Mihomo 版本:      ${MI_VERSION}"
echo "Metacubexd 版本:  ${METACUBEXD_VERSION}"
echo "日志级别:         ${LOG_LEVEL:-info}"
echo "订阅名称:         ${SUBSCRIBE_NAME:-未设置}"
echo "=========================================="

# 配置路径
CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
TEMPLATE_FILE="/app/config.yaml.template"

# 1. 生成 Mihomo 配置文件
mkdir -p "${CONFIG_DIR}"
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "生成 Mihomo 配置文件..."
    if [ -f "${TEMPLATE_FILE}" ]; then
        envsubst '${LOG_LEVEL} ${CLASH_SECRET} ${SUBSCRIBE_NAME} ${SUBSCRIBE_URL}' < "${TEMPLATE_FILE}" > "${CONFIG_FILE}"
        echo "✅ 配置文件已生成: ${CONFIG_FILE}"
    else
        echo "❌ 错误: 未找到配置模板"
        exit 1
    fi
else
    echo "📁 使用现有配置文件: ${CONFIG_FILE}"
fi

# 2. 验证配置
echo "验证 Mihomo 配置..."
if mihomo -d "${CONFIG_DIR}" -t 2>/dev/null; then
    echo "✅ Mihomo 配置文件验证通过"
else
    echo "⚠️  Mihomo 配置文件验证失败，但继续启动..."
fi

# 3. 启动 Caddy Web 服务器
echo "启动 Caddy Web 服务器..."
caddy run --config /srv/Caddyfile --adapter caddyfile &

# 等待 Caddy 启动
sleep 2

# 4. 在前台启动 Mihomo
echo "启动 Mihomo 核心..."
mihomo -d "${CONFIG_DIR}" &
MIHOMO_PID=$!

stop_mihomo() {
    kill -TERM "${MIHOMO_PID}" 2>/dev/null || true
    wait "${MIHOMO_PID}" 2>/dev/null || true
}
trap stop_mihomo INT TERM

api_request() {
    if [ -n "${CLASH_SECRET:-}" ]; then
        curl -fsS -H "Authorization: Bearer ${CLASH_SECRET}" "$@"
    else
        curl -fsS "$@"
    fi
}

API_URL="http://127.0.0.1:9090"
API_READY=0
ATTEMPT=0
while [ "${ATTEMPT}" -lt 30 ]; do
    if ! kill -0 "${MIHOMO_PID}" 2>/dev/null; then
        wait "${MIHOMO_PID}"
        exit $?
    fi
    if api_request -o /dev/null "${API_URL}/version" 2>/dev/null; then
        API_READY=1
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 1
done

update_provider() {
    provider_type="$1"
    provider_name="$2"
    if api_request -X PUT -o /dev/null "${API_URL}/providers/${provider_type}/${provider_name}/"; then
        echo "✅ 已更新 ${provider_type} provider: ${provider_name}"
    else
        echo "⚠️ 更新 ${provider_type} provider 失败，继续使用已有缓存（若存在）: ${provider_name}" >&2
    fi
}

has_configured_provider() {
    section_name="$1"
    provider_name="$2"
    awk -v section_name="${section_name}" -v provider_name="${provider_name}" '
        $0 == section_name ":" {
            in_section = 1
            next
        }
        in_section && /^[^[:space:]#]/ {
            in_section = 0
        }
        in_section && $0 == "  " provider_name ":" {
            found = 1
            exit
        }
        END {
            if (!found) {
                exit 1
            }
        }
    ' "${CONFIG_FILE}"
}

if [ "${API_READY}" -eq 1 ]; then
    echo "启动时更新订阅和 ACL4SSR 规则..."
    case "${SUBSCRIBE_NAME:-default}" in
        ''|*[!A-Za-z0-9_.-]*)
            echo "⚠️ SUBSCRIBE_NAME 仅支持字母、数字、点、下划线和连字符；跳过订阅自动更新。" >&2
            ;;
        *)
            if has_configured_provider proxy-providers "${SUBSCRIBE_NAME:-default}"; then
                update_provider proxies "${SUBSCRIBE_NAME:-default}"
            else
                echo "ℹ️ 当前配置未定义该 proxy provider，跳过订阅自动更新。"
            fi
            ;;
    esac

    for provider_name in \
        local_area_network unban ban_ad ban_program_ad \
        adblock_easylist adblock_easylist_china privacy \
        google_fcm google_cn steam_cn bing onedrive microsoft apple telegram \
        ai openai netease_music epic origin sony steam nintendo youtube netflix \
        bahamut bilibili_hmt bilibili china_media proxy_media proxy_gfw \
        china_domain china_company_ip download
    do
        if has_configured_provider rule-providers "${provider_name}"; then
            update_provider rules "${provider_name}"
        fi
    done
else
    echo "⚠️ Mihomo 控制 API 未就绪，跳过启动时 provider 更新；继续运行已有配置。" >&2
fi

wait "${MIHOMO_PID}"
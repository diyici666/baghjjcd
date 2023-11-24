#!/usr/bin/env bash

# 设置各变量
WSPATH=${WSPATH:-'arco'}
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
WEB_USERNAME=${WEB_USERNAME:-'admin'}
WEB_PASSWORD=${WEB_PASSWORD:-'password'}

generate_config() {
  cat > /app/config.json << EOF
{
    "log":{
        "access":"/dev/null",
        "error":"/dev/null",
        "loglevel":"none"
    },
    "inbounds":[
        {
            "port":8080,
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "flow":"xtls-rprx-vision"
                    }
                ],
                "decryption":"none",
                "fallbacks":[
                    {
                        "dest":3001
                    },
                    {
                        "path":"/${WSPATH}-vless",
                        "dest":3002
                    },
                    {
                        "path":"/${WSPATH}-vmess",
                        "dest":3003
                    },
                    {
                        "path":"/${WSPATH}-trojan",
                        "dest":3004
                    },
                    {
                        "path":"/${WSPATH}-shadowsocks",
                        "dest":3005
                    }
                ]
            },
            "streamSettings":{
                "network":"tcp"
            }
        },
        {
            "port":3001,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none"
            }
        },
        {
            "port":3002,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "level":0
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${WSPATH}-vless"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3003,
            "listen":"127.0.0.1",
            "protocol":"vmess",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "alterId":0
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/${WSPATH}-vmess"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3004,
            "listen":"127.0.0.1",
            "protocol":"trojan",
            "settings":{
                "clients":[
                    {
                        "password":"${UUID}"
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${WSPATH}-trojan"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3005,
            "listen":"127.0.0.1",
            "protocol":"shadowsocks",
            "settings":{
                "clients":[
                    {
                        "method":"chacha20-ietf-poly1305",
                        "password":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/${WSPATH}-shadowsocks"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls"
                ],
                "metadataOnly":false
            }
        }
    ],
    "dns":{
        "servers":[
            "https+local://8.8.8.8/dns-query"
        ]
    },
    "outbounds":[
        {
            "protocol":"freedom"
        },
        {
            "tag":"WARP",
            "protocol":"wireguard",
            "settings":{
                "secretKey":"cKE7LmCF61IhqqABGhvJ44jWXp8fKymcMAEVAzbDF2k=",
                "address":[
                    "172.16.0.2/32",
                    "fd01:5ca1:ab1e:823e:e094:eb1c:ff87:1fab/128"
                ],
                "peers":[
                    {
                        "publicKey":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                        "endpoint":"162.159.193.10:2408"
                    }
                ]
            }
        }
    ],
    "routing":{
        "domainStrategy":"AsIs",
        "rules":[
            {
                "type":"field",
                "domain":[
                    "domain:openai.com",
                    "domain:ai.com"
                ],
                "outboundTag":"WARP"
            }
        ]
    }
}
EOF
}

generate_arco() {
  cat > /app/arco.sh << ABC
#!/usr/bin/env bash

arco_type() {
  if [[ -n "\${ARCO_AUTH}" && -n "\${ARCO_DOMAIN}" ]]; then
    [[ \$ARCO_AUTH =~ TunnelSecret ]] && echo \$ARCO_AUTH > /app/arco.json && cat > /app/arco.yml << EOF
tunnel: \$(cut -d\" -f12 <<< \$ARCO_AUTH)
credentials-file: /app/arco.json
protocol: h2mux

ingress:
  - hostname: \$ARCO_DOMAIN
    service: http://localhost:8080
EOF

    [ -n "\${SSH_DOMAIN}" ] && cat >> /app/arco.yml << EOF
  - hostname: \$SSH_DOMAIN
    service: http://localhost:2222
EOF

    cat >> /app/arco.yml << EOF
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF

  else
    ARCO_DOMAIN=\$(cat /app/arco.log | grep -o "info.*https://.*trycloudflare.com" | sed "s@.*https://@@g" | tail -n 1)
  fi
}

export_list() {
  VMESS="{ \"v\": \"2\", \"ps\": \"Arco-Vmess\", \"add\": \"icook.hk\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\${ARCO_DOMAIN}\", \"path\": \"/${WSPATH}-vmess?ed=2048\", \"tls\": \"tls\", \"sni\": \"\${ARCO_DOMAIN}\", \"alpn\": \"\" }"

  cat > /app/list << EOF
*******************************************
V2-rayN:
----------------------------
vless://${UUID}@icook.hk:443?encryption=none&security=tls&sni=\${ARCO_DOMAIN}&type=ws&host=\${ARCO_DOMAIN}&path=%2F${WSPATH}-vless?ed=2048#Arco-Vless
----------------------------
vmess://\$(echo \$VMESS | base64 -w0)
----------------------------
trojan://${UUID}@icook.hk:443?security=tls&sni=\${ARCO_DOMAIN}&type=ws&host=\${ARCO_DOMAIN}&path=%2F${WSPATH}-trojan?ed=2048#Arco-Trojan
----------------------------
ss://$(echo "chacha20-ietf-poly1305:${UUID}@icook.hk:443" | base64 -w0)@icook.hk:443#Arco-Shadowsocks
由于该软件导出的链接不全，请自行处理如下: 传输协议: WS ， 伪装域名: \${ARCO_DOMAIN} ，路径: /${WSPATH}-shadowsocks?ed=2048 ， 传输层安全: tls ， sni: \${ARCO_DOMAIN}
*******************************************
小火箭:
----------------------------
vless://${UUID}@icook.hk:443?encryption=none&security=tls&type=ws&host=\${ARCO_DOMAIN}&path=/${WSPATH}-vless?ed=2048&sni=\${ARCO_DOMAIN}#Arco-Vless
----------------------------
vmess://$(echo "none:${UUID}@icook.hk:443" | base64 -w0)?remarks=Arco-Vmess&obfsParam=\${ARCO_DOMAIN}&path=/${WSPATH}-vmess?ed=2048&obfs=websocket&tls=1&peer=\${ARCO_DOMAIN}&alterId=0
----------------------------
trojan://${UUID}@icook.hk:443?peer=\${ARCO_DOMAIN}&plugin=obfs-local;obfs=websocket;obfs-host=\${ARCO_DOMAIN};obfs-uri=/${WSPATH}-trojan?ed=2048#Arco-Trojan
----------------------------
ss://$(echo "chacha20-ietf-poly1305:${UUID}@icook.hk:443" | base64 -w0)?obfs=wss&obfsParam=\${ARCO_DOMAIN}&path=/${WSPATH}-shadowsocks?ed=2048#Arco-Shadowsocks
*******************************************
Clash:
----------------------------
- {name: Arco-Vless, type: vless, server: icook.hk, port: 443, uuid: ${UUID}, tls: true, servername: \${ARCO_DOMAIN}, skip-cert-verify: false, network: ws, ws-opts: {path: /${WSPATH}-vless?ed=2048, headers: { Host: \${ARCO_DOMAIN}}}, udp: true}
----------------------------
- {name: Arco-Vmess, type: vmess, server: icook.hk, port: 443, uuid: ${UUID}, alterId: 0, cipher: none, tls: true, skip-cert-verify: true, network: ws, ws-opts: {path: /${WSPATH}-vmess?ed=2048, headers: {Host: \${ARCO_DOMAIN}}}, udp: true}
----------------------------
- {name: Arco-Trojan, type: trojan, server: icook.hk, port: 443, password: ${UUID}, udp: true, tls: true, sni: \${ARCO_DOMAIN}, skip-cert-verify: false, network: ws, ws-opts: { path: /${WSPATH}-trojan?ed=2048, headers: { Host: \${ARCO_DOMAIN} } } }
----------------------------
- {name: Arco-Shadowsocks, type: ss, server: icook.hk, port: 443, cipher: chacha20-ietf-poly1305, password: ${UUID}, plugin: v2ray-plugin, plugin-opts: { mode: websocket, host: \${ARCO_DOMAIN}, path: /${WSPATH}-shadowsocks?ed=2048, tls: true, skip-cert-verify: false, mux: false } }
*******************************************
EOF
  cat /app/list
}

arco_type
export_list
ABC
}

generate_nezha() {
  cat > /app/nezha.sh << EOF
#!/usr/bin/env bash

# 检测是否已运行
check_run() {
  [[ \$(pgrep -lafx nezha-agent) ]] && echo "哪吒客户端正在运行中" && exit
}

# 三个变量不全则不安装哪吒客户端
check_variable() {
  [[ -z "\${NEZHA_SERVER}" || -z "\${NEZHA_PORT}" || -z "\${NEZHA_KEY}" ]] && exit
}

# 下载最新版本 Nezha Agent
download_agent() {
  if [ ! -e /app/nezha-agent ]; then
    URL=\$(wget -qO- "https://api.github.com/repos/nezhahq/agent/releases/latest" | grep -o "https.*linux_amd64.zip")
    URL=\${URL:-https://github.com/nezhahq/agent/releases/download/v0.15.6/nezha-agent_linux_amd64.zip}
    wget -P /app/ \${URL}
    unzip -qod /app/ /app/nezha-agent_linux_amd64.zip
    rm -f /app/nezha-agent_linux_amd64.zip
  fi
}

check_run
check_variable
download_agent
EOF
}

generate_ttyd() {
  cat > /app/ttyd.sh << EOF
#!/usr/bin/env bash

# 检测是否已运行
check_run() {
  [[ \$(pgrep -lafx ttyd) ]] && echo "ttyd 正在运行中" && exit
}

# ssh arco 域名不设置，则不安装 ttyd 服务端
check_variable() {
  [ -z "\${SSH_DOMAIN}" ] && exit
}

# 下载最新版本 ttyd
download_ttyd() {
  if [ ! -e /app/ttyd ]; then
    URL=\$(wget -qO- "https://api.github.com/repos/tsl0922/ttyd/releases/latest" | grep -o "https.*x86_64")
    URL=\${URL:-https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64}
    wget -O /app/ttyd \${URL}
    chmod +x /app/ttyd
  fi
}

check_run
check_variable
download_ttyd
EOF
}

generate_pm2_file() {
  if [[ -n "${ARCO_AUTH}" && -n "${ARCO_DOMAIN}" ]]; then
    [[ $ARCO_AUTH =~ TunnelSecret ]] && ARCO_ARGS="tunnel --edge-ip-version auto --config /app/arco.yml run"
    [[ $ARCO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]] && ARCO_ARGS="tunnel --edge-ip-version auto --protocol h2mux run --token ${ARCO_AUTH}"
  else
    ARCO_ARGS="tunnel --edge-ip-version auto --protocol h2mux --no-autoupdate --logfile /app/arco.log --loglevel info --url http://localhost:8080"
  fi

  TLS=${NEZHA_TLS:+'--tls'}

  cat > /app/ecosystem.config.js << EOF
module.exports = {
  "apps":[
      {
          "name":"web",
          "script":"/app/web.js run"
      },
      {
          "name":"arco",
          "script":"cloudflared",
          "args":"${ARCO_ARGS}"
EOF

  [[ -n "${NEZHA_SERVER}" && -n "${NEZHA_PORT}" && -n "${NEZHA_KEY}" ]] && cat >> /app/ecosystem.config.js << EOF
      },
      {
          "name":"nezha",
          "script":"/app/nezha-agent",
          "args":"-s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${TLS}"
EOF
  
  [ -n "${SSH_DOMAIN}" ] && cat >> /app/ecosystem.config.js << EOF
      },
      {
          "name":"ttyd",
          "script":"/app/ttyd",
          "args":"-c ${WEB_USERNAME}:${WEB_PASSWORD} -p 2222 bash"
EOF

  cat >> /app/ecosystem.config.js << EOF
      }
  ]
}
EOF
}

generate_config
generate_arco
generate_nezha
generate_ttyd
generate_pm2_file

[ -e /app/nezha.sh ] && bash /app/nezha.sh
[ -e /app/arco.sh ] && bash /app/arco.sh
[ -e /app/ttyd.sh ] && bash /app/ttyd.sh
[ -e /app/ecosystem.config.js ] && pm2 start /app/ecosystem.config.js

#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e '\e[34m'
echo -e '$$\   $$\ $$$$$$$$\      $$$$$$$$\           $$\                                       $$\     '
echo -e '$$$\  $$ |\__$$  __|     $$  _____|          $$ |                                      $$ |    '
echo -e '$$$$\ $$ |   $$ |        $$ |      $$\   $$\ $$$$$$$\   $$$$$$\  $$\   $$\  $$$$$$$\ $$$$$$\   '
echo -e '$$ $$\$$ |   $$ |$$$$$$\ $$$$$\    \$$\ $$  |$$  __$$\  \____$$\ $$ |  $$ |$$  _____|\_$$  _|  '
echo -e '$$ \$$$$ |   $$ |\______|$$  __|    \$$$$  / $$ |  $$ | $$$$$$$ |$$ |  $$ |\$$$$$$\    $$ |    '
echo -e '$$ |\$$$ |   $$ |        $$ |       $$  $$<  $$ |  $$ |$$  __$$ |$$ |  $$ | \____$$\   $$ |$$\ '
echo -e '$$ | \$$ |   $$ |        $$$$$$$$\ $$  /\$$\ $$ |  $$ |\$$$$$$$ |\$$$$$$  |$$$$$$$  |  \$$$$  |'
echo -e '\__|  \__|   \__|        \________|\__/  \__|\__|  \__| \_______| \______/ \_______/    \____/ '
echo -e '\e[0m'
echo -e "Join our Telegram channel: https://t.me/NTExhaust"
sleep 5

# ===== Instalasi Docker =====
echo -e "${GREEN}▶ Memulai proses instalasi Docker...${NC}"
sleep 2

sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

if command -v docker &> /dev/null; then
  echo -e "${GREEN}✅ Docker berhasil diinstal! Versi: $(docker --version)${NC}"
else
  echo -e "${RED}❌ Gagal menginstal Docker.${NC}"
  exit 1
fi

# ===== Firewall (UFW) =====
echo -e "${GREEN}▶ Mengatur firewall dan membuka port yang diperlukan...${NC}"
sleep 2

if ! command -v ufw &> /dev/null; then
  echo -e "${YELLOW}⚠️  UFW belum terinstal. Menginstal...${NC}"
  sudo apt-get install -y ufw
fi

sudo ufw allow 22/tcp
sudo ufw allow 5011/tcp
sudo ufw allow 1194/udp

UFW_STATUS=$(sudo ufw status | grep -i "Status: active")
if [ -z "$UFW_STATUS" ]; then
  echo -e "${YELLOW}⚠️  Mengaktifkan UFW...${NC}"
  echo "y" | sudo ufw enable
else
  echo -e "${CYAN}✅ Firewall sudah aktif.${NC}"
fi

echo -e "${CYAN}📋 Aturan firewall saat ini:${NC}"
sudo ufw status verbose

# ===== Unduh & Jalankan Installer Worker Node =====
echo -e "${GREEN}▶ Menyiapkan Worker Node...${NC}"
sleep 2

INSTALLER_URL="https://raw.githubusercontent.com/admier1/BrinxAI-Worker-Nodes/refs/heads/main/install_brinxai_worker_amd64_deb.sh"
INSTALLER_NAME="install_brinxai_worker_amd64_deb.sh"

if [ ! -f "$INSTALLER_NAME" ]; then
  wget "$INSTALLER_URL" -O $INSTALLER_NAME
  chmod +x $INSTALLER_NAME
fi
./"$INSTALLER_NAME"

# ===== Menu Multi Pilihan Model =====
echo -e "${GREEN}▶ Pilih model BrinxAI yang ingin dijalankan (pisahkan dengan spasi, contoh: 1 3 5):${NC}"
echo -e "${CYAN}1.${NC} Text UI           (CPU: 4 | RAM: 4GB | Port: 5000)"
echo -e "${CYAN}2.${NC} Rembg             (CPU: 2 | RAM: 2GB | Port: 7000)"
echo -e "${CYAN}3.${NC} Upscaler          (CPU: 2 | RAM: 2GB | Port: 3000)"
echo -e "${CYAN}4.${NC} Stable Diffusion  (CPU: 8 | RAM: 8GB | Port: 5050)"
echo -e "${CYAN}5.${NC} Relay Node        (CPU: 1 | RAM: 256MB | Port: 1194 UDP)"
read -p "Masukkan pilihan Anda (contoh: 1 3 5): " -a model_choices

docker network create brinxai-network &>/dev/null || true

run_model_safe() {
  NAME=$1
  CPU=$2
  MEM=$3
  PORT=$4
  IMAGE=$5

  if docker ps -a --format '{{.Names}}' | grep -q "^$NAME$"; then
    echo -e "${YELLOW}⚠️  Container '$NAME' sudah ada. Lewatkan...${NC}"
  else
    echo -e "${CYAN}▶ Menjalankan $NAME...${NC}"
    docker run -d --name $NAME --restart=unless-stopped \
      --network brinxai-network --cpus=$CPU --memory=${MEM}m \
      -p 127.0.0.1:$PORT:$PORT $IMAGE
  fi
}

for choice in "${model_choices[@]}"; do
  case "$choice" in
    1) run_model_safe "text-ui" 4 4096 5000 "admier/brinxai_nodes-text-ui:latest" ;;
    2) run_model_safe "rembg" 2 2048 7000 "admier/brinxai_nodes-rembg:latest" ;;
    3) run_model_safe "upscaler" 2 2048 3000 "admier/brinxai_nodes-upscaler:latest" ;;
    4) run_model_safe "stable-diffusion" 8 8192 5050 "admier/brinxai_nodes-stabled:latest" ;;
    5)
      echo -e "${CYAN}▶ Menyiapkan Relay Node...${NC}"
      sudo ufw allow 1194/udp

      INSTALLER_URL_RELAY="https://raw.githubusercontent.com/admier1/BrinxAI-Relay-Nodes/refs/heads/main/install_brinxai_relay_amd64_deb.sh"
      INSTALLER_NAME_RELAY="install_brinxai_relay_amd64_deb.sh"

      if [ ! -f "$INSTALLER_NAME_RELAY" ]; then
        wget "$INSTALLER_URL_RELAY" -O $INSTALLER_NAME_RELAY
        chmod +x $INSTALLER_NAME_RELAY
      fi
      ./"$INSTALLER_NAME_RELAY"
      ;;
    *) echo -e "${RED}❌ Pilihan tidak valid: $choice${NC}" ;;
  esac
done

echo -e "${GREEN}✅ Semua model yang dipilih telah dijalankan.${NC} ${CYAN}docker ps -a untuk melihat kontainer.${NC}"
echo -e "${YELLOW}Gunakan perintah berikut untuk melihat log:${NC} ${CYAN}docker logs -f <nama_kontainer>${NC}"

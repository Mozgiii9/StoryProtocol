#!/bin/bash

while true
do

# Логотип

echo -e '\e[40m\e[91m'
echo -e '-----------------------------------------------------------------------------'
echo -e '███╗   ██╗ ██████╗ ██████╗ ███████╗██████╗ ██╗   ██╗███╗   ██╗███╗   ██╗███████╗██████╗ '
echo -e '████╗  ██║██╔═══██╗██╔══██╗██╔════╝██╔══██╗██║   ██║████╗  ██║████╗  ██║██╔════╝██╔══██╗'
echo -e '██╔██╗ ██║██║   ██║██║  ██║█████╗  ██████╔╝██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██████╔╝'
echo -e '██║╚██╗██║██║   ██║██║  ██║██╔══╝  ██╔══██╗██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██╔══██╗'
echo -e '██║ ╚████║╚██████╔╝██████╔╝███████╗██║  ██║╚██████╔╝██║ ╚████║██║ ╚████║███████╗██║  ██║'
echo -e '╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝'
echo -e '-----------------------------------------------------------------------------'
echo -e '\e[0m'

sleep 2

# Меню

PS3='Выберите действие: '
options=(
"Установить ноду Story"
"Проверить кошелек"
"Создать валидатор"
"Выход")
select opt in "${options[@]}"
do
case $opt in

"Установить ноду Story")
echo "============================================================"
echo "Начало установки"
echo "============================================================"

# Установка переменных
NODE="story"
DAEMON_HOME="$HOME/.story/story"
DAEMON_NAME="story"
if [ -d "$DAEMON_HOME" ]; then
    new_folder_name="${DAEMON_HOME}_$(date +"%Y%m%d_%H%M%S")"
    mv "$DAEMON_HOME" "$new_folder_name"
fi

if [ ! $VALIDATOR ]; then
    read -p "Введите имя валидатора: " VALIDATOR
    echo 'export VALIDATOR='\"${VALIDATOR}\" >> $HOME/.bash_profile
fi

# Ввод портов
read -p "Введите порт для p2p (по умолчанию 26656): " P2P_PORT
P2P_PORT=${P2P_PORT:-26656} # Если ввод пустой, используется 26656

read -p "Введите порт для RPC (по умолчанию 26657): " RPC_PORT
RPC_PORT=${RPC_PORT:-26657} # Если ввод пустой, используется 26657

read -p "Введите порт для API (по умолчанию 1317): " API_PORT
API_PORT=${API_PORT:-1317} # Если ввод пустой, используется 1317

# Обновление
sudo apt update && sudo apt upgrade -y

# Установка пакетов
apt install curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 aria2 pv -y

# Установка Go
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.21.6.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
source $HOME/.bash_profile
sleep 1

# Загрузка бинарного файла
cd $HOME
sudo rm -rf story
wget -O story-linux-amd64-0.10.0-9603826.tar.gz https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.10.0-9603826.tar.gz
tar xvf story-linux-amd64-0.10.0-9603826.tar.gz
sudo chmod +x story-linux-amd64-0.10.0-9603826/story
sudo mv story-linux-amd64-0.10.0-9603826/story /usr/local/bin/
story version

cd $HOME
rm -rf story-geth
wget -O geth-linux-amd64-0.9.2-ea9f0d2.tar.gz https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.2-ea9f0d2.tar.gz 
tar xvf geth-linux-amd64-0.9.2-ea9f0d2.tar.gz
sudo chmod +x geth-linux-amd64-0.9.2-ea9f0d2/geth
sudo mv geth-linux-amd64-0.9.2-ea9f0d2/geth /usr/local/bin/story-geth

# Инициализация
$DAEMON_NAME init --network iliad  --moniker "${VALIDATOR}"
sleep 1
$DAEMON_NAME validator export --export-evm-key --evm-key-path $HOME/.story/.env
$DAEMON_NAME validator export --export-evm-key >>$HOME/.story/story/config/wallet.txt
cat $HOME/.story/.env >>$HOME/.story/story/config/wallet.txt

# Загрузка genesis и addrbook
wget -O $HOME/.story/story/config/addrbook.json https://raw.githubusercontent.com/McDaan/general/main/story/addrbook.json

# Установка пиров и сидов
PEERS=$(curl -sS https://story-rpc.mandragora.io/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd, -)
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.story/story/config/config.toml

SEEDS=6a07e2f396519b55ea05f195bac7800b451983c0@story-seed.mandragora.io:26656,51ff395354c13fab493a03268249a74860b5f9cc@story-testnet-seed.itrocket.net:26656,5d7507dbb0e04150f800297eaba39c5161c034fe@135.125.188.77:26656
sed -i.bak -e "s/^seeds *=.*/seeds = \"$SEEDS\"/" $HOME/.story/story/config/config.toml

# Создание сервиса
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF  
[Unit]
Description=Story execution daemon
After=network-online.target

[Service]
User=$USER
ExecStart=/usr/local/bin/story-geth --iliad --syncmode full
Restart=always
RestartSec=3
LimitNOFILE=infinity
LimitNPROC=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/$NODE.service > /dev/null <<EOF  
[Unit]
Description=Story consensus daemon
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/.story/story
ExecStart=/usr/local/bin/story run --p2p.port $P2P_PORT --rpc.port $RPC_PORT --api.port $API_PORT
Restart=always
RestartSec=3
LimitNOFILE=infinity
LimitNPROC=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF

# Сброс
sudo rm -rf $HOME/.story/geth/iliad/geth/chaindata
sudo rm -rf $HOME/.story/story/data

wget -O geth_snapshot.lz4 https://snapshots.mandragora.io/geth_snapshot.lz4
wget -O story_snapshot.lz4 https://snapshots.mandragora.io/story_snapshot.lz4

lz4 -c -d geth_snapshot.lz4 | tar -x -C $HOME/.story/geth/iliad/geth
lz4 -c -d story_snapshot.lz4 | tar -x -C $HOME/.story/story

sudo rm -v geth_snapshot.lz4
sudo rm -v story_snapshot.lz4

# Проверка портов
if ss -tulpen | awk '{print $5}' | grep -q ":$P2P_PORT$" ; then
    echo -e "\e[31mПорт $P2P_PORT уже занят.\e[39m"
    sleep 2
    sed -i -e "s|:$P2P_PORT\"|:${PORT}56\"|g" $DAEMON_HOME/config/config.toml
    echo -e "\n\e[42mПорт $P2P_PORT изменен.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":$RPC_PORT$" ; then
    echo -e "\e[31mПорт $RPC_PORT уже занят.\e[39m"
    sleep 2
    sed -i -e "s|:$RPC_PORT\"|:${PORT}57\"|" $DAEMON_HOME/config/config.toml
    echo -e "\n\e[42mПорт $RPC_PORT изменен.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":$API_PORT$" ; then
    echo -e "\e[31mПорт $API_PORT уже занят.\e[39m"
    sleep 2
    sed -i -e "s|:$API_PORT\"|:${PORT}17\"|" $DAEMON_HOME/config/story.toml
    echo -e "\n\e[42mПорт $API_PORT изменен.\e[0m\n"
    sleep 2
fi

# Запуск сервиса
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable $NODE
sudo systemctl restart $NODE
sudo systemctl enable story-geth
sudo systemctl restart story-geth

break
;;

"Проверить кошелек")
story validator export | grep "EVM Public Key:" | awk '{print $NF}'

break
;;

"Создать валидатор")
cd $HOME/.story
story validator create --stake 1000000000000000000

break
;;

"Выход")
exit
;;
*) echo "Неверный вариант $REPLY";;
esac
done
done

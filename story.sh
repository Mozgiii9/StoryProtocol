#!/bin/bash

while true
do

# Логотип

echo -e '\e[32m'
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

# Ввод портов пользователем
read -p "Введите порт для P2P (по умолчанию 26656): " P2P_PORT
P2P_PORT=${P2P_PORT:-26656}  # Если ввод пустой, используется порт по умолчанию 26656

read -p "Введите порт для RPC (по умолчанию 26657): " RPC_PORT
RPC_PORT=${RPC_PORT:-26657}  # Если ввод пустой, используется порт по умолчанию 26657

read -p "Введите порт для API (по умолчанию 1317): " API_PORT
API_PORT=${API_PORT:-1317}  # Если ввод пустой, используется порт по умолчанию 1317

# Проверяем занятость портов и предупреждаем пользователя, если порты уже используются
if ss -tulpen | awk '{print $5}' | grep -q ":$P2P_PORT$" ; then
    echo -e "\e[31mПорт $P2P_PORT уже занят.\e[39m"
    exit 1  # Прекращаем выполнение, чтобы избежать конфликта
fi

if ss -tulpen | awk '{print $5}' | grep -q ":$RPC_PORT$" ; then
    echo -e "\e[31mПорт $RPC_PORT уже занят.\e[39m"
    exit 1
fi

if ss -tulpen | awk '{print $5}' | grep -q ":$API_PORT$" ; then
    echo -e "\e[31mПорт $API_PORT уже занят.\e[39m"
    exit 1
fi

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
rm -rf story
git clone https://github.com/piplabs/story
cd $HOME/story
git checkout v0.11.0
go build -o story ./client
sudo mv $HOME/story/story $(which story)
story version

cd $HOME
rm -rf story-geth
wget -O geth-linux-amd64-0.9.3-b224fdf.tar.gz https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.3-b224fdf.tar.gz 
tar xvf geth-linux-amd64-0.9.3-b224fdf.tar.gz
sudo chmod +x geth-linux-amd64-0.9.3-b224fdf/geth
sudo mv geth-linux-amd64-0.9.3-b224fdf/geth /usr/local/bin/story-geth

# Инициализация
$DAEMON_NAME init --network iliad  --moniker "${VALIDATOR}"
sleep 1
$DAEMON_NAME validator export --export-evm-key --evm-key-path $HOME/.story/.env
$DAEMON_NAME validator export --export-evm-key >>$HOME/.story/story/config/wallet.txt
cat $HOME/.story/.env >>$HOME/.story/story/config/wallet.txt

# Загрузка genesis и addrbook
wget -O $HOME/.story/story/config/genesis.json https://server-3.itrocket.net/testnet/story/genesis.json
wget -O $HOME/.story/story/config/addrbook.json  https://server-3.itrocket.net/testnet/story/addrbook.json

# Установка пиров и сидов
SEEDS="51ff395354c13fab493a03268249a74860b5f9cc@story-testnet-seed.itrocket.net:26656"
PEERS="2f372238bf86835e8ad68c0db12351833c40e8ad@story-testnet-peer.itrocket.net:26656,343507f6105c8ebced67765e6d5bf54bc2117371@38.242.234.33:26656,de6a4d04aab4e22abea41d3a4cf03f3261422da7@65.109.26.242:25556,7844c54e061b42b9ed629b82f800f2a0055b806d@37.27.131.251:26656,1d3a0e76b5cdf550e8a0351c9c8cd9b5285be8a2@77.237.241.33:26656,f1ec81f4963e78d06cf54f103cb6ca75e19ea831@217.76.159.104:26656,2027b0adffea21f09d28effa3c09403979b77572@198.178.224.25:26656,118f21ef834f02ab91e3fc3e537110efb4c1c0ac@74.118.140.190:26656,8876a2351818d73c73d97dcf53333e6b7a58c114@3.225.157.207:26656,caf88cbcd0628188999104f5ea6a5eed4a34422c@178.63.184.134:26656,7f72d44f3d448fd44485676795b5cb3b62bf5af0@142.132.135.125:20656"
sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" \
       -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" $HOME/.story/story/config/config.toml

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
ExecStart=/usr/local/bin/story run
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

# Запись указанных портов в файл конфигурации story.toml
cat > $DAEMON_HOME/config/story.toml <<EOF
# Конфигурация для Story node
[p2p]
laddr = "tcp://0.0.0.0:$P2P_PORT"

[rpc]
laddr = "tcp://0.0.0.0:$RPC_PORT"

[api]
address = "tcp://0.0.0.0:$API_PORT"
EOF

echo -e "\n\e[42mПорты сохранены в story.toml: P2P=$P2P_PORT, RPC=$RPC_PORT, API=$API_PORT.\e[0m\n"

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

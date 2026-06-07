#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define resource path
KALI_RESOURCES_PATH="https://raw.githubusercontent.com/OPTips/kali-resources/refs/heads/master/"

# Get user name
USER_NAME=$(whoami)

# Get user desktop folder
USER_DESKTOP=$(xdg-user-dir DESKTOP)

# Get architecture
ARCHI=$(uname -m)
if [ "${ARCHI}" = "aarch64" ] || [ "${ARCHI}" = "arm64" ]; then
    ARCH="arm64"
else
    ARCH="x64"
fi

# Get Virtual Env
VIRT_ENV=$(systemd-detect-virt | awk '{print tolower($0)}')

# Debug variables
echo "[*] user_name: ${USER_NAME}"
echo "[*] user_desktop: ${USER_DESKTOP}"
echo "[*] arch: ${ARCH}"
echo "[*] virt_env: ${VIRT_ENV}"

# Force the use of the reliable Cloudflare CDN mirror to bypass geographical load-balancer issues
echo "[*] Configuring stable Kali download CDN..."
echo "deb http://kali.download/kali kali-rolling main contrib non-free non-free-firmware" | sudo tee /etc/apt/sources.list > /dev/null

# Remove any potentially conflicting repository sources from third parties
echo "[*] Removing conflicting repository sources..."
sudo rm -f /etc/apt/sources.list.d/*

# Thoroughly clean the local apt cache and corrupted lists before updating
echo "[*] Cleaning apt cache and updating lists..."
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get clean
sudo apt-get update

# Install vscode
echo "[*] Installing vscode..."
VSCODE_DEB=$(mktemp /tmp/vscode.XXXXXX.deb)
wget -qO "${VSCODE_DEB}" "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-${ARCH}"
sudo apt-get install -y "${VSCODE_DEB}"
rm -f "${VSCODE_DEB}"

# Install packages including pipx
echo "[*] Installing packages..."
sudo apt-get install -y burpsuite curl enum4linux feroxbuster gobuster \
    golang-go impacket-scripts ncdu nikto nmap pipx python3-pip \
    python3-venv seclists smbclient smbmap terminator tor

# Ensure pipx path is set correctly for the user
echo "[*] Running pipx ensurepath..."
pipx ensurepath

# Create terminator config folder
echo "[*] Setting up Terminator..."
mkdir -p ~/.config/terminator

# Copy terminator config file
wget -qO ~/.config/terminator/config "${KALI_RESOURCES_PATH}terminator_config"

# Set Terminator as the default system terminal (This links Ctrl+Alt+T to Terminator)
echo "[*] Setting Terminator as the default terminal emulator..."
sudo update-alternatives --set x-terminal-emulator /usr/bin/terminator
mkdir -p ~/.config/xfce4
echo "TerminalEmulator=terminator" > ~/.config/xfce4/helpers.rc

# Unpack rockyou (ignoring errors if it fails or is already unpacked)
echo "[*] Unpacking rockyou..."
if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
    sudo gunzip -d /usr/share/wordlists/rockyou.txt.gz || true
fi

# Copy aliases
echo "[*] Configuring aliases..."
wget -qO ~/.aliases "${KALI_RESOURCES_PATH}.aliases"

# Load aliases in .zshrc idempotently
if ! grep -q "\. ~/.aliases" ~/.zshrc; then
    cat << 'EOF' >> ~/.zshrc

# Load custom aliases
if [ -f ~/.aliases ]; then
    . ~/.aliases
fi
EOF
fi

# Install penelope via pipx
echo "[*] Installing penelope..."
pipx install git+https://github.com/brightio/penelope

# Setting VIM
echo "[*] Configuring VIM..."
VIM_CONTENT="source \$VIMRUNTIME/defaults.vim
set mouse-=a"

echo "$VIM_CONTENT" > "/home/${USER_NAME}/.vimrc"
echo "$VIM_CONTENT" | sudo tee /root/.vimrc > /dev/null

# Copy scripts
echo "[*] Downloading custom scripts..."
for script in upload monip nmaper vpn-connect; do
    sudo wget -qO "/usr/local/bin/${script}" "${KALI_RESOURCES_PATH}${script}"
    sudo chmod +x "/usr/local/bin/${script}"
done

# Create ovpn folder
mkdir -p ~/ovpn_files

# Install updog
echo "[*] Installing updog..."
sudo pipx install updog

# Create Tools folder
echo "[*] Setting up Exegol Tools..."
mkdir -p ~/Tools

# Get Tools script
wget -qO ~/Tools/update-resources.sh "https://raw.githubusercontent.com/ThePorgs/Exegol-resources/main/update-resources.sh"
chmod +x ~/Tools/update-resources.sh

# Install Tools
(cd ~/Tools/ && ./update-resources.sh)

# Install resizer based on virtual environment
# if [ "${VIRT_ENV}" = "qemu" ] || [ "${VIRT_ENV}" = "vmware" ]; then
#     echo "[*] Installing resizer scripts for VM..."
#     for size in medium high auto; do
#         wget -qO "${USER_DESKTOP}/${size}.sh" "${KALI_RESOURCES_PATH}${size}.sh"
#         chmod +x "${USER_DESKTOP}/${size}.sh"
#     done
# fi
echo "[*] Installing resizer scripts for VM..."
for size in medium high auto; do
    wget -qO "${USER_DESKTOP}/${size}.sh" "${KALI_RESOURCES_PATH}${size}.sh"
    chmod +x "${USER_DESKTOP}/${size}.sh"
done

# Install ligolo-ng
# echo "[*] Compiling ligolo-ng..."
# if [ ! -d /opt/ligolo-ng ]; then
#     sudo git clone https://github.com/nicocha30/ligolo-ng /opt/ligolo-ng
# fi
# (
#     cd /opt/ligolo-ng
#     sudo go build -o agent cmd/agent/main.go
#     sudo go build -o proxy cmd/proxy/main.go
# )

# Set dnsmasq
# echo "[*] Configuring dnsmasq..."
# NETWORK_MANAGER_FILE="/etc/NetworkManager/NetworkManager.conf"
# if grep -q "dns=" "${NETWORK_MANAGER_FILE}"; then
#     sudo sed -i '/dns=/c\dns=dnsmasq' "${NETWORK_MANAGER_FILE}"
# else
#     sudo sed -i '/\[main\]/a dns=dnsmasq' "${NETWORK_MANAGER_FILE}"
# fi

# Install xrdp
echo "[*] Installing xrdp..."
sudo apt-get install -y xrdp
sudo systemctl enable xrdp --now
echo "xfce4-session" | tee ~/.xsession

# Add xrdp polkit rules
echo "[*] Configuring xrdp polkit rules..."
sudo mkdir -p /etc/polkit-1/rules.d/
sudo tee /etc/polkit-1/rules.d/50-xrdp.rules > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
  polkit.log(action + ", " + subject);
  if (~["org.freedesktop.login1.power-off","org.freedesktop.login1.power-off-multiple-sessions","org.freedesktop.login1.reboot","org.freedesktop.login1.reboot-multiple-sessions"].indexOf(action.id)) {
    return polkit.Result.YES;
  }
});
EOF

echo "[*] Kali setup is complete!"
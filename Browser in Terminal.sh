# ================================
#  BROWSH FULL INSTALL SCRIPT
#  Ubuntu / Google Cloud Shell
# ================================

set -e

echo "Updating system..."
sudo apt update

echo "Installing required libraries..."
sudo apt install -y wget tar libgtk-3-0t64 libdbus-glib-1-2 libxt6t64 libx11-xcb1 libasound2t64

echo "Downloading latest Firefox..."
wget "https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US" -O firefox.tar.xz

echo "Extracting Firefox..."
tar -xJf firefox.tar.xz

echo "Moving Firefox to /opt..."
sudo mv firefox /opt/firefox

echo "Creating global symlink..."
sudo ln -sf /opt/firefox/firefox /usr/local/bin/firefox

echo "Downloading Browsh v1.8.0..."
wget https://github.com/browsh-org/browsh/releases/download/v1.8.0/browsh_1.8.0_linux_amd64

echo "Making Browsh executable..."
chmod +x browsh_1.8.0_linux_amd64

echo "Installing Browsh globally..."
sudo mv browsh_1.8.0_linux_amd64 /usr/local/bin/browsh

echo "Cleaning up..."
rm -f firefox.tar.xz

echo "================================"
echo " INSTALL COMPLETE "
echo "================================"
echo "Firefox version:"
firefox --version
echo ""
echo "To run Browsh, just type:"
echo "browsh"
echo ""
echo "If sandbox error appears, use:"
echo "browsh --firefox.args \"--no-sandbox\""

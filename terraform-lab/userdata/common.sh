#!/bin/bash
set -euxo pipefail

# --------------------------------------------------------------------
# Enable Amazon SSM Agent
# --------------------------------------------------------------------
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# --------------------------------------------------------------------
# Wait until outbound Internet is available
# --------------------------------------------------------------------
echo "Waiting for Internet connectivity..."

until curl -fsSL https://github.com >/dev/null 2>&1; do
    sleep 5
done

echo "Internet is available."

# --------------------------------------------------------------------
# Install common packages
# --------------------------------------------------------------------
dnf install -y \
    git \
    nano \
    jq \
    tree \
    tmux

# --------------------------------------------------------------------
# Install Starship (for root)
# --------------------------------------------------------------------
mkdir -p /root/.local/bin
mkdir -p /root/.config

curl -fsSL https://starship.rs/install.sh | \
    sh -s -- -b /root/.local/bin -y

grep -qxF 'export PATH="/root/.local/bin:$PATH"' /root/.bashrc \
    || echo 'export PATH="/root/.local/bin:$PATH"' >> /root/.bashrc

grep -qxF 'eval "$(/root/.local/bin/starship init bash)"' /root/.bashrc \
    || echo 'eval "$(/root/.local/bin/starship init bash)"' >> /root/.bashrc

cat >/root/.config/starship.toml <<'EOF'
add_newline = false

format = "$hostname$directory$character"

[hostname]
ssh_only = false
disabled = false
format = "🛰️ [$hostname](bold green) "

[directory]
truncation_length = 3
format = "[$path](cyan) "

[character]
success_symbol = "❯"
error_symbol = "[✗](red)"
EOF

# --------------------------------------------------------------------
# Install bat
# --------------------------------------------------------------------
VERSION=0.25.0

curl -LO https://github.com/sharkdp/bat/releases/download/v$${VERSION}/bat-v$${VERSION}-x86_64-unknown-linux-musl.tar.gz

tar -xzf bat-v$${VERSION}-x86_64-unknown-linux-musl.tar.gz

install \
    bat-v$${VERSION}-x86_64-unknown-linux-musl/bat \
    /usr/local/bin/

rm -rf bat-v$${VERSION}-x86_64-unknown-linux-musl*

# --------------------------------------------------------------------
# Marker file
# --------------------------------------------------------------------
echo "Provisioned successfully on $(date)" >/root/provisioned.txt


# --------------------------------------------------------------------
# Bootstrap
# --------------------------------------------------------------------



cat >/usr/local/bin/bootstrap.sh <<'EOF'
#!/bin/bash
set -euo pipefail

mkdir -p ~/.local/bin
mkdir -p ~/.config

if ! command -v starship >/dev/null 2>&1; then
    curl -fsSL https://starship.rs/install.sh | sh -s -- -b ~/.local/bin -y
fi

grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc \
    || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

grep -qxF 'eval "$(starship init bash)"' ~/.bashrc \
    || echo 'eval "$(starship init bash)"' >> ~/.bashrc

cat > ~/.config/starship.toml <<'STARSHIP'
add_newline = false

format = "$hostname$directory$character"

[hostname]
ssh_only = false
disabled = false
format = "🛰️ [$hostname](bold green) "

[directory]
truncation_length = 3
format = "[$path](cyan) "

[character]
success_symbol = "❯"
error_symbol = "[✗](red)"
STARSHIP

cat >> ~/.bashrc <<'BASHRC'

alias ll='ls -lah --color=auto'
alias cls='clear'
alias grep='grep --color=auto'
alias cat='bat --style=header --paging=never'

echo
echo "🛰️ Connected to $(hostname)"
echo
BASHRC

echo "Bootstrap complete. Reconnect your shell."
EOF

chmod +x /usr/local/bin/bootstrap.sh

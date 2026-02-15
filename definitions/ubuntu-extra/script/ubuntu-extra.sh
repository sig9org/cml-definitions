#!/bin/bash

# Install basic packages
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  axel \
  curl \
  eza \
  fping \
  git \
  gpg \
  neovim \
  nmap \
  peco \
  ripgrep \
  snmp \
  snmp-mibs-downloader \
  sudo \
  traceroute \
  tree \
  tshark \
  unzip \
  wget \
  zip \
  zsh

# Install Docker
curl -fsSL https://get.docker.com | /bin/sh

# Disable AppArmor
systemctl stop apparmor.service
systemctl disable apparmor.service

# Timezone & NTP
timedatectl set-timezone Asia/Tokyo
cat << EOF >> /etc/systemd/timesyncd.conf
NTP=162.159.200.123 162.159.200.1
EOF

# SSH
sed -i -e "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i -e "s/#ClientAliveInterval 0/ClientAliveInterval 60/g" /etc/ssh/sshd_config
sed -i -e "s/#ClientAliveCountMax 3/ClientAliveCountMax 5/g" /etc/ssh/sshd_config

cat << EOF > /etc/ssh/ssh_config.d/99_lab.conf
KexAlgorithms +diffie-hellman-group1-sha1
Ciphers aes128-cbc,aes256-ctr
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
EOF

# Enable "/var/log/messages"
cat << 'EOF' > /etc/rsyslog.d/50-default.conf
#  Default rules for rsyslog.
#
#   For more information see rsyslog.conf(5) and /etc/rsyslog.conf

#
# First some standard log files.  Log by facility.
#
auth,authpriv.*   /var/log/auth.log
*.*;auth,authpriv.none  -/var/log/syslog
#cron.*    /var/log/cron.log
#daemon.*   -/var/log/daemon.log
kern.*    -/var/log/kern.log
#lpr.*    -/var/log/lpr.log
mail.*    -/var/log/mail.log
#user.*    -/var/log/user.log

#
# Logging for the mail system.  Split it up so that
# it is easy to write scripts to parse these files.
#
#mail.info   -/var/log/mail.info
#mail.warn   -/var/log/mail.warn
mail.err   /var/log/mail.err

#
# Some "catch-all" log files.
#
#*.=debug;\
# auth,authpriv.none;\
# news.none;mail.none -/var/log/debug
*.=info;*.=notice;*.=warn;\
 auth,authpriv.none;\
 cron,daemon.none;\
 mail,news.none  -/var/log/messages

#
# Emergencies are sent to everybody logged in.
#
*.emerg    :omusrmsg:*

#
# I like to have messages displayed on the console, but only on a virtual
# console I usually leave idle.
#
#daemon,mail.*;\
# news.=crit;news.=err;news.=notice;\
# *.=debug;*.=info;\
# *.=notice;*.=warn /dev/tty8
EOF

cat << 'EOF' > /etc/logrotate.d/syslog
/var/log/messages
{
 rotate 4
 weekly
 missingok
 notifempty
 compress
 delaycompress
 sharedscripts
 postrotate
  /usr/lib/rsyslog/rsyslog-rotate
 endscript
}
EOF

# Install uncmnt
curl -L https://github.com/sig9org/uncmnt/releases/download/v0.0.2/uncmnt_v0.0.2_linux_amd64 -o /usr/local/bin/uncmnt && \
chmod 755 /usr/local/bin/uncmnt

# Install mise
apt update
install -dm 755 /etc/apt/keyrings
wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | tee /etc/apt/keyrings/mise-archive-keyring.gpg 1> /dev/null
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" | tee /etc/apt/sources.list.d/mise.list
apt update
apt install -y mise

# zsh & oh-my-zsh
chsh -s /bin/zsh
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
mv ~/.oh-my-zsh /opt/

# Initialization script
cat << 'EOF' >> /usr/local/bin/init-img.sh
#!/bin/bash

mv /opt/.oh-my-zsh ~/

# Disable login messages
echo 'exit' > ~/.hushlogin

cat << 'EOL' > ~/.zshrc
# Environment variables
export EDITOR=nvim
export ZSH="$HOME/.oh-my-zsh"

# Prompt
PROMPT='%F{%(!.210.green)}%n@%m %~ %# %f'

# Plugins
plugins=(
  aliases
  brew
  composer
  copypath
  docker
  git
  github
  history
  laravel
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting
)
source $ZSH/oh-my-zsh.sh

# History
setopt hist_ignore_dups

# mise
eval "$(mise activate zsh)"

# peco
function peco-select-history() {
  BUFFER=$(\history -n -r 1 | peco --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle reset-prompt
}
zle -N peco-select-history
bindkey '^r' peco-select-history

function peco-cdr () {
    local selected_dir=$(cdr -l | awk '{ print $2 }' | peco)
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N peco-cdr
bindkey '^@' peco-cdr

# uv
eval "$(uv generate-shell-completion zsh)"

# Alias
alias la="eza -aF --color=always"
alias ll="eza -alF --color=always"
alias t="task"
alias tfp="terraform plan"
alias tfa="terraform apply -auto-approve"
alias tft="terraform apply -auto-approve -var=\"tag=true\""
alias tfd="terraform destroy -auto-approve"
alias vi="nvim"
alias vim="nvim"
EOL

# Install tools using mise
mise install python@latest
mise use -g python@latest

mise install task@latest
mise use -g task@latest

mise install terraform@latest
mise use -g terraform@latest

mise install ruff@latest
mise use -g ruff@latest

mise install uv@latest
mise use -g uv@latest

mise install xh@latest
mise use -g xh@latest

rm -rf /usr/local/bin/init-img.sh
EOF

# Clean up
apt clean all
apt -y autoremove
history -c

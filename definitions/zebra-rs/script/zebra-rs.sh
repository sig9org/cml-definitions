#!/bin/bash

ZEBRA_USER=zebra-rs
ZEBRA_VERSION=$1
ARCH=$2
CODENAME=$3

# Install zebra-rs
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://zebra.rs/apt/zebra-rs-archive-keyring.asc | sudo tee /etc/apt/keyrings/zebra-rs.asc >/dev/null
printf 'Types: deb\nURIs: %s\nSuites: ./\nSigned-By: %s\n' \
  "https://github.com/zebra-rs/zebra-rs.github.io/releases/download/apt-${CODENAME}" "/etc/apt/keyrings/zebra-rs.asc" \
  | sudo tee /etc/apt/sources.list.d/zebra-rs.sources >/dev/null
rm -f /etc/apt/sources.list.d/zebra-rs.list
apt-get update
apt-get upgrade -y
apt-get install -y --allow-downgrades \
  fping \
  gping \
  nmap \
  traceroute \
  tshark \
  xh \
  zebra-rs=${ZEBRA_VERSION}
systemctl enable --now zebra-rs.service

useradd -m -g zebra-rs -G sudo -s /usr/bin/bash ${ZEBRA_USER}
echo "${ZEBRA_USER}:${ZEBRA_USER}" | chpasswd
echo 'exec /usr/bin/vty' | tee -a /home/${ZEBRA_USER}/.profile
echo 'exit' > /home/${ZEBRA_USER}/.hushlogin
chown -R ${ZEBRA_USER}:zebra-rs:/home/${ZEBRA_USER}/

# Copy zebra-rs.conf
cat << 'EOF' > /usr/local/bin/copy-zebra-config.sh
#!/bin/bash
set -e

FLAG_FILE="/var/lib/zebra-rs-config-done"

if [ -f "$FLAG_FILE" ]; then
    echo "Zebra-rs config has already been provisioned. Skipping."
    exit 0
fi

mkdir -p /etc/zebra-rs

MNT_DIR="/mnt/cidata_temp"
mkdir -p "$MNT_DIR"

mount -o ro /dev/sr0 "$MNT_DIR" || mount -o ro /dev/vdb "$MNT_DIR" || mount -o ro /dev/disk/by-label/cidata "$MNT_DIR" || true

if [ -f "$MNT_DIR/zebra-rs" ]; then
    cp "$MNT_DIR/zebra-rs" /etc/zebra-rs/zebra-rs.conf
    chmod 644 /etc/zebra-rs/zebra-rs.conf
    chown root:root /etc/zebra-rs/zebra-rs.conf
    systemctl restart zebra-rs.service

    touch "$FLAG_FILE"
    echo "Zebra-rs config provisioned successfully."
fi

umount "$MNT_DIR" || true
rmdir "$MNT_DIR" || true
EOF

chmod 755 /usr/local/bin/copy-zebra-config.sh

cat << 'EOF' > /etc/systemd/system/copy-zebra-config.service
[Unit]
Description=Copy zebra-rs configuration from CML CONFIG tab (Once on first boot)
After=cloud-init.service
ConditionPathExists=!/var/lib/zebra-rs-config-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/copy-zebra-config.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable copy-zebra-config.service

# Disable AppArmor
systemctl stop apparmor.service
systemctl disable apparmor.service

# Timezone & NTP
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

# Clean up
apt clean all
apt -y autoremove
history -c

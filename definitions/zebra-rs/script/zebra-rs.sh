#!/bin/bash

ZEBRA_VERSION=$1

# Install zebra-rs
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://zebra.rs/apt/zebra-rs-archive-keyring.asc | sudo tee /etc/apt/keyrings/zebra-rs.asc >/dev/null
printf 'Types: deb\nURIs: %s\nSuites: ./\nSigned-By: %s\n' \
  "https://github.com/zebra-rs/zebra-rs.github.io/releases/download/apt-resolute" "/etc/apt/keyrings/zebra-rs.asc" \
  | sudo tee /etc/apt/sources.list.d/zebra-rs.sources >/dev/null
rm -f /etc/apt/sources.list.d/zebra-rs.list
apt-get update
apt-get upgrade -y
apt-get install -y --allow-downgrades zebra-rs=${ZEBRA_VERSION}
systemctl enable --now zebra-rs.service

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

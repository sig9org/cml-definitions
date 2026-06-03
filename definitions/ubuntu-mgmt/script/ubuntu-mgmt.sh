#!/bin/bash

# Disable apparmor and ufw
systemctl disable --now apparmor.service
ufw disable

# Basic settings
add-apt-repository -y multiverse
apt update
apt -y upgrade
DEBIAN_FRONTEND=noninteractive apt install -y \
  fping \
  nmap \
  snmp \
  traceroute \
  tree \
  tshark \
  xh
timedatectl set-timezone Asia/Tokyo

# SSH
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

# uncmnt
curl -L https://github.com/sig9org/uncmnt/releases/download/v0.0.2/uncmnt_v0.0.2_linux_amd64 -o /usr/local/bin/uncmnt
chmod 755 /usr/local/bin/uncmnt

# nginx (HTTP/HTTPS)
apt install -y nginx
systemctl enable --now nginx.service
mkdir -p /etc/ssl/nginx
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /etc/ssl/nginx/nginx-selfsigned.key \
  -out /etc/ssl/nginx/nginx-selfsigned.crt \
  -subj "/C=JP/ST=Tokyo/L=Chiyoda/O=MyCompany/OU=Dev/CN=localhost"
chmod 600 /etc/ssl/nginx/nginx-selfsigned.key
cat << EOF > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    server_name _;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    server_name _;

    ssl_certificate /etc/ssl/nginx/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/nginx/nginx-selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
}
EOF
systemctl restart nginx.service

rm /var/www/html/index.nginx-debian.html
cat << EOF > /var/www/html/index.html
Hello, World!
EOF
truncate -s 10M /var/www/html/sample.bin
chown -R www-data:www-data /var/www/html

# chrony (NTP)
cat << EOF > /etc/chrony/chrony.conf
allow 0.0.0.0/0
confdir /etc/chrony/conf.d
driftfile /var/lib/chrony/chrony.drift
keyfile /etc/chrony/chrony.keys
leapseclist /usr/share/zoneinfo/leap-seconds.list
local stratum 10
logdir /var/log/chrony
makestep 1 3
maxupdateskew 100.0
ntsdumpdir /var/lib/chrony
rtcsync
server time3.google.com iburst
server time4.google.com iburst prefer
#sourcedir /etc/chrony/sources.d
sourcedir /run/chrony-dhcp
EOF
systemctl restart chronyd.service

# dnsmasq (DNS/DHCP/TFTP)
systemctl disable --now systemd-resolved.service
rm /etc/resolv.conf
cat << EOF > /etc/resolv.conf
nameserver 127.0.0.1
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

apt install -y dnsmasq
cat << EOF > /etc/dnsmasq.conf
bogus-priv
domain-needed
domain=example.net
enable-tftp
expand-hosts
local=/example.net/
log-facility=/var/log/dnsmasq.log
log-queries
resolv-file=/etc/dnsmasq_resolv.conf
tftp-root=/var/tftp
tftp-secure
EOF

cat << EOF > /etc/dnsmasq_resolv.conf
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF
systemctl restart dnsmasq.service

mkdir -p /var/tftp
truncate -s 10M /var/tftp/sample.bin
chown -R dnsmasq:nogroup /var/tftp

# rsyslog (Syslog)
mkdir -p /var/log/rsyslog
chown syslog:adm /var/log/rsyslog
chmod 755 /var/log/rsyslog
cat << 'EOF' > /etc/rsyslog.d/99-remote.conf
module(load="imudp")
input(type="imudp" port="514")

if $fromhost-ip == '127.0.0.1' or $fromhost-ip == 'localhost' then {
    stop
}

$template ClinetMessage,"/var/log/rsyslog/%hostname%.log"
*.*     -?ClinetMessage
EOF
systemctl restart rsyslog.service

# snmptrapd (SNMP Trap)
touch /var/log/snmptrapd.log
chown Debian-snmp:Debian-snmp /var/log/snmptrapd.log
apt install -y snmp-mibs-downloader snmpd snmptrapd
cat << EOF > /etc/snmp/snmptrapd.conf
localport 162
authCommunity log,execute,net public
EOF

mkdir -p /etc/systemd/system/snmptrapd.service.d
cat << EOF > /etc/systemd/system/snmptrapd.service.d/local.conf
[Service]
ExecStart=
ExecStart=/usr/sbin/snmptrapd -Lf /var/log/snmptrapd.log -f
EOF

systemctl daemon-reload
systemctl restart snmptrapd.service

# FreeRadius (Radius)
apt install -y freeradius freeradius-utils

cat << 'EOF' > /etc/freeradius/3.0/radiusd.conf
prefix = /usr
exec_prefix = /usr
sysconfdir = /etc
localstatedir = /var
sbindir = ${exec_prefix}/sbin
logdir = /var/log/freeradius
raddbdir = /etc/freeradius/3.0
radacctdir = ${logdir}/radacct
name = freeradius
confdir = ${raddbdir}
modconfdir = ${confdir}/mods-config
certdir = ${confdir}/certs
cadir   = ${confdir}/certs
run_dir = ${localstatedir}/run/${name}
db_dir = ${raddbdir}
libdir = /usr/lib/freeradius
pidfile = ${run_dir}/${name}.pid
max_request_time = 30
cleanup_delay = 5
max_requests = 16384
hostname_lookups = no
unlang {
}
log {
        destination = files
        colourise = yes
        file = ${logdir}/radius.log
        syslog_facility = daemon
        stripped_names = no
        auth = yes
        auth_badpass = yes
        auth_goodpass = yes
        msg_goodpass = "from %{Packet-Src-IP-Address}"
        msg_badpass  = "from %{Packet-Src-IP-Address}"
        msg_denied = "You are already logged in - access denied"
}
checkrad = ${sbindir}/checkrad
ENV {
}
security {
        user = freerad
        group = freerad
        allow_core_dumps = no
        max_attributes = 200
        reject_delay = 1
        status_server = yes
        require_message_authenticator = auto
        limit_proxy_state = auto
}
proxy_requests  = yes
$INCLUDE proxy.conf
$INCLUDE clients.conf
thread pool {
        start_servers = 5
        max_servers = 32
        min_spare_servers = 3
        max_spare_servers = 10
        max_requests_per_server = 0
        auto_limit_acct = no
}
modules {
        $INCLUDE mods-enabled/
}
instantiate {
}
policy {
        $INCLUDE policy.d/
}
$INCLUDE sites-enabled/
EOF

cat << EOF > /etc/freeradius/3.0/clients.conf
client Private-A {
  ipaddr = 10.0.0.0/8
  proto = *
  secret = SECRET-KEY
  require_message_authenticator = yes
  nas_type   = other
  limit_proxy_state = yes
  limit {
    max_connections = 16
    lifetime = 0
    idle_timeout = 30
  }
}

client Private-B {
  ipaddr = 172.16.0.0/12
  proto = *
  secret = SECRET-KEY
  require_message_authenticator = yes
  nas_type   = other
  limit_proxy_state = yes
  limit {
    max_connections = 16
    lifetime = 0
    idle_timeout = 30
  }
}

client Private-C {
  ipaddr = 192.168.0.0/16
  proto = *
  secret = SECRET-KEY
  require_message_authenticator = yes
  nas_type   = other
  limit_proxy_state = yes
  limit {
    max_connections = 16
    lifetime = 0
    idle_timeout = 30
  }
}
EOF

cat << EOF > /etc/freeradius/3.0/users
USER1 Cleartext-Password := "PASSWORD1"
USER2 Cleartext-Password := "PASSWORD2"
USER3 Cleartext-Password := "PASSWORD3"
EOF

systemctl restart freeradius && systemctl status freeradius

# GoFlow2 (IPFIX/NetFlow/sFlow)
curl -LO https://github.com/netsampler/goflow2/releases/download/v2.2.6/goflow2_2.2.6_amd64.deb
apt install -y ./goflow2_2.2.6_amd64.deb
rm -f goflow2_2.2.6_amd64.deb
mkdir -p /usr/share/goflow2
cat << EOF > /etc/default/goflow2
GOFLOW2_ARGS="-listen sflow://:6343,netflow://:9995 -transport.file /var/log/goflow2.log"
EOF
systemctl restart --now goflow2.service

# Clean up
apt clean all
apt -y autoremove
history -c

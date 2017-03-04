#!/bin/bash
# Based on Adafruit Learning Technologies Onion Pi project
# see: http://learn.adafruit.com/onion-pi

app_name="Onion Pi"
moniker="4d4m0u"

station=wlan1
AP=wlan0

root_check() {
  if (( $EUID != 0 )); then
    echo "This must be run as root. Type in 'sudo bash $0' to run it as root."
    exit 1
  fi
}

init() {
  echo "$(tput setaf 2)
                     ..
                    ,:
            .      ::
            .:    :2.
             .:,  1L
              .v: Z, ..::,
               :k:N.Lv:
                22ukL
                JSYk.$(tput bold ; tput setaf 7)
               ,B@B@i
               BO@@B@.
             :B@L@Bv:@7
           .PB@iBB@  .@Mi
         .P@B@iE@@r  . 7B@i
        5@@B@:NB@1$(tput setaf 5) r  ri:$(tput bold ; tput setaf 7)7@M
      .@B@BG.OB@B$(tput setaf 5)  ,.. .i, $(tput bold ; tput setaf 7)MB,
      @B@BO.B@@B$(tput setaf 5)  i7777,    $(tput bold ; tput setaf 7)MB.
     PB@B@.OB@BE$(tput setaf 5)  LririL,.L. $(tput bold ; tput setaf 7)@P
     B@B@5iB@B@i$(tput setaf 5)  :77r7L, L7 $(tput bold ; tput setaf 7)O@
     @B1B27@B@B,$(tput setaf 5) . .:ii.  r7 $(tput bold ; tput setaf 7)BB
     O@.@M:B@B@:$(tput setaf 5) v7:    ::.  $(tput bold ; tput setaf 7)BM
     :Br7@L5B@BO$(tput setaf 5) irL: :v7L. $(tput bold ; tput setaf 7)P@,
      7@,Y@UqB@B7$(tput setaf 5) ir ,L;r: $(tput bold ; tput setaf 7)u@7
       r@LiBMBB@Bu$(tput setaf 5)   rr:.$(tput bold ; tput setaf 7):B@i
         FNL1NB@@@@:   ;OBX
           rLu2ZB@B@@XqG7$(tput sgr0 ; tput setaf 2)
              . rJuv::

              $(tput setaf 2)$app_name
  	  $(tput bold ; tput setaf 5)by adafruit$(tput sgr0)
         $(tput bold ; tput setaf 5)modified by $moniker$(tput sgr0)
  "

  echo "$(tput setaf 6)This script will configure your Raspberry Pi as an Onion Pi Tor proxy.$(tput sgr0)"
  read -p "$(tput bold ; tput setaf 2)Press [Enter] to begin, [Ctrl-C] to abort...$(tput sgr0)"
}

update_pkgs() {
  echo "$(tput setaf 6)Updating packages...$(tput sgr0)"
  apt-get update -q -y
}

install_tor() {
  echo "$(tput setaf 6)Installing Tor...$(tput sgr0)"
  apt-get install tor -y
}

configure_tor() {
  echo "$(tput setaf 6)Configuring Tor...$(tput sgr0)"
  x=/etc/tor/torrc
  cp $x $x.bak
  cat > $x << EOL
  Log notice file /var/log/tor/notices.log
  VirtualAddrNetwork 10.192.0.0/10
  AutomapHostsSuffixes .onion,.exit
  AutomapHostsOnResolve 1
  TransPort 9040
  TransListenAddress 192.168.42.1
  DNSPort 53
  DNSListenAddress 192.168.42.1
  EOL
}

install_mac_changer() {
  echo "$(tput setaf 6)Installing Mac Changer...$(tput sgr0)"
  apt-get install macchanger -y
}

configure_routes() {
  echo "$(tput setaf 6)Flushing old IP tables...$(tput sgr0)"
  iptables -F
  iptables -t nat -F

  echo "$(tput setaf 6)Establishing $(tput bold)ssh$(tput sgr0 ; tput setaf 6) exception on port 22...$(tput sgr0)"
  iptables -t nat -A PREROUTING -i $AP -p tcp --dport 22 -j REDIRECT --to-ports 22

  echo "$(tput setaf 6)Rerouting DNS traffic...$(tput sgr0)"
  iptables -t nat -A PREROUTING -i $AP -p udp --dport 53 -j REDIRECT --to-ports 53

  echo "$(tput setaf 6)Rerouting TCP traffic...$(tput sgr0)"
  iptables -t nat -A PREROUTING -i $AP -p tcp --syn -j REDIRECT --to-ports 9040

  echo "$(tput setaf 6)Saving IP tables...$(tput sgr0)"
  sh -c "iptables-save > /etc/iptables.ipv4.nat"
}

configure_logging() {
  echo "$(tput setaf 6)Setting up logging in /var/log/tor/notices.log...$(tput sgr0)"
  x=/var/log/tor/notices.log
  touch $x
  chown debian-tor $x
  chmod 644 $x
}

start() {
  echo "$(tput setaf 6)Starting Tor...$(tput sgr0)"
  service tor start
}

enable_on_boot() {
  echo "$(tput setaf 6)Setting Tor to start at boot...$(tput sgr0)"
  update-rc.d tor enable
}

wrong_key() {
	echo -e "$(tput setaf 6)\n-----------------------------$(tput sgr0)"
	echo -e "$(tput setaf 6)\nError: Wrong value.\n$(tput sgr0)"
	echo -e "$(tput setaf 6)-----------------------------\n$(tput sgr0)"
	echo -e "$(tput setaf 6)Enter any key to continue$(tput sgr0)"
	read -r key
}

finish() {
  echo "$(tput setaf 6)Setup complete!

  $(tput bold)Verify by visiting: $(tput setaf 3)https://check.torproject.org/$(tput sgr0)
  "
	default=Y
	read -r -p "$(tput setaf 6)Do you want to reboot now to apply changes [Y/n] [Default=Y] [Quit=Q/q]?$(tput sgr0) " input
	input=${input:-$default}
	case $input in
		Y|y)
			echo "$(tput setaf 6)Rebooting to apply changes...$(tput sgr0)"
			closing
			reboot
			exit 0
		;;
		N|n)
			echo "$(tput setaf 6)Remember to reboot later to apply changes.$(tput sgr0)"
		;;
		Q|q)s
		;;
		*)
			wrong_key
			finish
		;;
	esac
}

begin() {
  root_check
  init
  update_pkgs
  install_tor
  configure_tor
  install_mac_changer
  configure_routes
  configure_logging
  start
  enable_on_boot
  finish
  exit 0
}

begin

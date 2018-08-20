#!/bin/bash

# Based on Adafruit Learning Technologies Onion Pi project
# see: http://learn.adafruit.com/onion-pi

declare BASH_UTILS_URL="https://raw.githubusercontent.com/nicholasadamou/Dotfile-Utilities/master/utils.sh"

declare skipQuestions=false

trap "exit 1" TERM
export TOP_PID=$$

declare APP_NAME="Onion Pi"
declare MONIKER="4d4m0u"

declare AP=wlan0

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setup_onion_pi() {
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

              $(tput setaf 2)$APP_NAME
      $(tput bold ; tput setaf 5)by adafruit$(tput sgr0)
         $(tput bold ; tput setaf 5)modified by $MONIKER$(tput sgr0)
  "

  echo "$(tput setaf 6)This script will configure your Raspberry Pi as an Onion Pi Tor proxy.$(tput sgr0)"
  
  if [ "$TRAVIS" != "true" ]; then
      read -r -p "$(tput bold ; tput setaf 2)Press [Enter] to begin, [Ctrl-C] to abort...$(tput sgr0)"
  fi

  update
  upgrade

  declare -a PKGS=(
      "tor"
      "macchanger"
      "iptables-persistent"
  )

  for PKG in "${PKGS[@]}"; do
      install_package "$PKG" "$PKG"
  done

  FILE=/etc/tor/torrc
  sudo cp "$FILE" "$FILE".bak
  cat > "$FILE" <<- EOL
  Log notice file /var/log/tor/notices.log
  VirtualAddrNetwork 10.192.0.0/10
  AutomapHostsSuffixes .onion,.exit
  AutomapHostsOnResolve 1
  TransPort 9040
  TransListenAddress 192.168.42.1
  DNSPort 53
  DNSListenAddress 192.168.42.1
EOL

  sudo iptables -F
  sudo iptables -t nat -F

  sudo iptables -t nat -A PREROUTING -i "$AP" -p tcp --dport 22 -j REDIRECT --to-ports 22
  sudo iptables -t nat -A PREROUTING -i "$AP" -p udp --dport 53 -j REDIRECT --to-ports 53
  sudo iptables -t nat -A PREROUTING -i "$AP" -p tcp --syn -j REDIRECT --to-ports 9040

  sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
  sudo systemctl enable netfilter-persistent

  FILE=/var/log/tor/notices.log
  sudo touch "$FILE"
  sudo chown debian-tor "$FILE"
  sudo chmod 644 "$FILE"

  sudo service tor start
  sudo update-rc.d tor enable
}

restart() {
    ask_for_confirmation "Do you want to restart?"
    
    if answer_is_yes; then
        sudo shutdown -r now &> /dev/null
    fi
}

main() {
    # Ensure that the following actions
    # are made relative to this file's path.

    cd "$(dirname "${BASH_SOURCE[0]}")" \
        && source <(curl -s "$BASH_UTILS_URL") \
        || exit 1

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    skip_questions "$@" \
        && skipQuestions=true

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    ask_for_sudo

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    setup_onion_pi

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    
    if ! $skipQuestions; then
        restart
    fi
}

main "$@"

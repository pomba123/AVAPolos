#!/bin/bash

#-------------------------------------------#
# AVAPolos - Script de configuração de rede #
#-------------------------------------------#

#This script needs to run as root.
if [ "$EUID" -ne 0 ]; then
  echo "Este script precisa ser rodado como root" | log error
  exit
fi

#If the header file is present on the system.
if [ -f "/etc/avapolos/header.sh" ]; then
  #Source it.
  source /etc/avapolos/header.sh
#If it's not present.
else
  #Tell the user and exit with an error code.
  echo "Não foi encontrado o arquivo header.sh" | log error
  exit 1
fi

#----------------------------------------------------------

enableDnsmasq="false"
echo "install_networking.sh" | log debug
echo "Configurando rede." | log info

#----------------------------------------------------------

rm -rf $NETWORKING_PATH/enable

#Funcions used to get the default network configuration.
getInterface() {

  blacklist="lo docker br veth tun"
  priority=("en" "wl")
  for if in $(ifconfig | grep ^[a-zA-Z] | cut -d":" -f1); do
    ifs+=("$if")
  done
  for item in $blacklist; do
    ifs=("${ifs[@]/*$item*}")
  done

  new_ifs=()
  for item in ${ifs[@]}; do
    if ! [ -z "$item" ]; then
      new_ifs+=("$item")
    fi
  done
  ifs=(${new_ifs[@]})
  unset new_ifs

  if [ ${#ifs[@]} -eq 1 ]; then
    interface=${ifs[0]}
  elif [ $INTERACTIVE="false" ]; then
    flag="false"
    while [ "$flag" = "false" ]; do
      for if in $ifs; do
        for counter in $(seq 0 $((${#priority[@]} - 1 ))); do
          if [[ "$if" =~ ${priority[counter]} ]]; then
            interface=$if
            flag="true"
          fi
        done
      done
    done
  # else
  #   log warn "A interface principal não foi detectada automaticamente"
  #   option=$(input "Deseja selecionar uma manualmente?" "sim" "nao" 1 "Selecione uma opção.")
  #   if [ "$option" = "nao" ]; then
  #     log error "Cancelando instalação."
  #     exit 1
  #   fi
  #
  #   log debug "Interfaces detectadas:"
  #   for counter in ${!ifs[@]}; do
  #     log debug "$counter. ${ifs[counter]}"
  #   done
  #   flag=false
  #   while [ "$flag" = "false" ]; do
  #     echo "Selecione uma interface: (0-$c)"
  #     read option
  #     for counter in ${!ifs[@]}; do
  #       if [ "$option" = "$counter" ]; then
  #         flag="true"
  #       fi
  #     done
  #   done
  #   interface=${ifs[option]}
  fi

  echo $interface > $INSTALL_SCRIPTS_PATH/interface
  echo $interface
}
getIP() { #$1-> interface
  if ! [ -z "$1" ]; then
    ip=$(ip -o -f inet addr show | grep "$1" | awk '/scope global/ {print $4}')

    if ! [ -z $ip ]; then
      echo $ip
    fi
  fi
}
getGateway() { #$1-> interface
  if ! [ -z "$1" ]; then
    gw=$(ip route | grep "default" | grep "$1" | awk '{print $3}')
    echo $gw
  fi
}
getNameservers(){ #$1-> interface

  cmdRet=$(systemd-resolve --status)
  hasDns=$(echo $cmdRet | grep -o "DNS Servers: ")

  if ! [ -z "$hasDns" ]; then
    ifstart=$(echo "$cmdRet" | grep "(""$1"")" -m 1 -n | cut -d":" -f1)
    lineEnd=$(echo "$cmdRet" | wc -l)
    ifFromEnd=$(( $lineEnd - $ifstart ))
    #try to find DNS Domain
    endLink=$(echo "$cmdRet" | tail -n $ifFromEnd | grep 'Link' -m 1 -n | cut -d":" -f1)
    if [ -z "$endLink" ]; then
       #try to find next link
       endLink=$(echo "$cmdRet" | tail -n $ifFromEnd | grep 'DNS Domain' -m 1 -n | cut -d":" -f1)
       if [ -z "$endLink" ]; then
          endLink=$lineEnd
       fi
    fi
    if [ ! $endLink -eq $lineEnd ]; then
       endLink=$(( $endLink - 1))
    fi

    cmdFromIf=$(echo "$cmdRet" | tail -n $ifFromEnd | head -n $endLink)
    dnsArr=$(echo "$cmdFromIf" | rev | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}\ ' | rev)
    newDnsArr=()
    for dns in $dnsArr; do
      newDnsArr+=("$dns")
    done
    dnsArr=(${newDnsArr[@]})
    unset newDnsArr

    echo ${dnsArr[@]}

  fi

}
getNetwork () { #$1-> ip
  if ! [ -z "$1" ]; then
    network="$(echo $1 | grep -Eo '([0-9]{1,3}\.){3}')0"
    echo $network
  fi
}
getNetmask() { #$1-> interface
  if ! [ -z "$1" ]; then
    netmask=$(ifconfig $1 | grep netmask | awk '{print $4}')
    echo $netmask
  fi
}

#This function disables Network-Manager, Netplan and systemd-resolved.
disableDefaultNetworkServices() {
  if [ -f "/etc/init.d/network-manager" ]; then
    echo "Desabilitando serviço padrão de gerenciamento de redes." | log debug
    sudo systemctl disable NetworkManager | log debug
    sudo systemctl stop NetworkManager | log debug
    sudo systemctl mask NetworkManager | log debug
  fi
  if ! [ -z "$(command -v netplan)" ]; then
    echo "Desinstalando netplan" | log debug
    sudo apt-get remove netplan.io -y | log debug
  fi
  echo "Parando serviço padrão de nomes" | log debug
  sudo systemctl stop systemd-resolved | log debug
  sudo systemctl disable systemd-resolved | log debug
  sudo systemctl mask systemd-resolved | log debug
}

#These functions generate the required configurations.
generateHostsConfig() { # $1-> ip(without mask)
  if [ -z "$1" ]; then
    echo "Nenhum ip foi passado para o generateHostsConfig" | log error
    exit 1
  fi
  echo "Gerando arquivo /etc/hosts" | log debug
  echo -e "#AVAPolos config start"
  echo -e "$1 avapolos"
  echo -e "$1 controle.avapolos"
  echo -e "$1 inicio.avapolos"
  echo -e "$1 moodle.avapolos"
  echo -e "$1 wiki.avapolos"
  echo -e "$1 educapes.avapolos"
  echo -e "$1 traefik.avapolos"
  echo -e "$1 menu.avapolos"
  echo -e "$1 downloads.avapolos"
  echo -e "$1 portainer.avapolos"
  echo -e "#AVAPolos config end"
}
generateNetworkConfig() { # $1-> interface $2-> ip/mask $3-> gateway $4-> network $5-> netmask $6-> dns1 $7-> dns2
  if [ -z "$1" ]; then
    echo "Nenhum ip foi passado para o generateNetworkConfig" | log error
    exit 1
  fi
  echo -e "#AVAPolos config start"
  echo -e "auto $1"
  echo -e "iface $1 inet static"
  echo -e "address $2"
  if ! [ -f "$INSTALL_SCRIPTS_PATH/polo" ]; then
    echo -e "gateway $3"
  fi
  echo -e "network $4"
  echo -e "netmask $5"
  echo -e "dns-nameservers $6 $7"
  echo -e "#AVAPolos config end"
}
generateResolvConfig() { #$1 DNS
  if [ -z "$1" ]; then
    echo "Nenhum ip foi passado para o generateResolvConfig" | log error
    exit 1
  fi
  for arg in $@; do
    echo -e "nameserver $arg"
  done
}

#Main function
main() {

  echo "getInterface" | log debug
  INTERFACE=$(getInterface)
  echo "interface selecionada: $INTERFACE" | log debug

  echo "getIP" | log debug
  IP=$(getIP $INTERFACE)
  echo "IP detectado: $IP" | log debug

  if [ -z "$IP" ]; then

    enableDnsmasq="true"
    IP="10.254.0.1/16"
    NS1="10.254.0.1"
    NS2=""
    GATEWAY="10.254.0.1"
    NETWORK="10.254.0.0"
    NETMASK="255.255.0.0"

    echo "+-----------------------------------------------------" | log info
    echo "|Nenhum ip detectado, utilizando configurações padrão." | log info
    echo "|" | log info
    echo "|Os seguintes parâmetros serão configurados:" | log info
    echo "|Interface:$interface" | log info
    echo "|IP do Host: 10.254.0.1/16" | log info
    echo "|Servidor DNS: 10.254.0.1" | log info
    echo "|Gateway da rede: 10.254.0.1" | log info
    echo "+-----------------------------------------------------" | log info
    echo "|Subrede estática: 10.254.0.0" | log info
    echo "|Subrede DHCP: 10.254.1.0" | log info
    echo "+-----------------------------------------------------" | log info

  else

    echo "getGateway" | log debug
    GATEWAY=$(getGateway $INTERFACE)
    echo "Gateway detectado: $GATEWAY" | log debug

    echo "getNameservers" | log debug
    DNS=($(getNameservers $INTERFACE))
    echo "Servidores DNS detectados: "${DNS[@]} | log debug

    echo "getNetwork" | log debug
    NETWORK=$(getNetwork $IP)
    echo "Rede detectada: $NETWORK" | log debug

    echo "getNetmask" | log debug
    NETMASK=$(getNetmask $INTERFACE)
    echo "Máscara de rede detectada: $NETMASK" | log debug

    if [ -z "$DNS" ]; then
      NS1="1.1.1.1"
      NS2="8.8.8.8"
      echo "Nenhum servidor DNS detectado, configurando automaticamente." | log warn
    else
      counter=0
      for ns in ${DNS[@]}; do
        counter=$(($counter + 1))
        eval "NS$counter=$ns";
      done
    fi
  fi

  if [ "$enableDnsmasq" = "true" ]; then
    echo "dnsmasq será iniciado." | log debug
    touch $NETWORKING_PATH/enable
  else
    echo "--------------------------------------------" | log info
    echo "Os seguintes parâmetros serão configurados:" | log info
    echo "Interface:$INTERFACE" | log info
    echo "IP do Host: $IP" | log info
    echo "Gateway da rede: $GATEWAY" | log info
    echo "DNS1: $NS1" | log info
    echo "DNS2: $NS2" | log info
    echo "--------------------------------------------" | log info
  fi

  disableDefaultNetworkServices

  echo "Configurando arquivo /etc/network/interfaces" | log debug
  # $1-> interface $2-> ip/mask $3-> gateway $4-> network $5-> netmask $6-> dns1 $7-> dns2
  generateNetworkConfig "$INTERFACE" "$IP" "$GATEWAY" "$NETWORK" "$NETMASK" "$NS1" "$NS2" >> /etc/network/interfaces
  ifconfig "$INTERFACE" down | log debug
  ip addr flush dev "$INTERFACE" | log debug
  service networking restart | log debug

  echo "Aplicando configurações no arquivo /etc/hosts" | log debug
  generateHostsConfig $(echo "$IP" | cut -d "/" -f1) >> /etc/hosts

  echo "Aplicando configurações no resolv.conf"
  rm -rf /etc/resolv.conf
  generateResolvConfig ${DNS[@]} > /etc/resolv.conf
  chmod 777 /etc/resolv.conf

  cd $NETWORKING_PATH
  if [ -f enable ]; then
    echo "Inicializando dnsmasq, pode ser acessado pela porta 5380. (admin/admin)" | log debug
    docker-compose up -d | log debug
  fi

  cd $ROOT_PATH
  echo "router.yml" >> $SERVICES_PATH/enabled_services
  echo "hub_name.yml" >> $SERVICES_PATH/enabled_services

}

#----------------------------------------------------------

main

#!/usr/bin/env bash

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

echo "install_images.sh" | log debug
echo "Instalando imagens dos microsserviços." | log info

echo "Buscando imagens Docker no diretório: $IMAGES_PATH" | log debug

cd $IMAGES_PATH

imageList=$(ls *.tar)
for image in $imageList; do
  docker load -i $image 2>&1 | log debug
done

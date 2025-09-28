#!/bin/bash

# Script para construir la imagen del contenedor ARK ASA
set -e

IMAGE_NAME="ark-ascended-server-alex"
TAG="latest"

docker build -t ${IMAGE_NAME}:${TAG} -f Containerfile .

echo "Imagen construida: ${IMAGE_NAME}:${TAG}"

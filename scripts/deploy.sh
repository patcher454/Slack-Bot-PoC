#!/bin/bash
set -euo pipefail

IMAGE_TAG=${1:?Image tag is required}
IMAGE_NAME=${2:?Image name is required}
CONTAINER_NAME=${CONTAINER_NAME:-slack-bot-poc-dev}

echo "--- GitHub Container Registry 로그인 ---"
echo "${GITHUB_TOKEN}" | docker login ghcr.io -u "${GITHUB_ACTOR}" --password-stdin

echo "--- 새 Docker 이미지 pull: ${IMAGE_NAME}:${IMAGE_TAG} ---"
docker pull "${IMAGE_NAME}:${IMAGE_TAG}"

echo "--- 기존 컨테이너 중지 및 제거 (존재 시) ---"
docker stop "${CONTAINER_NAME}" || true
docker rm "${CONTAINER_NAME}" || true

echo "--- 새 컨테이너 시작 ---"
docker run -d --name "${CONTAINER_NAME}" -p 8080:8080 "${IMAGE_NAME}:${IMAGE_TAG}"

echo "--- 오래된 이미지 정리 ---"
docker image prune -f

echo "--- 배포 성공! ---"

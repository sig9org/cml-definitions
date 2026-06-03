#!/bin/bash

DIR="file"
CODENAME="resolute"
DATE="20260520"
RESIZE="+1.5G"
TYPE=$1
SCRIPT="https://raw.githubusercontent.com/sig9org/cml-definitions/master/definitions/ubuntu-${TYPE}/script/ubuntu-${TYPE}.sh"

echo "############################################################"
echo "##### (1/x) Download the image and make a copy for work.."
echo "############################################################"

mkdir -p ${DIR}/
rm -f ${DIR}/${CODENAME}-server-cloudimg-amd64.img
axel https://cloud-images.ubuntu.com/${CODENAME}/${DATE}/${CODENAME}-server-cloudimg-amd64.img \
  -o ${DIR}/${CODENAME}-server-cloudimg-amd64.qcow2
cp ${DIR}/${CODENAME}-server-cloudimg-amd64.qcow2 \
  ${DIR}/${CODENAME}-server-cloudimg-amd64-tmp.qcow2
eza -hl file/*.qcow2

echo "############################################################"
echo "##### (2/x) Resize the image."
echo "############################################################"

qemu-img resize ${DIR}/${CODENAME}-server-cloudimg-amd64-tmp.qcow2 ${RESIZE}
qemu-img info ${DIR}/${CODENAME}-server-cloudimg-amd64-tmp.qcow2

echo "############################################################"
echo "##### (3/x) Customize the image."
echo "############################################################"

virt-customize -v -x -a ${DIR}/${CODENAME}-server-cloudimg-amd64-tmp.qcow2 \
  --run-command 'growpart /dev/sda 1' \
  --run-command 'resize2fs /dev/sda1' \
  --run-command "curl -Ls ${SCRIPT} | bash -s"

echo "############################################################"
echo "##### (4/x) Compress images."
echo "############################################################"

virt-sparsify --compress \
  ${DIR}/${CODENAME}-server-cloudimg-amd64-tmp.qcow2 \
  ${DIR}/${CODENAME}-server-cloudimg-amd64-${TYPE}-${DATE}.qcow2
eza -hl file/*.qcow2
rm -f ${DIR}/${CODENAME}-server-cloudimg-amd64-tmp.qcow2

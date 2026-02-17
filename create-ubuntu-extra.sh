#!/bin/bash

DIR="file"
DATE="20260214"
RESIZE="+1.5G"
SCRIPT="https://raw.githubusercontent.com/sig9org/cml-definitions/master/definitions/ubuntu-extra/script/ubuntu-extra.sh"

echo "############################################################"
echo "##### (1/x) Download the image and make a copy for work.."
echo "############################################################"

mkdir -p ${DIR}/
rm -f ${DIR}/noble-server-cloudimg-amd64.img
axel https://cloud-images.ubuntu.com/noble/${DATE}/noble-server-cloudimg-amd64.img \
  -o ${DIR}/noble-server-cloudimg-amd64.qcow2
cp ${DIR}/noble-server-cloudimg-amd64.qcow2 \
  ${DIR}/noble-server-cloudimg-amd64-tmp.qcow2
eza -hl file/*.qcow2

echo "############################################################"
echo "##### (2/x) Resize the image."
echo "############################################################"

qemu-img resize ${DIR}/noble-server-cloudimg-amd64-tmp.qcow2 ${RESIZE}
qemu-img info ${DIR}/noble-server-cloudimg-amd64-tmp.qcow2

echo "############################################################"
echo "##### (3/x) Customize the image."
echo "############################################################"

virt-customize -v -x -a ${DIR}/noble-server-cloudimg-amd64-tmp.qcow2 \
  --run-command 'growpart /dev/sda 1' \
  --run-command 'resize2fs /dev/sda1' \
  --run-command "curl -Ls ${SCRIPT} | bash -s"

echo "############################################################"
echo "##### (4/x) Compress images."
echo "############################################################"

virt-sparsify --compress \
  ${DIR}/noble-server-cloudimg-amd64-tmp.qcow2 \
  ${DIR}/noble-server-cloudimg-amd64-extra-${DATE}.qcow2
eza -hl file/*.qcow2
rm -f ${DIR}/noble-server-cloudimg-amd64-tmp.qcow2

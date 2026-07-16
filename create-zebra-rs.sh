#!/bin/bash

DIR="file"
CODENAME="resolute"
DATE=$1
RESIZE="+1.5G"
SCRIPT="https://raw.githubusercontent.com/sig9org/cml-definitions/master/definitions/zebra-rs/script/zebra-rs.sh"
ZEBRA_VERSION=$2
ARCH=$3

echo "############################################################"
echo "##### (1/4) Download the image and make a copy for work.."
echo "############################################################"

mkdir -p ${DIR}/
rm -f ${DIR}/${CODENAME}-server-cloudimg-${ARCH}.img
axel https://cloud-images.ubuntu.com/${CODENAME}/${DATE}/${CODENAME}-server-cloudimg-${ARCH}.img \
  -o ${DIR}/${CODENAME}-server-cloudimg-${ARCH}.qcow2
cp ${DIR}/${CODENAME}-server-cloudimg-${ARCH}.qcow2 \
  ${DIR}/${CODENAME}-server-cloudimg-${ARCH}-tmp.qcow2
eza -hl file/*.qcow2

echo "############################################################"
echo "##### (2/4) Resize the image."
echo "############################################################"

qemu-img resize ${DIR}/${CODENAME}-server-cloudimg-${ARCH}-tmp.qcow2 ${RESIZE}
qemu-img info ${DIR}/${CODENAME}-server-cloudimg-${ARCH}-tmp.qcow2

echo "############################################################"
echo "##### (3/4) Customize the image."
echo "############################################################"

virt-customize -v -x -a ${DIR}/${CODENAME}-server-cloudimg-${ARCH}-tmp.qcow2 \
  --run-command 'growpart /dev/sda 1' \
  --run-command 'resize2fs /dev/sda1' \
  --run-command "curl -Ls ${SCRIPT} | bash -s ${ZEBRA_VERSION} ${ARCH} ${CODENAME}"

echo "############################################################"
echo "##### (4/4) Compress images."
echo "############################################################"

virt-sparsify --compress \
  ${DIR}/${CODENAME}-server-cloudimg-${ARCH}-tmp.qcow2 \
  ${DIR}/zebra-rs-${ARCH}-${ZEBRA_VERSION}.qcow2
eza -hl file/*.qcow2
rm -f ${DIR}/${CODENAME}-server-cloudimg-${ARCH}-tmp.qcow2

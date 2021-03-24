#cloud-config
manage_etc_hosts: true
hostname: ${hostname}

users:
  - default
  - name: ${adminuser}
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh-authorized-keys:
      - ${sshkey}

disk_setup:
  /dev/disk/azure/scsi1/lun${lun}:
    table_type: gpt
    layout: True
    overwrite: True

fs_setup:
    - device: /dev/disk/azure/scsi1/lun${lun}
      partition: 1
      filesystem: ext4

mounts:
    - ["/dev/disk/azure/scsi1/lun${lun}-part1", "${mountpoint}", auto, "defaults,noexec,nofail"]
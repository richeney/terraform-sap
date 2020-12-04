# Notes

## Mounting the SAP Hana media

```bash
sudo yum update
sudo yum install nfs-utils
sudo mkdir -p /mount/saphananfsuks/saphanamedia
sudo mount -t nfs saphananfsuks.file.core.windows.net:/saphananfsuks/saphanamedia /mount/saphananfsuks/saphanamedia -o vers=4,minorversion=1,sec=sys
```

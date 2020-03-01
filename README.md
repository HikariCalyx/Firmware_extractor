## Requirements
- protobuf
- LZMA
- 7z
- lz4
### Linux
```
apt install unace unrar zip unzip p7zip-full p7zip-rar sharutils rar uudeview mpack arj cabextract file-roller rename
apt install liblzma-dev python-pip brotli lz4
pip install backports.lzma protobuf pycrypto
```
### Mac
```
brew install protobuf liblzma-dev brotli lz4
pip install backports.lzma protobuf pycrypto
```
Also install [mono](https://www.mono-project.com/docs/getting-started/install/mac/)  

## How to use
### Download
```
git clone --recurse-submodules https://github.com/erfanoabdi/Firmware_extractor.git
```

### Extract images from firmware URL
Example: Extracting images from pixel 2 factory image:
```
cd Firmware_extractor
wget https://dl.google.com/dl/android/aosp/walleye-pq3a.190705.001-factory-cc471c8c.zip -o firmware.zip
./extractor.sh firmware.zip
```
output will be on "Firmware_extractor/out"

# Above mover.sh and patcher.sh

## mover.sh
The mover.sh is meant for moving unpacked FIHSW firmwares (a.k.a. nb0) and repacking them as patchable package.

Example:
```
cd FIHSW_PNX-2590-0-00CN-B03_600CN_9_20190201.full
# Command below is meant to ensure if there's systeminfo.img file exists, as the script will read original filename from it.
ls | grep systeminfo.img
../mover.sh
```

Soon a package will be created at root directory of this tool known as \[FIH_Firmware_Build_Version\].zip, in this case:
> PNX-2590-0-00CN-B03.zip

The FIH Firmware Build Version will be read from systeminfo.img as well.
For MediaTek models, I tried to add a header at the beginning of preloader partition to make sure it will be processed by patcher.

## patcher.sh

patcher.sh relies on extractor.sh to make it working.
Comparing to original extractor.sh, this extractor.sh is modified for HMD Nokia Phones (and Probably Sharp Aquos S2 / C10 / S3 / S3 mini) with A/B seamless update.

You can use it with either packed zip files that used what you dumped from phone, or full OTA package.

Usage 1 (if you use full dump):
```
./patcher.sh -v dump_images.zip ota_package_1.zip ota_package_2.zip ota_package_3.zip ... ota_package_32767.zip
```

Example:
```
./patcher.sh -v PNX-2590-0-00CN-B03.zip PNX-259E-0-00CN-B03-2590-0-00CN-B03-update.zip PNX-259G-0-00CN-B03-259E-0-00CN-B03-update.zip
```

Usage 2 (if you use full ota):
```
./patcher.sh -v full_ota.zip ota_package_1.zip ota_package_2.zip ota_package_3.zip ... ota_package_32767.zip
```

Example:
```
./patcher.sh -v B2N-347C-0-00CN-B04-update.zip B2N-347D-0-00CN-B02-347C-0-00CN-B04-update.zip B2N-347H-0-00CN-B03-347D-0-00CN-B02-update.zip B2N-347I-0-00CN-B02-347H-0-00CN-B03-update.zip
```

Please read this if you want to know details about FIH Firmware Build Version:
https://forum.xda-developers.com/nokia-6/how-to/knowledge-fih-firmware-build-version-t3887411

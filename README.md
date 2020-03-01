## Requirements
- protobuf
- LZMA
- 7z
- lz4
### Linux
Take Debian-based distro (e.g. Ubuntu) for example. If you use other flavor (Redhat-based like Fedora or Arch-based like Manjaro), you'll use the package manager of your own distro. WSL is not tested yet and not guaranteed.
```
apt install zip p7zip-full sharutils uudeview mpack arj cabextract file-roller rename liblzma-dev python-pip brotli
pip install backports.lzma protobuf pycrypto bsdiff4
```
### Mac
```
brew install protobuf liblzma-dev brotli lz4
pip install backports.lzma protobuf pycrypto bsdiff4
```
Also install [mono](https://www.mono-project.com/docs/getting-started/install/mac/)  

## How to use
### Download
```
git clone --recurse-submodules https://github.com/HikariCalyx/Firmware_extractor.git
```

### Extract images from firmware URL
Example: Extracting images from pixel 2 factory image:
```
cd Firmware_extractor
wget https://dl.google.com/dl/android/aosp/walleye-pq3a.190705.001-factory-cc471c8c.zip -o firmware.zip
./extractor.sh firmware.zip
```
output will be on "Firmware_extractor/out"

# About mover.sh and patcher.sh

## mover.sh
The mover.sh is meant for moving unpacked FIHSW firmwares (a.k.a. nb0) and repacking them as patchable package. HCTSW firmwares may work as well.

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

> A-Only device testing under progress...

### Support A/B seamless update devices
- Nokia 3.1 (ES2)
- Nokia 3.1 A & C (EAG)
- Nokia 3.1 Plus (ROO)
- Nokia 3.1 Plus C (RHD)
- Nokia 3.2 / V (DPL / DVW)
- Nokia 4.2 (PAN)
- Nokia 5.1 (CO2)
- Nokia 5.1 Plus X5 (PDA)
- Nokia 6.1 (PL2)
- Nokia 6.1 Plus X6 (DRG)
- Nokia 6.2 (SLD)
- Nokia 7 (C1N)
- Nokia 7 Plus (B2N)
- Nokia 7.1 (CTL)
- Nokia X71 (TAS)
- Nokia 7.2 (DDV)
- Nokia 8 (NB1)
- Nokia 8 Sirocco (A1N)
- Nokia 8.1 X7 (PNX)
- Nokia 9 PureView (AOP)
- Sharp Aquos S2 / C10 (SS2 / SAT)
- Sharp Aquos S3 / D10 (HH1 / HH6 / SD1)
- Sharp Aquos S3 mini (SG1)

### Unsupported A/B seamless update devices (from HMD Nokia) so far
- Nokia 2.2 (WSP)
- Nokia 2.3 (IRM)

You can use it with either packed zip files that used what you dumped from phone, or full OTA package.

Usage 1 (if you use full dump):
```
./patcher.sh -v dump_images.zip ota_package_1.zip ota_package_2.zip ota_package_3.zip ... ota_package_32767.zip
```

However, if you only want to patch boot, dtbo, vbmeta, system, vendor and modem, you can just pack them as zip and patch them directly.

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

All the updated images will be placed at out directory. Comparing to install them on the phone, this method is apparently faster.

Please read this if you want to know details about FIH Firmware Build Version:
https://forum.xda-developers.com/nokia-6/how-to/knowledge-fih-firmware-build-version-t3887411

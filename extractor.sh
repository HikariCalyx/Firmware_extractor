#!/bin/bash

# Supported Firmwares:
# Aonly OTA
# Raw image
# tarmd5
# chunk image
# QFIL
# AB OTA
# Image zip
# ozip
# Sony ftf
# ZTE update.zip
# KDDI .bin
# bin images
# pac
# sign images
# nb0
# kdz
# RUU

usage() {
    echo "Usage: $0 <Path to firmware> [Output Dir]"
    echo -e "\tPath to firmware: the zip!"
    echo -e "\tOutput Dir: the output dir!"
}

if [ "$1" == "" ]; then
    echo "BRUH: Enter all needed parameters"
    usage
    exit 1
fi

LOCALDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOST="$(uname)"
toolsdir="$LOCALDIR/tools"

if [[ ! -d "$toolsdir/extract_android_ota_payload" ]]; then
    git clone -q https://github.com/cyxx/extract_android_ota_payload.git "$toolsdir/extract_android_ota_payload"
else
    git -C "$toolsdir/extract_android_ota_payload" pull
fi
if [[ ! -d "$toolsdir/oppo_ozip_decrypt" ]]; then
    git clone -q https://github.com/bkerler/oppo_ozip_decrypt.git "$toolsdir/oppo_ozip_decrypt"
else
    git -C "$toolsdir/oppo_ozip_decrypt" pull
fi
if [[ ! -d "$toolsdir/update_payload_extractor" ]]; then
    git clone -q https://github.com/erfanoabdi/update_payload_extractor.git "$toolsdir/update_payload_extractor"
else
    git -C "$toolsdir/update_payload_extractor" pull
fi

simg2img="$toolsdir/$HOST/bin/simg2img"
packsparseimg="$toolsdir/$HOST/bin/packsparseimg"
unsin="$toolsdir/$HOST/bin/unsin"
payload_extractor="$toolsdir/update_payload_extractor/extract.py"
sdat2img="$toolsdir/sdat2img.py"
ozipdecrypt="$toolsdir/oppo_ozip_decrypt/ozipdecrypt.py"
lpunpack="$toolsdir/$HOST/bin/lpunpack"
splituapp="$toolsdir/splituapp"
pacextractor="$toolsdir/$HOST/bin/pacextractor"
nb0_extract="$toolsdir/$HOST/bin/nb0-extract"
kdz_extract="$toolsdir/KDZFileTools.py"
dz_extract="$toolsdir/undz.py"
ruu="$toolsdir/$HOST/bin/RUU_Decrypt_Tool"

romzip="$(realpath $1)"
romzipext=${romzip##*.}
PARTITIONS="system vendor cust odm oem factory product xrom modem dtbo boot tz systemex oppo_product preload_common abl bluetooth cda cmnlib cmnlib64 devcfg dsp hidden hyp keymaster mdtp mdtpsecapp nvdef pmic rpm splash systeminfo xbl xbl_config preloader tee odmdtbo logo spmfw scp sspm cam_vpu1 cam_vpu2 cam_vpu3 md1img lk logo vbmeta aop ImageFv qupfw storsec zplash aboot sbl1 custom picture"
EXT4PARTITIONS="system vendor cust odm oem factory product xrom systemex oppo_product preload_common custom"
OTHERPARTITIONS="tz.mbn:tz tz.img:tz modem.img:modem NON-HLOS:modem boot-verified.img:boot dtbo-verified.img:dtbo abl:abl bluetooth:bluetooth cda:cda cmnlib.:cmnlib cmnlib64:cmnlib64 devcfg:devcfg dsp:dsp hidden:hidden hyp:hyp keymaster:keymaster mdtp.:mdtp mdtpsecapp:mdtpsecapp nvdef:nvdef pmic:pmic rpm:rpm splash:splash systeminfo:systeminfo xbl.:xbl xbl_config:xbl_config tee:tee odmdtbo:odmdtbo logo:logo spmfw:spmfw scp:scp sspm:sspm cam_vpu1:cam_vpu1 cam_vpu2:cam_vpu2 cam_vpu3:cam_vpu3 preloader:preloader md1img:md1img lk:lk vbmeta:vbmeta aop:aop qupfw:qupfw qupv3fw:qupv3fw km4:keymaster storsec:storsec zplash:zplash aboot:aboot emmc_appsboot:aboot sbl1:sbl1 picture:picture"

echo "Create Temp and out dir"
outdir="$LOCALDIR/out"
if [ ! "$2" == "" ]; then
    outdir="$(realpath $2)"
fi
tmpdir="$outdir/tmp"
mkdir -p "$tmpdir"
mkdir -p "$outdir"
cd $tmpdir

MAGIC=$(head -c12 $romzip | tr -d '\0')
if [[ $MAGIC == "OPPOENCRYPT!" ]] || [[ "$romzipext" == "ozip" ]]; then
    echo "ozip detected"
    cp $romzip "$tmpdir/temp.ozip"
    python $ozipdecrypt "$tmpdir/temp.ozip"
    if [[ -d "$tmpdir/out" ]]; then
        7z a -r "$tmpdir/temp.zip" "$tmpdir/out/*"
    fi
    "$LOCALDIR/extractor.sh" "$tmpdir/temp.zip" "$outdir"
    exit
fi

if [[ $(echo $romzip | grep kdz) ]]; then
    echo "KDZ detected"
    python $kdz_extract -f $romzip -x -o "./"
    dzfile=`ls -l | grep ".*.dz" | gawk '{ print $9 }'`
    python $dz_extract -f $dzfile -i -o "./"
    for partition in $PARTITIONS; do
        [[ -e "$tmpdir/$partition.img" ]] && mv "$tmpdir/$partition.img" "$outdir/$partition.img"
    done
    rm -rf $tmpdir
    exit 0
fi

if [[ $(echo $romzip | grep -i ruu_ | grep -i exe) ]]; then
    echo "RUU detected"
    cp $romzip $tmpdir
    romzip="$tmpdir/$(basename $romzip)"
    $ruu -s $romzip 2>/dev/null
    $ruu -f $romzip 2>/dev/null
    find "$tmpdir/OUT"* -name *.img -exec mv {} $tmpdir \;
    for partition in $PARTITIONS; do
        [[ -e "$tmpdir/$partition.img" ]] && mv "$tmpdir/$partition.img" "$outdir/$partition.img"
    done
    rm -rf $tmpdir
    exit 0
fi

if [[ ! $(7z l -ba $romzip | grep ".*system.ext4.tar.*\|.*.tar\|.*chunk\|system\/build.prop\|system.new.dat\|system_new.img\|system.img\|system-sign.img\|system.bin\|payload.bin\|.*.zip\|.*.rar\|.*rawprogram*\|system.sin\|.*system_.*\.sin\|system-p\|super\|UPDATE.APP\|.*.pac\|.*.nb0" | grep -v ".*chunk.*\.so$") ]]; then
    echo "BRUH: This type of firmwares not supported"
    cd "$LOCALDIR"
    rm -rf "$tmpdir" "$outdir"
    exit 1
fi

echo "Extracting firmware on: $outdir"

for otherpartition in $OTHERPARTITIONS; do
    filename=$(echo $otherpartition | cut -f 1 -d ":")
    outname=$(echo $otherpartition | cut -f 2 -d ":")
    if [[ $(7z l -ba $romzip | grep $filename) ]]; then
        echo "$filename detected for $outname"
        foundfiles=$(7z l -ba $romzip | gawk '{ print $NF }' | grep $filename)
        7z e -y $romzip $foundfiles 2>/dev/null >> $tmpdir/zip.log
        outputs=$(ls *"$filename"*)
        for output in $outputs; do
            [[ ! -e "$outname".img ]] && mv $output "$outname".img
            $simg2img "$outname".img "$outdir/$outname".img 2>/dev/null
            if [[ ! -s "$outdir/$outname".img ]] && [ -f "$outname".img ]; then
                mv "$outname".img "$outdir/$outname".img
            fi
        done
    fi
done

if [[ $(7z l -ba $romzip | grep firmware-update/dtbo.img) ]]; then
    7z e -y $romzip firmware-update/dtbo.img 2>/dev/null >> $tmpdir/zip.log
fi
if [[ $(7z l -ba $romzip | grep system.new.dat) ]]; then
    echo "Aonly OTA detected"
    for partition in $PARTITIONS; do
        7z e -y $romzip $partition.new.dat* $partition.transfer.list $partition.img 2>/dev/null >> $tmpdir/zip.log
        if [[ -f $partition.new.dat.1 ]]; then
            cat $partition.new.dat.{0..999} 2>/dev/null >> $partition.new.dat
            rm -rf $partition.new.dat.{0..999}
        fi
        ls | grep "\.new\.dat" | while read i; do
            line=$(echo "$i" | cut -d"." -f1)
            if [[ $(echo "$i" | grep "\.dat\.xz") ]]; then
                7z e -y "$i" 2>/dev/null >> $tmpdir/zip.log
                rm -rf "$i"
            fi
            if [[ $(echo "$i" | grep "\.dat\.br") ]]; then
                echo "Converting brotli $partition dat to normal"
                brotli -d "$i"
                rm -f "$i"
            fi
            echo "Extracting $partition"
            python3 $sdat2img $line.transfer.list $line.new.dat "$outdir"/$line.img > $tmpdir/extract.log
            rm -rf $line.transfer.list $line.new.dat
        done
    done
elif [[ $(7z l -ba $romzip | grep rawprogram) ]]; then
    echo "QFIL detected"
    rawprograms=$(7z l -ba $romzip | gawk '{ print $NF }' | grep rawprogram)
    7z e -y $romzip $rawprograms 2>/dev/null >> $tmpdir/zip.log
    for partition in $PARTITIONS; do
        partitionsonzip=$(7z l -ba $romzip | gawk '{ print $NF }' | grep $partition)
        if [[ ! $partitionsonzip == "" ]]; then
            7z e -y $romzip $partitionsonzip 2>/dev/null >> $tmpdir/zip.log
            if [[ ! -f "$partition.img" ]]; then
                if [[ -f "$partition.raw.img" ]]; then
                    mv "$partition.raw.img" "$partition.img"
                else
                    rawprogramsfile=$(grep -rlw $partition rawprogram*.xml)
                    $packsparseimg -t $partition -x $rawprogramsfile > $tmpdir/extract.log
                    mv "$partition.raw" "$partition.img"
                fi
            fi
        fi
    done
elif [[ $(7z l -ba $romzip | grep nb0) ]]; then
    echo "nb0 detected"
    to_extract=`7z l $romzip | grep ".*.nb0" | gawk '{ print $6 }'`
    echo $to_extract
    7z e -y $romzip $to_extract 2>/dev/null >> $tmpdir/zip.log
    $nb0_extract $to_extract $tmpdir
    for partition in $PARTITIONS; do
        part=`ls -l | grep ".*$partition.img" | gawk '{ print $9 }'`
        mv $part $partition.img
    done
    romzip=""
elif [[ $(7z l -ba $romzip | grep system | grep chunk | grep -v ".*\.so$") ]]; then
    echo "chunk detected"
    for partition in $PARTITIONS; do
        foundpartitions=$(7z l -ba $romzip | gawk '{ print $NF }' | grep $partition.img)
        7z e -y $romzip *$partition*chunk* */*$partition*chunk* $foundpartitions dummypartition 2>/dev/null >> $tmpdir/zip.log
        rm -f *"$partition"_b*
        rm -f *"$partition"_other*
        romchunk=$(ls | grep chunk | grep $partition | sort)
        if [[ $(echo "$romchunk" | grep "sparsechunk") ]]; then
            $simg2img $(echo "$romchunk" | tr '\n' ' ') $partition.img.raw 2>/dev/null
            rm -rf *$partition*chunk*
            if [[ -f $partition.img ]]; then
                rm -rf $partition.img.raw
            else
                mv $partition.img.raw $partition.img
            fi
        fi
    done
elif [[ $(7z l -ba $romzip | gawk '{print $NF}' | grep "system_new.img\|^system.img\|\/system.img\|\/system_image.emmc.img\|^system_image.emmc.img") ]]; then
    echo "Image detected"
    7z x -y $romzip 2>/dev/null >> $tmpdir/zip.log
    find $tmpdir/ -name "* *" -type d,f | rename 's/ /_/g' > /dev/null 2>&1 # removes space from file name
    find $tmpdir/ -mindepth 2 -type f -name "*_image.emmc.img" -exec mv {} . \; # move .img in sub-dir to $tmpdir
    find $tmpdir/ -mindepth 2 -type f -name "*_new.img" -exec mv {} . \; # move .img in sub-dir to $tmpdir
    find $tmpdir/ -mindepth 2 -type f -name "*.img.ext4" -exec mv {} . \; # move .img in sub-dir to $tmpdir
    find $tmpdir/ -mindepth 2 -type f -name "*.img" -exec mv {} . \; # move .img in sub-dir to $tmpdir
    find $tmpdir/ -type f ! -name "*img*" -exec rm -rf {} \; # delete other files
    find "$tmpdir" -maxdepth 1 -type f -name "*_image.emmc.img" | rename 's/_image.emmc.img/.img/g' > /dev/null 2>&1 # proper .img names
    find "$tmpdir" -maxdepth 1 -type f -name "*_new.img" | rename 's/_new.img/.img/g' > /dev/null 2>&1 # proper .img names
    find "$tmpdir" -maxdepth 1 -type f -name "*.img.ext4" | rename 's/.img.ext4/.img/g' > /dev/null 2>&1 # proper .img names
    romzip=""
elif [[ $(7z l -ba $romzip | grep "system.sin\|.*system_.*\.sin") ]]; then
    echo "sin detected"
    to_remove=`7z l $romzip | grep ".*boot_.*\.sin" | gawk '{ print $6 }' | sed -e 's/boot_\(.*\).sin/\1/'`
    if [ -z "$to_remove" ]
    then
      to_remove=`7z l $romzip | grep ".*cache_.*\.sin" | gawk '{ print $6 }' | sed -e 's/cache_\(.*\).sin/\1/'`
    fi
    if [ -z "$to_remove" ]
    then
      to_remove=`7z l $romzip | grep ".*vendor_.*\.sin" | gawk '{ print $6 }' | sed -e 's/vendor_\(.*\).sin/\1/'`
    fi
    7z x -y $romzip 2>/dev/null >> $tmpdir/zip.log
    find $tmpdir/ -mindepth 2 -type f -name "*.sin" -exec mv {} . \; # move .img in sub-dir to $tmpdir
    find "$tmpdir" -maxdepth 1 -type f -name "*_$to_remove.sin" | rename 's/_'$to_remove'.sin/.sin/g' > /dev/null 2>&1 # proper names
    $unsin -d $tmpdir
    find "$tmpdir" -maxdepth 1 -type f -name "*.ext4" | rename 's/.ext4/.img/g' > /dev/null 2>&1 # proper names
    romzip=""
elif [[ $(7z l -ba $romzip | grep ".*.pac") ]]; then
    echo "pac detected"
    7z x -y $romzip 2>/dev/null >> $tmpdir/zip.log
    find $tmpdir/ -name "* *" -type d,f | rename 's/ /_/g' > /dev/null 2>&1
    pac_list=`find $tmpdir/ -type f -name "*.pac" -printf '%P\n' | sort`
    for file in $pac_list; do
       $pacextractor $file
    done
elif [[ $(7z l -ba $romzip | grep "system.bin") ]]; then
    echo "bin images detected"
    7z x -y $romzip 2>/dev/null >> $tmpdir/zip.log
    find $tmpdir/ -mindepth 2 -type f -name "*.bin" -exec mv {} . \; # move .img in sub-dir to $tmpdir
    find "$tmpdir" -maxdepth 1 -type f -name "*.bin" | rename 's/.bin/.img/g' > /dev/null 2>&1 # proper names
    romzip=""
elif [[ $(7z l -ba $romzip | grep "system-p") ]]; then
    echo "P suffix images detected"
    for partition in $PARTITIONS; do
        foundpartitions=$(7z l -ba $romzip | gawk '{ print $NF }' | grep $partition-p)
        7z e -y $romzip $foundpartitions dummypartition 2>/dev/null >> $tmpdir/zip.log
        if [ ! -z "$foundpartitions" ]; then
            mv $(ls $partition-p*) "$partition.img"
        fi
    done
elif [[ $(7z l -ba $romzip | grep "system-sign.img") ]]; then
    echo "sign images detected"
    7z x -y $romzip 2>/dev/null >> $tmpdir/zip.log
    find $tmpdir/ -name "* *" -type d,f | rename 's/ /_/g' > /dev/null 2>&1 # removes space from file name
    find $tmpdir/ -mindepth 2 -type f -name "*-sign.img" -exec mv {} . \; # move .img in sub-dir to $tmpdir
    find $tmpdir/ -type f ! -name "*-sign.img" -exec rm -rf {} \; # delete other files
    find "$tmpdir" -maxdepth 1 -type f -name "*-sign.img" | rename 's/-sign.img/.img/g' > /dev/null 2>&1 # proper .img names
    mv "$tmpdir/boot.img" "$outdir/boot.img"
    sign_list=`find "$tmpdir" -maxdepth 1 -type f -name "*.img" -printf '%P\n' | sort`
    for file in $sign_list; do
        rm -rf "$tmpdir/x.img"
        dd if="$tmpdir/$file" of="$tmpdir/x.img" bs=$((0x4040)) skip=1 > /dev/null 2>&1
        $simg2img "$tmpdir/x.img" "$tmpdir/$file" > /dev/null 2>&1
    done
    romzip=""
elif [[ $(7z l -ba $romzip | grep "super.img") ]]; then
    echo "super detected"
    foundsupers=$(7z l -ba $romzip | gawk '{ print $NF }' | grep "super.img")
    7z e -y $romzip $foundsupers dummypartition 2>/dev/null >> $tmpdir/zip.log
    superchunk=$(ls | grep chunk | grep super | sort)
    if [[ $(echo "$superchunk" | grep "sparsechunk") ]]; then
        $simg2img $(echo "$superchunk" | tr '\n' ' ') super.img.raw 2>/dev/null
        rm -rf *super*chunk*
    fi
    if [ -f super.img ]; then
        $simg2img super.img super.img.raw 2>/dev/null
    fi
    if [[ ! -s super.img.raw ]] && [ -f super.img ]; then
        mv super.img super.img.raw
    fi

    for partition in $PARTITIONS; do
        ($lpunpack --partition="$partition"_a super.img.raw || $lpunpack --partition="$partition" super.img.raw) 2>/dev/null
        if [ -f "$partition"_a.img ]; then
            mv "$partition"_a.img "$partition".img
        else
            foundpartitions=$(7z l -ba $romzip | gawk '{ print $NF }' | grep $partition.img)
            7z e -y $romzip $foundpartitions dummypartition 2>/dev/null >> $tmpdir/zip.log
        fi
    done
    rm -rf super.img.raw
elif [[ $(7z l -ba $romzip | grep tar.md5 | gawk '{ print $NF }' | grep AP_) ]]; then
    echo "AP tarmd5 detected"
    mainmd5=$(7z l -ba $romzip | grep tar.md5 | gawk '{ print $NF }' | grep AP_)
    cscmd5=$(7z l -ba $romzip | grep tar.md5 | gawk '{ print $NF }' | grep CSC_)
    echo "Extracting tarmd5"
    7z e -y $romzip $mainmd5 $cscmd5 2>/dev/null >> $tmpdir/zip.log
    mainmd5=$(7z l -ba $romzip | grep tar.md5 | gawk '{ print $NF }' | grep AP_ | sed 's|.*/||')
    cscmd5=$(7z l -ba $romzip | grep tar.md5 | gawk '{ print $NF }' | grep CSC_ | sed 's|.*/||')
    echo "Extracting images..."
    for i in "$mainmd5" "$cscmd5"; do
        if [ ! -f "$i" ]; then
            continue
        fi
        for partition in $PARTITIONS; do
            tarulist=$(tar -tf $i | grep -e ".*$partition.*\.img.*\|.*$partition.*ext4")
            echo "$tarulist" | while read line; do
                tar -xf "$i" "$line"
                if [[ $(echo "$line" | grep "\.lz4") ]]; then
                    unlz4 -f -q "$line" "$partition.img"
                    rm -f "$line"
                    line=$(echo "$line" | sed 's/\.lz4$//')
                fi
                if [[ $(echo "$line" | grep "\.ext4") ]]; then
                    mv "$line" "$(echo "$line" | cut -d'.' -f1).img"
                fi
            done
        done
    done
    if [[ -f system.img ]]; then
        rm -rf $mainmd5
        rm -rf $cscmd5
    else
        echo "Extract failed"
        rm -rf "$tmpdir"
        exit 1
    fi
    romzip=""
elif [[ $(7z l -ba $romzip | grep .tar) && ! $(7z l -ba $romzip | grep tar.md5 | gawk '{ print $NF }' | grep AP_) ]]; then
    tar=$(7z l -ba $romzip | grep .tar | gawk '{ print $NF }')
    echo "non AP tar detected"
    7z e -y $romzip $tar 2>/dev/null >> $tmpdir/zip.log
    "$LOCALDIR/extractor.sh" $tar "$outdir"
    exit
elif [[ $(7z l -ba $romzip | grep payload.bin) ]]; then
    echo "AB OTA detected"
    7z e -y $romzip payload.bin 2>/dev/null >> $tmpdir/zip.log
    python "$LOCALDIR/tools/extract_android_ota_payload/extract_android_ota_payload.py" payload.bin $tmpdir
    for partition in $PARTITIONS; do
        [[ -e "$tmpdir/$partition.img" ]] && mv "$tmpdir/$partition.img" "$outdir/$partition.img"
    done
    rm payload.bin
    rm -rf "$tmpdir"
    exit
elif [[ $(7z l -ba $romzip | grep ".*.rar\|.*.zip") ]]; then
    echo "Image zip firmware detected"
    mkdir -p $tmpdir/zipfiles
    7z e -y $romzip -o$tmpdir/zipfiles 2>/dev/null >> $tmpdir/zip.log
    find $tmpdir/zipfiles -name "* *" -type d,f | rename 's/ /_/g' > /dev/null 2>&1
    zip_list=`find $tmpdir/zipfiles -type f -size +300M \( -name "*.rar*" -o -name "*.zip*" \) -printf '%P\n' | sort`
    for file in $zip_list; do
       "$LOCALDIR/extractor.sh" $tmpdir/zipfiles/$file "$outdir"
    done
    exit
elif [[ $(7z l -ba $romzip | grep "UPDATE.APP") ]]; then
    echo "Huawei UPDATE.APP detected"
    7z x $romzip UPDATE.APP
    python3 $splituapp -f "UPDATE.APP" -l super || (
    for partition in $PARTITIONS; do
        python3 $splituapp -f "UPDATE.APP" -l ${partition/.img/} || echo "$partition not found in UPDATE.APP"
    done)
    if [ -f super.img ]; then
        ($simg2img super.img super.img.raw || mv super.img super.img.raw) 2>/dev/null

        for partition in $PARTITIONS; do
            ($lpunpack --partition="$partition"_a super.img.raw || $lpunpack --partition="$partition" super.img.raw) 2>/dev/null
            if [ -f "$partition"_a.img ]; then
                mv "$partition"_a.img "$partition".img
            else
                foundpartitions=$(7z l -ba $romzip | gawk '{ print $NF }' | grep $partition.img)
                7z e -y $romzip $foundpartitions dummypartition 2>/dev/null >> $tmpdir/zip.log
            fi
        done
        rm -rf super.img.raw
    fi
fi

for partition in $PARTITIONS; do
    if [ -f $partition.img ]; then
        $simg2img $partition.img "$outdir"/$partition.img 2>/dev/null
    fi
    if [[ ! -s "$outdir"/$partition.img ]] && [ -f $partition.img ]; then
        mv $partition.img "$outdir"/$partition.img
    fi

    if [[ $EXT4PARTITIONS =~ (^|[[:space:]])"$partition"($|[[:space:]]) ]] && [ -f "$outdir"/$partition.img ]; then
        MAGIC=$(head -c12 "$outdir"/$partition.img | tr -d '\0')
        offset=$(LANG=C grep -aobP -m1 '\x53\xEF' "$outdir"/$partition.img | head -1 | gawk '{print $1 - 1080}')
        if [[ $(echo "$MAGIC" | grep "MOTO") ]]; then
            if [[ "$offset" == 128055 ]]; then
                offset=131072
            fi
            echo "MOTO header detected on $partition in $offset"
        elif [[ $(echo "$MAGIC" | grep "ASUS") ]]; then
            echo "ASUS header detected on $partition in $offset"
        else
            offset=0
        fi
        if [ ! $offset == "0" ]; then
            dd if="$outdir"/$partition.img of="$outdir"/$partition.img-2 ibs=$offset skip=1 2>/dev/null
            mv "$outdir"/$partition.img-2 "$outdir"/$partition.img
        fi
    fi

    if [ ! -s "$outdir"/$partition.img ] && [ -f "$outdir"/$partition.img ]; then
        rm "$outdir"/$partition.img
    fi
done

cd "$LOCALDIR"
rm -rf "$tmpdir"

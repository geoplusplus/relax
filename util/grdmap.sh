#!/bin/sh

set -e
self=$(basename $0)
selfdir=$(dirname $0)
cmdline=$*
trap 'echo $self: Some errors occurred. Exiting.; exit' ERR

my_gmt(){

grdimage $U3 -R$bds -J${PROJ} \
    $AXIS \
    -K -C$colors -P -X1.2i -Y${YSHIFT}i $illumination \
    > $PSFILE

# running all required subprograms
for subprog in $EXTRA;do
if [ -e "$selfdir/$subprog" ]; then
	#echo $self: running $subprog $PSFILE $bds $VECTOR $U3 $HEIGHT
	eval "$subprog $PSFILE $bds $VECTOR $U3 $HEIGHT"
else
	if [ -e "$subprog" ]; then
		#echo $self: running $subprog $PSFILE $bds $VECTOR $U3 $HEIGHT
		eval "$subprog $PSFILE $bds $VECTOR $U3 $HEIGHT"
	fi
fi
done

# plotting vectors
if [ -e $U1 ]; then

#echo $self": found "$U1": plotting vectors"
echo $self": Using VECTOR="$VECTOR", STEP="$ADX

# arrowwidth/headlength/headwidth
# grdvector crashes with wrong sampling
#	-Q0.51c/0.8c/0.7cn1.0c \
grdvector $U1 $U2 -K -J${PROJ} -O -R$bds -I$ADX/$ADX \
	-Q0.3c/0.5c/0.4cn1.0c \
	-S$VECTOR -W0.1p/0/0/0 \
	-G255/255/255 \
	 >> $PSFILE
fi

# plot the vector legend if $VECTOR is set
if [ "$VECTOR" != "-" ]; then
UL=`echo $bds | awk -F "/" '{print $1,$4}' `
pstext -O -K -J${PROJ} -N -R$bds \
	-G0/0/0 -Ya0.3i \
	<<EOF >> $PSFILE
$UL 14 0 4 LM $SIZE $unit
EOF
psxy -O -K -J${PROJ} -R$bds -N \
	-W0.5p/0/0/0 -Xa0.9i \
	-Sv0.2c/1.0c/0.4cn1.0c \
	<<EOF >> $PSFILE
$UL 0 1
EOF
REVERT="-Xa-0.9i -Ya-0.3i"
fi

	#-Q0.20c/1.0c/0.4cn1.0c \
psscale -O -B$PSSCALE/:$unit: -D2.0i/-0.8i/3.1i/0.2ih \
	-C$colors $REVERT \
	>> $PSFILE 

rm -f $colors

}

if (test $# -lt "1"); then
        echo "usage: grdmap.sh [-b -5/5/-5/5] [-p -1.5/1.5/0.1] [...] file1.grd ... fileN.grd"
	echo "or"
        echo "       grdmap.sh [-b -5/5/-5/5] [-p -1.5/1.5/0.1] [...] dir1/index1 ... dirN/indexN"
	echo ""
        echo "options:"
        echo "         -b bds sets the map bound to bds"
	echo "         -c palette_name [default my_jet]"
        echo "         -e file.sh runs file.sh to add content to map"
        echo "         -g switch to geographic projection (longitude/latitude)"
	echo "         -i file.grd illuminates the grd image with file.grd"
        echo "         -o output directory"
        echo "         -p palette sets the color scale bounds to palette"
        echo "         -r reverse the y-axis"
        echo "         -s step sets the distance between vectors"
        echo "         -u defines the color scale unit"
        echo "         -v vector sets the vector scale to vector"
	echo "         -t tick interval"
	echo "         -x do not display map (only create .ps file)"
        echo "         -Y shift the plot vertically on the page"
	echo ""
	echo "Creates N maps based on grd files file1.grd ... fileN.grd, or based"
	echo "on files dir1/index1-{up,north.east}.grd ... dirN/indexN-{up,north,east}.grd"
	echo ""
        
        exit
fi

gmtset LABEL_FONT_SIZE 12p
gmtset HEADER_FONT_SIZE 12p
gmtset ANOT_FONT_SIZE 12p 
gmtset COLOR_BACKGROUND 0/0/255
gmtset COLOR_FOREGROUND 255/0/0
gmtset COLOR_NAN 255/255/255
gmtset PAPER_MEDIA a5

libdir=$(dirname $0)
EXTRA=""

while getopts "b:c:e:gi:o:p:v:s:t:u:xrY:" flag
do
  case "$flag" in
    b) bset=1;bds=$OPTARG;;
    c) cset=1;carg=$OPTARG;;
    e) eset=1;EXTRA="$EXTRA $OPTARG";;
    g) gset=1;;
    i) iset=1;illumination="-I$OPTARG";;
    o) oset=1;ODIR=$OPTARG;;
    p) pset=1;P=$OPTARG;PSSCALE=`echo $OPTARG | awk -F"/" 'function abs(x){return x<0?-x:x}{print abs($2-$1)/4}'`;echo $PSSCALE;;
    v) vset=1;SIZE=$OPTARG;VECTOR=$OPTARG"c";;
    r) rset=1;;
    s) sset=1;ADX=$OPTARG;;
    t) tset=1;tick=$OPTARG;;
    u) uset=1;unit=$OPTARG;;
    x) xset=1;;
    Y) Yset=1;Yshift=$OPTARG;;
  esac
done
for item in $bset $cset $iset $oset $pset $vset $sset $tset $uset $Yset $EXTRA;do
	shift;shift
done
for item in $gset $xset $rset;do
	shift;
done

while [ "$#" != "0" ];do

WDIR=`dirname $1`
INDEX=`basename $1`

# default names
U1=$WDIR/$INDEX-east.grd
U2=$WDIR/$INDEX-north.grd
U3=$WDIR/$INDEX-up.grd

if [ -e $U3 ]; then
	U3=$U3;
else
	U3=$WDIR/$INDEX
fi

echo $self": Using directory "$WDIR", plotting index "$INDEX

# defaults
if [ "$bset" != "1" ]; then
	bds=`grdinfo -C $U3 | awk '{s=1;print $2/s"/"$3/s"/"$4/s"/"$5/s}'`
fi
if [ "$tset" != "1" ]; then
	tick=`echo $bds | awk -F "/" '{s=1;print ($2-$1)/s/4}'`
fi
if [ "$gset" != "1" ]; then
	HEIGHT=`echo $bds | awk -F "/" '{printf("%fi\n",($4-$3)/($2-$1)*4)}'`
	if [ "$rset" != "1" ]; then
		PROJ="X4i/"$HEIGHT
	else
		PROJ="X4i/"-$HEIGHT
	fi
        AXIS=-Ba${tick}:"":/a${tick}:""::."$U3":WSne
else
	HEIGHT=4i
	PROJ="M0/0/$HEIGHT"
        AXIS=-B${tick}:"":/${tick}:""::."$U3":WSne
fi

if [ "$uset" != "1" ]; then
	# retrieve the "Remarks"
	# use grdedit -D:=:=:=:=:=:=:cm: file.grd to update the value
	unit=`grdinfo $U3 | grep "Remark" | awk -F ": " '{print $3}'`
fi

if [ "$Yset" != "1" ]; then
	YSHIFT=2.0
else
	YSHIFT=`echo $Yshift | awk '{print $1+2}'`
fi

if [ "$cset" != "1" ]; then
	#cptfile=hot
	cptfile=$libdir/my_jet
	#cptfile=$libdir/my_hot_inv
else
	if [ -e $libdir/$carg ]; then 
		cptfile=$libdir/$carg
	else 
		cptfile=$carg;
	fi
fi

colors=$WDIR/palette.cpt
echo $self: using colorfile $cptfile
if [ "$pset" != "1" ]; then
	# cool, copper, gebco, globe, gray, haxby, hot, jet, no_green, ocean
	# polar, rainbow, red2green, relief, topo, sealand, seis, split, wysiwyg  
	PSSCALE=`grdinfo $U3 -C | awk 'function abs(x){return x<0?-x:x}{if (abs($6) >= abs($7)) print abs($6); else print abs($7)}'`
	if [ "0" == $PSSCALE ]; then
		grd2cpt $U3 -C$cptfile -Z -T= -L-1/1 > $colors
		PSSCALE=0.5
	else
		grd2cpt $U3 -C$cptfile -Z -T= > $colors
	fi
else
	makecpt -C$cptfile -T$P -D > $colors;
fi
if [ "$oset" != "1" ]; then
	ODIR=$WDIR
fi
if [ -e $U1 ]; then
	if [ "$vset" != "1" ]; then
                MAX1=`grdinfo $U1 -C | awk '{if (sqrt($7^2)>sqrt($6^2)){print sqrt($7^2)}else{print sqrt($6^2)}}'`
                MAX2=`grdinfo $U2 -C | awk '{if (sqrt($7^2)>sqrt($6^2)){print sqrt($7^2)}else{print sqrt($6^2)}}'`
		SIZE=`echo "$MAX1 $MAX2"| awk '{if (0==$1 && 0==$2){print 1}else{print ($1+$2)*0.95}}'`
		VECTOR=$SIZE"c"
	fi
	if [ "$sset" != "1" ]; then
		ADX=`grdinfo $U2 -C | awk '{printf "5*%11.9f\n", $8}' | bc`
	fi
else
	# unused value but preserve the number of elements in call to subroutine
	if [ "$vset" != "1" ]; then
		VECTOR="-"
	fi
fi

echo $self": z-min/z-max for "$U3": "`grdinfo -C $U3 | awk '{print $6,$7}'`

PSFILE=$ODIR/$INDEX-plot.ps
PDFFILE=$ODIR/$INDEX-plot.pdf

my_gmt $INDEX

# add trailer information
echo %% Postscript created with >> $PSFILE
echo %% $(basename $0) $cmdline >> $PSFILE

# open file for display
echo $self": Created map "$PSFILE

if [ "$xset" != "1" ]; then
	#display -trim $PSFILE &
	#gv -spartan $PSFILE &
	ps2pdf -sPAPERSIZE="a4" $PSFILE $PDFFILE
	echo $self": Converted to pdf file "$PDFFILE
	xpdf -paper "A5" $PDFFILE -z 100 -g 565x655 >& /dev/null &
fi

shift
if [ "$#" != "0" ];then
	echo ""
fi
done

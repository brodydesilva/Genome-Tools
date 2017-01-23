TARGET_DIR='~/Project2/UCSC/2.1/'
PREFIX='Clostridium_hathewayi'

TOOLS='/share/apps/ngs-ccts/'
BEDOPS=$TOOLS'share/apps/ngs-ccts/BEDOPS/bedops_v2.4.19/bin/'
UCSC='/share/apps/ngs-ccts/ucsc-tools/'

# assume all the information is in the target dir
# assume all files begin with the name of the genome

# Necessary files:
#		.fa
#		.gff
#		.vcf

# create .dict file
java -jar /share/apps/ngs-ccts/picard-tools/picard-tools-1.129/picard.jar CreateSequenceDictionary REFERENCE=$PREFIX'.fa' OUTPUT=$PREFIX'.dict'

# convert fa to bb
$UCSC'faToTwoBit' $PREFIX'.fa' $PREFIX'.2bit'

# create .chrom.sizes file
$UCSC'twoBitInfo' $PREFIX'.2bit' $PREFIX'.chrom.sizes'

# convert gff to bed (no filtering or explicit sorting)
$BEDOPS'convert2bed' -i gff -o bed -d < $PREFIX'.gff' > $PREFIX'.bed'

# convert bed to bb
$UCSC'bedToBigBed' $PREFIX'.bed' $PREFIX'.chrom.sizes' $PREFIX'.bb'

# gzip and tabix index vcf
cp $PREFIX'.vcf' $PREFIX'2.vcf'
bgzip $PREFIX'.vcf'
mv $PREFIX'2.vcf' $PREFIX'.vcf' # ugly workaround for not knowing how to redirect the bgzip -c to a file instead of redirecting the file itself before bgzip.

# tabix index the bgzipped file (for some reason does not modify in place like bgzip)
tabix -p vcf $PREFIX'.vcf.gz'

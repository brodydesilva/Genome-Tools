TARGET_DIR='~/Project2/UCSC/2.1/'
PREFIX='Clostridium_hathewayi'

TOOLS='/share/apps/ngs-ccts/'
BEDOPS=$TOOLS'BEDOPS/bedops_v2.4.19/bin/'
UCSC='/share/apps/ngs-ccts/ucsc-tools/'
BGZIP='/home/bdesilva/software/tabix-0.2.6/bgzip'
TABIX='/home/bdesilva/software/tabix-0.2.6/tabix'

FASTA='.fna'
VCF='.vcf.snp'
GFF='_concat.gff'
DICT='.dict'
TWOBIT='.2bit'
CS='.chrom.sizes'
BB='.bb'
BED='.bed'

# assume all the information is in the target dir
# assume all files begin with the name of the genome

# Necessary files:
#		.fa
#		.gff
#		.vcf

# create .dict file
java -jar /share/apps/ngs-ccts/picard-tools/picard-tools-1.129/picard.jar CreateSequenceDictionary REFERENCE=$PREFIX$FASTA OUTPUT=$PREFIX$DICT

# convert fa to bb
$UCSC'faToTwoBit' $PREFIX$FASTA $PREFIX$TWOBIT

# create .chrom.sizes file
$UCSC'twoBitInfo' $PREFIX$TWOBIT $PREFIX$CS

# convert gff to bed (no filtering or explicit sorting)
$BEDOPS'convert2bed' -i gff -o bed -d < $PREFIX$GFF > $PREFIX$BED

# convert bed to bb
$UCSC'bedToBigBed' $PREFIX$BED $PREFIX$CS $PREFIX$BB

# gzip and tabix index vcf
cp $PREFIX$VCF $PREFIX'2'$VCF
$BGZIP $PREFIX$VCF
mv $PREFIX'2'$VCF $PREFIX$VCF # ugly workaround for not knowing how to redirect the bgzip -c to a file instead of redirecting the file itself before bgzip.

# tabix index the bgzipped file (for some reason does not modify in place like bgzip)
$TABIX -p vcf $PREFIX$VCF'.gz'


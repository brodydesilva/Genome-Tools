# Generate data files for UCSC Track Hub from FASTA and GFF files and create custom track files from a VCF file
# Modify to fit data and tools
TARGET_DIR='/home/bdesilva/Project2/UCSC/2.2/B_v/'
PREFIX=$TARGET_DIR'Bacteroides_vulgatus'
TEMP_FILE='_temp'

# Executables for genomics
TOOLS='/share/apps/ngs-ccts/'
BEDOPS=$TOOLS'BEDOPS/bedops_v2.4.19/bin/'
UCSC=$TOOLS'ucsc-tools/'
BGZIP='/home/bdesilva/software/tabix-0.2.6/bgzip'
TABIX='/home/bdesilva/software/tabix-0.2.6/tabix'
BCFTOOLS='/home/bdesilva/software/bcftools/bin/bcftools'

# File Extensions (must reflect data)
FASTA='.fa'
VCF='.vcf.snp'
GFF='.gff'
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

# fix the non-standard gff starting version
cut -f 1-6 $PREFIX$BED > $PREFIX$TEMP_FILE
mv $PREFIX$TEMP_FILE $PREFIX$BED
awk -v FS='\t' -v OFS='\t' '{if ($5==".") {$5=0} if ($6==".") {$6=0} print $0}' $PREFIX$BED >> $PREFIX$TEMP_FILE # fix the . to 0
mv $PREFIX$TEMP_FILE $PREFIX$BED

# sort bed file
$UCSC'bedSort' $PREFIX$BED $PREFIX$BED
# convert bed to bb
$UCSC'bedToBigBed' -tab $PREFIX$BED $PREFIX$CS $PREFIX$BB

# can make more .bb files (& corresponding trackDb.txt files) that focus specifically on cds and gene (just need to seperate out the bed file)
awk -v FS='\t' -v OFS='\t' '{if ($4~/cds/) {print $0}}' $PREFIX$BED >> $PREFIX'_cds.bed' # grab only cds data
awk -v FS='\t' -v OFS='\t' '{if ($4~/gene/) {print $0}}' $PREFIX$BED >> $PREFIX'_gene.bed' # grab only gene data
$UCSC'bedToBigBed' -tab $PREFIX'_cds.bed' $PREFIX$CS $PREFIX'_cds.bb'
$UCSC'bedToBigBed' -tab $PREFIX'_gene.bed' $PREFIX$CS $PREFIX'_gene.bb'

# split and bgzip the individual files --> output as vcf (not bcf)
# Jorge Amigo https://www.biostars.org/u/375/ for following structure
SSVCF=$PREFIX$VCF
for SAMPLE in `$BCFTOOLS view -h $SSVCF | grep "^#CHROM" | cut -f10-`; do
  $BCFTOOLS view -c1 -Oz -s $SAMPLE -o ${SSVCF/.vcf*/.$SAMPLE'.vcf.gz'} $SSVCF
done


# Create the tabix indexed files
for SAMPLE in $(find $PREFIX.*.vcf.gz); do
	$TABIX $SAMPLE;
done

# add the tracks to the trackDb.txt

# gzip and tabix index vcf
#cp $PREFIX$VCF $PREFIX'2'$VCF
#$BGZIP $PREFIX$VCF
#mv $PREFIX'2'$VCF $PREFIX$VCF # ugly workaround for not knowing how to redirect the bgzip -c to a file instead of redirecting the file itself before bgzip.

# tabix index the bgzipped file (for some reason does not modify in place like bgzip)
#$TABIX -p vcf $PREFIX$VCF'.gz'

#cp $PREFIX$VCF $PREFIX'.vcf'
#mv $PREFIX$VCF'.gz' $PREFIX'.vcf.gz'
#mv $PREFIX$VCF'.gz.tbi' $PREFIX'.vcf.gz.tbi'

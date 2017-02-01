# Usage: change the TARGET_DIR and other variables to accurately reflect your data (mostly paths and file endings)
# scp to the public server from the local drive

TARGET_DIR='/home/bdesilva/Project2/UCSC/5/'
SFX='.fa' # suffix to check for

# Create the description document
DESC=${TARGET_DIR}description.html
printf "<html>\n<body>\n" >> $DESC

for FOLDER in $(basename -s $SFX $(find $TARGET_DIR*$SFX)); do 
	mkdir $TARGET_DIR$FOLDER;
	mv $TARGET_DIR$FOLDER.* $TARGET_DIR$FOLDER/;
	# Generate data files for UCSC Track Hub from FASTA and GFF files and create custom track files from a VCF file
	# Modify to fit data and tools
	PREFIX=$TARGET_DIR$FOLDER/$FOLDER
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
	VCF='.vcf' # NOTE: Can sometimes be .vcf.snp !
	GFF='.gff'
	DICT='.dict'
	TWOBIT='.2bit'
	CS='.chrom.sizes'
	BB='.bb'
	BED='.bed'
	GZ='.gz'
	TBI='.tbi'
	BB_SIZE=6

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
	awk -v FS='\t' -v OFS='\t' '{if ($4~/cds/) {print $0}}' $PREFIX$BED >> ${PREFIX}_cds${BED} # grab only cds data
	awk -v FS='\t' -v OFS='\t' '{if ($4~/gene/) {print $0}}' $PREFIX$BED >> ${PREFIX}_gene${BED} # grab only gene data
	$UCSC'bedToBigBed' -tab ${PREFIX}_cds${BED} ${PREFIX}${CS} ${PREFIX}_cds${BB}
	$UCSC'bedToBigBed' -tab ${PREFIX}_gene${BED} ${PREFIX}${CS} ${PREFIX}_gene${BB}

	# bgzip and tabix index the main vcf file
	cp $PREFIX$VCF ${PREFIX}2${VCF}
	$BGZIP $PREFIX$VCF
	mv $PREFIX'2'$VCF $PREFIX$VCF # ugly workaround for not knowing how to redirect the bgzip -c to a file instead of redirecting the file itself before bgzip.

	# tabix index the bgzipped file (for some reason does not modify in place like bgzip)
	$TABIX -p vcf $PREFIX$VCF$GZ
	
	if [ "$VCF" == ".vcf.snp" ]; then
		cp $PREFIX$VCF $PREFIX$VCF
		mv $PREFIX$VCF$GZ ${PREFIX}.vcf$GZ # only necessary if there is .vcf.snp
		mv $PREFIX$VCF$GZ$TBI ${PREFIX}.vcf$GZ$TBI # only necessary if there is .vcf.snp
	fi

	# split and bgzip the individual files --> output as vcf (not bcf)
	# Jorge Amigo https://www.biostars.org/u/375/ for following structure
	SSVCF=$PREFIX$VCF
	for SAMPLE in `$BCFTOOLS view -h $SSVCF | grep "^#CHROM" | cut -f10-`; do
		$BCFTOOLS view -c1 -Oz -s $SAMPLE -o ${SSVCF/${VCF}*/.$SAMPLE${VCF}${GZ}} $SSVCF
	done

	# Create the tabix indexed files
	for SAMPLE in $(find ${PREFIX}.*${VCF}${GZ}); do
		$TABIX $SAMPLE;
	done
	
	# create the trackDb.txt file and populate with the data from the folders
	TRACK=$TARGET_DIR$FOLDER/trackDb.txt
	# for each of the tabix-indexed filenames, add them to the trackDb.txt
	printf "track cds\n"	>> $TRACK
	printf "bigDataUrl ${FOLDER}_cds${BB}\n" >> $TRACK # hardcoded
	printf "shortLabel CDS\n" >> $TRACK
	printf "longLabel NCBI CDS\n" >> $TRACK
	printf "type bigBed $BB_SIZE\n\n" >> $TRACK

	printf "track gene\n"	>> $TRACK
	printf "bigDataUrl ${FOLDER}_gene${BB}\n" >> $TRACK # hardcoded
	printf "shortLabel Gene\n" >> $TRACK
	printf "longLabel NCBI Gene\n" >> $TRACK
	printf "type bigBed $BB_SIZE\n" >> $TRACK
	printf "visibility pack\n\n" >> $TRACK

	printf "track msvcf\n" >> $TRACK
	printf "bigDataUrl ${FOLDER}${VCF}${GZ}\n" >> $TRACK
	printf "shortLabel MS VCF\n" >> $TRACK
	printf "longLabel MS VCF for $FOLDER from [feature not yet supported] folder.\n" >> $TRACK
	printf "type vcfTabix\n" >> $TRACK
	printf "visibility dense\n\n" >> $TRACK

	for single in	$(find $TARGET_DIR$FOLDER/*.vcf.gz.tbi | awk -F'.' '{print $2}' | grep -v "vcf"); do
		printf "track $single\n" >> $TRACK
		printf "bigDataUrl ${FOLDER}.${single}${VCF}${GZ}\n" >> $TRACK
		printf "shortLabel $single\n" >> $TRACK
	  printf "longLabel ssvcf\n" >> $TRACK
#		printf "longLabel SS VCF for $FOLDER from [feature not yet supported] folder.\n" >> $TRACK
		printf "type vcfTabix\n" >> $TRACK
		printf "visibility dense\n\n" >> $TRACK
	done
	
	# Append the folder name with information to the end of this genomes.txt file
	GENOMES=${TARGET_DIR}genomes.txt
	printf "genome $FOLDER\n" >> $GENOMES
	printf "trackDb ${FOLDER}/trackDb.txt\n" >> $GENOMES
	printf "twoBitPath ${FOLDER}/${FOLDER}${TWOBIT}\n" >> $GENOMES
	printf "description ${FOLDER} metagenome\n" >> $GENOMES
	printf "organism Bacteria\n" >> $GENOMES
	printf "defaultPos ${FOLDER}:1-10000\n" >> $GENOMES
	printf "htmlPath description.html\n\n" >> $GENOMES


	# Add elements to the description.html file
	printf "<h1>${FOLDER}</h1>\n" >> $DESC
done

# Create the hub file
HUB=${TARGET_DIR}hub.txt
printf "hub hub.txt\n" >> $HUB
printf "shortLabel metagenome\n" >> $HUB
printf "longLabel Incorporate msvcf custom track, ssvcf custom tracks (for each sample), Bacteroides_vulgatus genomic info and Clostridium_hathewayi genomic info genomesFile genomes.txt\n" >> $HUB
printf "genomesFile genomes.txt\n" >> $HUB
printf "email bdesilva@uab.edu\n" >> $HUB
printf "descriptionUrl description.html\n" >> $HUB

# Finish the description file
printf "</body>\n</html>\n" >> $DESC

#Usage sh get_genomes_gff.sh allgenomes_annotations_links
# allgenomes_annotations_links has name and URL seperated by tab for all reference genomes to be downloaded

FILE_DIR="raw_files_annotations"
GENOME_DIR="TEMP_DIR"
mkdir $GENOME_DIR
COMB_DIR="comb_genomes2"
mkdir $COMB_DIR
find $FILE_DIR -type f > temp.txt

while read name;
do
	if [ "${name: -3}" == "tgz" ]; then
     		# rename the file (remove the path prefix and file type suffix)
			name=${name: ((${#FILE_DIR} + 1)): -8}
		 	# make the file
			CONCAT=$COMB_DIR/${name}"_concat.gff"
			> $CONCAT
			ANNOT=$COMB_DIR/${name}"_annot.gff"
			> $ANNOT
			echo -e "\nINFO: Extracting genome $name to directory $GENOME_DIR\n"
			mkdir $GENOME_DIR/$name
            tar xf $FILE_DIR/${name}.gff.tgz -C $GENOME_DIR/${name}
			
			# print the concat file line by line substituting the 4th and 5th field with BEGIN and END

			echo -e "\nINFO: Retrieving combined file header information\n"
			# get the header information and add it to the file
			HEADFILE=$(find $GENOME_DIR/${name}/*.gff | head -1)
			HEAD=$(head -3 $HEADFILE)
			# add the header information to the files
			echo "$HEAD" >> "$CONCAT"
			# create the annotation file
			cat $GENOME_DIR/${name}/*.gff | grep '##sequence-region'| cut -d ' ' -f4  >> $ANNOT
			# cat all the files into the combined file
			cat $GENOME_DIR/${name}/*.gff | grep -v '#' >> $CONCAT

			echo -e "\nINFO: Refactoring the genome $name to a combined number format\n"	
			# raster through the file,  set first line of each file to be the region range
			count=0 # line number
			count2=0 # file number (each time hit the delimiter of region with a tab increment)
			SIZE=$(wc -l $CONCAT | awk '{print $1}' ) # number of files
			NUM=0 # the number to be added to the other region starts for each genome
			DELIM="region"$'\t'"1"$'\t'

			while read line; do
				# check if line is new region
				if [[ "$line" == *"$DELIM"* ]]; then
					if (($count2 == 0)); then
						NUM=0
					else
						# grab the range end from the line (given by count2) of the annot file
						NUM=$(($(sed "${count2}q;d" $ANNOT) + $NUM))
					fi
						END=$(echo "$line" | awk -v var=$NUM '{print $5+var}') # the 5th column is the end data
						BEGIN=$(echo "$line" | awk -v var=$NUM '{print $4+var}') # the 4th column is the begin data
						echo "$line" | awk -v name="$name" -v var="$BEGIN" -v var2="$END" -v FS='\t' -v OFS='\t' '{$1=name;$4=var;$5=var2; print $0}' >> ${CONCAT}.tmp
						((count2++))
				else
					END=$(echo "$line" | awk -v var=$NUM '{print $5+var}') # the 5th column is the end data
					BEGIN=$(echo "$line" | awk -v var=$NUM '{print $4+var}') # the 4th column is the begin data
					if [[ "$(echo $line | head -c 1)" != "#" ]]; then # if not the header line (first 3 lines or so)
						echo "$line" | awk -v name="$name" -v var="$BEGIN" -v var2="$END" -v FS='\t' -v OFS='\t' '{$1=name;$4=var;$5=var2; print $0}' >> ${CONCAT}.tmp
					else # if is a header line just print the line
						echo "$line" >> ${CONCAT}.tmp
					fi
				fi
			done < $CONCAT
			mv ${CONCAT}.tmp ${CONCAT}
	else

			# rename the file (remove the path prefix and file type suffix)
			name=${name: ((${#FILE_DIR}+ 1)): -4}

			# make the file
			CONCAT=$COMB_DIR/${name}"_concat.gff"
			> $CONCAT
			ANNOT=$COMB_DIR/${name}"_annot.gff"
			> $ANNOT

			echo -e "\nINFO: Retrieving combined file header information\n"
			# get the header information and add it to the file
			HEADFILE=$(find $FILE_DIR/${name}.gff | head -1)
			HEAD=$(head -3 $HEADFILE)
			# add the header information to the files
			echo "$HEAD" >> "$CONCAT"
			# create the annotation file
			cat $FILE_DIR/${name}.gff | grep '##sequence-region'| cut -d ' ' -f4  >> $ANNOT
			# cat all the files into the combined file
			cat $FILE_DIR/${name}.gff | grep -v '#' >> $CONCAT

			# replace the first column with the name of the file
			while read line; do
				if [[ "$(echo $line | head -c 1)" != "#" ]]; then # if is a header line, then 
					echo "$line" | awk -v name="$name" -v FS='\t' -v OFS='\t' '{$1=name; print $0}' >> ${CONCAT}.tmp
				else
					echo "$line" >> ${CONCAT}.tmp
				fi
			done < $CONCAT
			mv ${CONCAT}.tmp ${CONCAT}
	fi
done < temp.txt 

echo -e "\nINFO: Cleaning everything\n"

sleep 1
echo -e "\nINFO: Removing the extracted folders, temporary annotation files, and temp.txt\n"
rm -r $GENOME_DIR
rm temp.txt
rm ${COMB_DIR}/*annot.gff

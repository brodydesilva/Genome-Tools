

REF='../genomes_ref.fa'
OUT='../FASTA_2'
echo $OUT
while read line; do
	if [ "${line:0:1}" == ">" ]; then
		if [ -n ${file+x}]; then
			fasta_formatter -i $file -o tempref.txt -w 70
			mv tempref.txt $file
		fi
		file=${OUT}/${line:1}.fna
		echo $file
		> $file
		echo $line >> $file
	else
		echo $line >> $file
	fi
done < $REF

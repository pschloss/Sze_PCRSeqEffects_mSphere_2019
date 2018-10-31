REFS = data/references
FIGS = results/figures
TABLES = results/tables
PROC = data/process
FINAL = submission/

# utility function to print various variables. For example, running the
# following at the command line:
#
#	make print-BAM
#
# will generate:
#	BAM=data/raw_june/V1V3_0001.bam data/raw_june/V1V3_0002.bam ...
print-%:
	@echo '$*=$($*)'


################################################################################
#
# Part 1: Get the references
#
# We will need several reference files to complete the analyses including the
# SILVA reference alignment and RDP reference taxonomy. Note that this code
# assumes that mothur is in your PATH. If not (e.g. it's in code/mothur/, you
# will need to replace `mothur` with `code/mothur/mothur` throughout the
# following code.
#
################################################################################

# We want the latest greatest reference alignment and the SILVA reference
# alignment is the best reference alignment on the market. This version is from
# 132 and described at http://blog.mothur.org/2018/01/10/SILVA-v132-reference-files/
# We will use the SEED v. 132, which contain 12,083 bacterial sequences. This
# also contains the reference taxonomy. We will limit the databases to only
# include bacterial sequences.

$(REFS)/silva.seed.align :
	wget -N https://mothur.org/w/images/7/71/Silva.seed_v132.tgz
	tar xvzf Silva.seed_v132.tgz silva.seed_v132.align silva.seed_v132.tax
	mothur "#get.lineage(fasta=silva.seed_v132.align, taxonomy=silva.seed_v132.tax, taxon=Bacteria)"
	mv silva.seed_v132.pick.align $(REFS)/silva.seed.align
	mothur "#get.seqs(fasta=silva.seed_v132.align, accnos=$(REFS)/euks.accnos)"
	cat silva.seed_v132.pick.align >> $(REFS)/silva.seed.align
	rm Silva.seed_v132.tgz silva.seed_v132.*

$(REFS)/silva.v4.align : $(REFS)/silva.seed.align
	mothur "#pcr.seqs(fasta=$(REFS)/silva.seed.align, start=11894, end=25319, keepdots=F, processors=8)"
	mv $(REFS)/silva.seed.pcr.align $(REFS)/silva.v4.align

# Next, we want the RDP reference taxonomy. The current version is v10 and we
# use a "special" pds version of the database files, which are described at
# http://blog.mothur.org/2017/03/15/RDP-v16-reference_files/

$(REFS)/trainset16_022016.% :
	wget -N https://www.mothur.org/w/images/c/c3/Trainset16_022016.pds.tgz
	tar xvzf Trainset16_022016.pds.tgz trainset16_022016.pds
	mv trainset16_022016.pds/* $(REFS)/
	rm -rf trainset16_022016.pds
	rm Trainset16_022016.pds.tgz

# We need to get the Zymo mock community data
$(REFS)/zymo_mock.align : $(REFS)/silva.v4.align
	wget -N https://s3.amazonaws.com/zymo-files/BioPool/ZymoBIOMICS.STD.refseq.v2.zip
	unzip ZymoBIOMICS.STD.refseq.v2.zip
	rm ZymoBIOMICS.STD.refseq.v2/ssrRNAs/*itochondria_ssrRNA.fasta #V4 primers don't come close to annealing to these
	cat ZymoBIOMICS.STD.refseq.v2/ssrRNAs/*fasta > zymo.fasta
	mothur "#align.seqs(fasta=zymo.fasta, reference=data/references/silva.v4.align, processors=12)"
	mv zymo.align data/references/zymo_mock.align
	rm -rf zymo.* ZymoBIOMICS.STD.refseq.v2*

################################################################################
#
# Part 2: Get and run data through mothur
#
#	Process fastq data through the generation of files that will be used in the
# overall analysis.
#
################################################################################

# here we take the raw fastq files for all of the files and process them through the generation of
# a shared file. we stop at different stages where files are needed for splitting off the mock
# community data from the stool data

# Run stool sequences from make.contigs through make.shared
data/mothur/stool.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.opti_mcc.shared:\
			code/get_shared_stool.batch\
			data/references/silva.v4.align\
			data/references/trainset16_022016.pds.fasta\
			data/references/trainset16_022016.pds.tax\
			data/raw/stool.files
	mothur code/get_shared_stool.batch
	rm data/mothur/stool*map



# make.contigs; screen.seqs; unique; align (w/mock); filter; unique; classify.seqs; remove contaminants

data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.fasta data/mothur/mock.trim.contigs.good.unique.good.filter.pick.count_table $(REFS)/zymo_mock.filter.fasta:\
			code/get_good_mock.batch\
			data/references/silva.v4.align\
			$(REFS)/zymo_mock.align\
			data/references/trainset16_022016.pds.fasta\
			data/references/trainset16_022016.pds.tax\
			data/raw/mock.files
	mothur code/get_good_mock.batch


# error.seqs
data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.error.summary:\
			data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.fasta\
			data/mothur/mock.trim.contigs.good.unique.good.filter.pick.count_table\
			data/mothur/zymo_mock.filter.fasta
	mothur "#seq.error(fasta=data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.fasta, count=data/mothur/mock.trim.contigs.good.unique.good.filter.pick.count_table, reference=data/mothur/zymo_mock.filter.fasta, aligned=T)"


#need to remove those sequences that are more than 20 away from a reference
data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.fasta data/mothur/mock.trim.contigs.good.unique.good.filter.pick.pick.count_table : \
			data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.fasta\
			data/mothur/mock.trim.contigs.good.unique.good.filter.pick.count_table\
			data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.error.summary\
			code/remove_contaminants.R
	Rscript code/remove_contaminants.R


# precluster
data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.fasta data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.count_table:\
			code/run_precluster_mock.batch\
			data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.fasta\
			data/mothur/mock.trim.contigs.good.unique.good.filter.pick.pick.count_table
	mothur code/run_precluster_mock.batch
	rm data/mothur/mock*map


# error.seqs
data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.error.summary:\
			data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.fasta\
			data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.count_table\
			data/mothur/zymo_mock.filter.fasta
	mothur "#seq.error(fasta=data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.fasta, count=data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.count_table, reference=data/mothur/zymo_mock.filter.fasta, aligned=T)"


# chimera.vsearch
data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.vsearch.fasta data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.vsearch.count_table:\
			code/run_vchime_mock.batch\
			data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.fasta\
			data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.count_table
	mothur code/run_vchime_mock.batch
	mv data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.pick.fasta data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.vsearch.fasta
	mv data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.denovo.vsearch.pick.count_table data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.vsearch.count_table


# dist.seqs; cluster based on chimera.vsearch output
data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.vsearch.opti_mcc.shared :\
		code/get_vsearch_shared_mock.batch\
		data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.vsearch.fasta\
		data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.vsearch.count_table
	mothur code/get_vsearch_shared_mock.batch


# perfect chimera removal
data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.perfect.fasta data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.perfect.count_table : \
		code/perfect_chimera_removal.R\
		data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.error.summary\
		data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.fasta\
		data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.count_table
	Rscript code/perfect_chimera_removal.R


# dist.seqs; cluster based on perfect chimera removal
data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.perfect.opti_mcc.shared :\
		code/get_perfect_shared_mock.batch\
		data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.perfect.fasta\
		data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.perfect.count_table
	mothur code/get_perfect_shared_mock.batch


# No sequencing errors
data/mothur/zymo_mock.filter.pick.unique.precluster.opti_mcc.summary : \
		code/no_sequence_errors.batch\
		data/mothur/zymo_mock.filter.fasta
	grep "18S" data/mothur/zymo_mock.filter.fasta | cut -c2- > data/mothur/18S.accnos
	mothur code/no_sequence_errors.batch


################################################################################
#
# Part 3: Figure and table generation
#
#	Run scripts to generate figures and tables
#
################################################################################

data/process/error_chimera_rates.tsv : code/error_chimera_analysis.R\
		data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.error.summary\
		data/mothur/mock.trim.contigs.good.unique.good.filter.pick.count_table\
		data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.error.summary\
		data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.count_table\
		data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.vsearch.count_table
	Rscript code/error_chimera_analysis.R


################################################################################
#
# Part 4: Pull it all together
#
# Render the manuscript
#
################################################################################


$(FINAL)/manuscript.% : 			\ #include data files that are needed for paper don't leave this line with a : \
						$(FINAL)/mbio.csl\
						$(FINAL)/references.bib\
						$(FINAL)/manuscript.Rmd
	R -e 'render("$(FINAL)/manuscript.Rmd", clean=FALSE)'
	mv $(FINAL)/manuscript.knit.md submission/manuscript.md
	rm $(FINAL)/manuscript.utf8.md


write.paper : $(TABLES)/table_1.pdf $(TABLES)/table_2.pdf\ #customize to include
				$(FIGS)/figure_1.pdf $(FIGS)/figure_2.pdf\	# appropriate tables and
				$(FIGS)/figure_3.pdf $(FIGS)/figure_4.pdf\	# figures
				$(FINAL)/manuscript.Rmd $(FINAL)/manuscript.md\
				$(FINAL)/manuscript.tex $(FINAL)/manuscript.pdf

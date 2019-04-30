library(tidyverse)

# Points we can make...
# * Chimeras are not random
#	* Polymerases doesn't influence the specific chimeras that are generated
# * Chimeras can be relatively abundant


set.seed(19760620) #PDS's birthday

# unroll the frequency distribution of chimeras, subsample, and roll back up into a data frame
# column
get_subsample <- function(x, min_chimeras=10000) {
	count(sample_n(tibble(sequences=rep(x$sequences, x$count)), min_chimeras), sequences)
}

# Read in the preclustered count table
count_table <- read_tsv("data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.count_table") %>%
	rename(sequences=Representative_Sequence) %>%
	select(-total)

# Read in the seq.error analysis of the preclustered data
chimeric_sequences <- read_tsv("data/mothur/mock.trim.contigs.good.unique.good.filter.unique.pick.pick.precluster.error.summary") %>%
	filter(numparents == 2) %>%
	pull(query)


# Count the number of chimeras in each sample for the 35 cycle case (most extreme)
n_chimeras <- count_table %>%
	filter(sequences %in% chimeric_sequences) %>%
	gather(-sequences, key="sample", value="count") %>%
	mutate(sample=str_replace(sample, "_Mock_DNA\\d", "")) %>%
	group_by(sample, sequences) %>%
	summarize(count = sum(count)) %>%
	ungroup() %>%
	filter(count != 0, str_detect(sample, "35x")) %>%
	group_by(sample) %>%
	summarize(total = sum(count))


# Find the subsample threshold to use when we've excluded the Kapa data
bottom_threshold <- n_chimeras %>% filter(sample != "35x_K") %>% pull(total) %>% min()


# Count the frequency of each chimera per polymerase
chimera_counts_by_group <- count_table %>%
	filter(sequences %in% chimeric_sequences) %>%
	gather(-sequences, key="sample", value="count") %>%
	mutate(sample=str_replace(sample, "_Mock_DNA\\d", "")) %>%
	group_by(sample, sequences) %>%
	summarize(count = sum(count)) %>%
	ungroup() %>%
	filter(count != 0, str_detect(sample, "35x"))


# Subsample to the smallest polymerase type (excluding Kapa)
sub_sample_counts_by_group <- chimera_counts_by_group %>%
	filter(sample != "35x_K") %>%
	group_by(sample) %>%
	nest() %>%
	mutate(subsample = map(data, ~get_subsample(., bottom_threshold))) %>%
	select(sample, subsample) %>%
	unnest(subsample)


# Count the number of sequence that overlap 1, 2, 3, or 4 polymerase datasets
sequence_overlap_counts <- sub_sample_counts_by_group %>%
	group_by(sequences) %>%
	summarize(n_overlaps=n()) %>% arrange(desc(n_overlaps))


# Determine what fraction of the chimeric sequences are represented in each overlap class
overlap_density <- sequence_overlap_counts %>%
	inner_join(., sub_sample_counts_by_group, by="sequences") %>%
	group_by(n_overlaps, sample) %>%
	summarize(fraction = sum(n)/bottom_threshold)


# Get the number of chimeras that showed up in the Kapa class
n_kappa_chimeras <- n_chimeras %>% filter(sample=="35x_K") %>% pull(total)


# Determine the fraction of the Kapa chimeras show up in each of these classes
kappa_overlap <- inner_join(sequence_overlap_counts, chimera_counts_by_group) %>%
	filter(sample == "35x_K") %>%
	group_by(n_overlaps) %>%
	summarize(fraction=sum(count)/n_kappa_chimeras) %>%
	mutate(sample = "35x_K")


# Combine the density data for the four polymerases with the Kapa data and ouput
bind_rows(overlap_density, kappa_overlap) %>%
	arrange(n_overlaps, sample) %>%
	write_tsv("data/process/chimera_overlap_density.tsv")


# Output the frequency distribution of chimeras that were found across each polymerase
sequence_overlap_counts %>%
	count(n_overlaps) %>%
	write_tsv("data/process/chimera_overlap_frequency.tsv")

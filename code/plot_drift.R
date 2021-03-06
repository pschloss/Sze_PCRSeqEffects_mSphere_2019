library(tidyverse)
library(cowplot)
library(RColorBrewer)

polymerase_colors <- brewer.pal(5, "RdBu")
polymerase_colors[3] <- "darkgray"


labels <- c('mock' = 'Mean intra-replicate Bray-Curtis\ndistances for the mock community',
						'stool' = 'Mean inter-sample Bray-Curtis\ndistances for the stool samples')

mock <- read_csv("data/process/mock_beta_drift.csv") %>%
	filter(method == "vsearch") %>%
	select(-method) %>%
	mutate(data="mock")

stool <- read_tsv("data/process/stool_beta_diversity.tsv") %>%
	separate(rows, into=c("rounds", "polymerase", "row_subject")) %>%
	separate(columns, into=c("col_rounds", "col_polymerase", "col_subject")) %>%
	filter(rounds == col_rounds, polymerase == col_polymerase) %>%
	select(rounds, polymerase, row_subject, col_subject, distances) %>%
	group_by(rounds, polymerase) %>%
	summarize(ave_dist = mean(distances), n = n()) %>%
	ungroup() %>%
	filter(n == 6) %>%
	mutate(rounds = as.numeric(str_replace(rounds, "x", ""))) %>%
	select(-n) %>%
	mutate(data="stool")

bind_rows(mock, stool) %>%
	ggplot(aes(x=rounds, y=ave_dist, color=polymerase)) +
		geom_line(size=1) +
		facet_wrap(.~data, strip.position='left', scal="free_y", labeller=as_labeller(labels)) +
		coord_cartesian(ylim=c(0,0.6)) +
		scale_color_manual(name=NULL,
												breaks=c("ACC", "K", "PHU", "PL", "Q5"),
												labels=c("Accuprime", "KAPA", "Phusion", "Platinum", "Q5"),
												values=polymerase_colors) +
		labs(y=NULL, x="Number of rounds of PCR") +
		theme_classic() +
		theme(
			strip.background = element_blank(),
			strip.placement="outside",
			strip.text=element_text(size=11),
			legend.key.height = unit(0.8, "line")
		)

ggsave("results/figures/drift.pdf", width=6.5, height=3)

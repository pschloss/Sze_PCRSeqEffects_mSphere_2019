library(tidyverse)
library(RColorBrewer)

polymerase_colors <- brewer.pal(5, "RdBu")
polymerase_colors[3] <- "darkgray"

facet_names <- c(
									'contig_error' = "Raw contigs",
									'pc_error' = "Denoised contigs"
								)

read_tsv("data/process/error_chimera_rates.tsv") %>%
	gather(stage, error_rate, contig_error, pc_error) %>%
	mutate(error_rate = 100 * error_rate) %>%
	ggplot(aes(x=rounds, y=error_rate, color=polymerase)) +
		geom_line(size=1) +
		facet_wrap(.~stage, scales="free_y", labeller = as_labeller(facet_names)) +
		labs(y="Error rate (%)", x="Number of rounds of PCR") +
		scale_color_manual(name=NULL,
												breaks=c("ACC", "K", "PHU", "PL", "Q5"),
												labels=c("Accuprime", "KAPA", "Phusion", "Platinum", "Q5"),
												values=polymerase_colors) +
		theme_classic() +
		theme(
			panel.spacing=unit(0.5,"cm"),
			strip.background = element_blank(),
			legend.key.height = unit(0.8, "line")
		)
		ggsave('results/figures/mock_error.pdf', width=6, height=3, units="in")

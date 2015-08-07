# load package
library(phyloseq)

# set directory to where the data is located
setwd("<path_to_data>")

# import data
data.otu <- otu_table(read.table("utax_otu_table.txt"), taxa_are_rows=T) # community file
data.tax <- tax_table(as.matrix(read.table("utax_tax_table.txt", fill=T, header=T, sep="\t", row.names=1))) # taxonomy table
data.map <- import_qiime_sample_data("mapfile.tsv") # sample metadata

# create combined phyloseq object
data <- merge_phyloseq(data.otu, data.tax, data.map)

# relativize
data.rel = transform_sample_counts(data, function(x) x/sum(x))

# filtering low abundance taxa, recommended to minimize sequencing artefacts
otu_table(data)[otu_table(data.rel)<0.001]<-0
otu_table(data.rel)[otu_table(data.rel)<0.001]<-0 
data = prune_taxa(taxa_sums(data)>0, data)
data = prune_taxa(taxa_sums(data)>0, data)

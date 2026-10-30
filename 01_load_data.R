# 1. Download the French motor dataset (freMTPL2) from the CASdatasets GitHub
url_freq <- "https://github.com/dutangc/CASdatasets/raw/c49cbbb37235fc49616cac8ccac32e1491cdc619/data/freMTPL2freq.rda"
download.file(url_freq, destfile = "freMTPL2freq.rda", mode = "wb")

# 2. Load it into R
load("freMTPL2freq.rda")

# 3. First look at the data
head(freMTPL2freq)        # first 6 rows
str(freMTPL2freq)         # column names and types
nrow(freMTPL2freq)        # number of policies

# 4. Basic actuarial numbers
table(freMTPL2freq$ClaimNb)                                # how many policies have 0, 1, 2... claims
sum(freMTPL2freq$ClaimNb) / sum(freMTPL2freq$Exposure)     # overall claim frequency per policy-year

# How to look at the table
# View(freMTPL2freq)

# Find the percentage of no claim
mean(freMTPL2freq$ClaimNb == 0)

summary(freMTPL2freq$Exposure)
sum(freMTPL2freq$ClaimNb) / nrow(freMTPL2freq)          # divide by number of policies
sum(freMTPL2freq$ClaimNb) / sum(freMTPL2freq$Exposure)  # divide by exposure

# install.packages(c("dplyr", "ggplot2"))   # run once if not installed
library(dplyr)
library(ggplot2)

# 1. Load the raw data
load("freMTPL2freq.rda")
dat <- freMTPL2freq

# 2. How many records are unusual?
sum(dat$ClaimNb > 4)      # policies with more than 4 claims
sum(dat$Exposure > 1)     # policies with exposure above 1 year

# 3. Clean the data
dat$ClaimNb  <- pmin(as.numeric(dat$ClaimNb), 4)   # cap claims at 4
dat$Exposure <- pmin(dat$Exposure, 1)              # cap exposure at 1 year
dat$VehGas   <- factor(dat$VehGas)                 # text -> category

# 4. Check the result
table(dat$ClaimNb)
summary(dat$Exposure)
overall_freq <- sum(dat$ClaimNb) / sum(dat$Exposure)
overall_freq

# 5. Claim frequency by driver age band
dat$DrivAgeBand <- cut(dat$DrivAge, breaks = c(17, 20, 25, 30, 40, 50, 60, 70, 100))

freq_by_age <- dat |>
  group_by(DrivAgeBand) |>
  summarise(claims   = sum(ClaimNb),
            exposure = sum(Exposure),
            freq     = claims / exposure)
freq_by_age

# 6. Plot it
ggplot(freq_by_age, aes(x = DrivAgeBand, y = freq)) +
  geom_col(fill = "steelblue") +
  geom_hline(yintercept = overall_freq, linetype = "dashed") +
  labs(title = "Claim frequency by driver age",
       x = "Driver age", y = "Claims per policy-year")

# 7. Save the plot and the cleaned data
dir.create("plots", showWarnings = FALSE)
ggsave("plots/freq_by_driver_age.png", width = 7, height = 4)
saveRDS(dat, "dat_clean.rds")
library(dplyr)
library(ggplot2)

# 1. Load the cleaned data from Day 2
dat <- readRDS("dat_clean.rds")
overall_freq <- sum(dat$ClaimNb) / sum(dat$Exposure)

# 2. A reusable function: frequency table + plot for any variable
plot_freq <- function(data, var) {
  tab <- data |>
    group_by(.data[[var]]) |>
    summarise(claims   = sum(ClaimNb),
              exposure = sum(Exposure),
              freq     = claims / exposure)
  print(tab)
  
  p <- ggplot(tab, aes(x = .data[[var]], y = freq)) +
    geom_col(fill = "steelblue") +
    geom_hline(yintercept = overall_freq, linetype = "dashed") +
    labs(title = paste("Claim frequency by", var),
         x = var, y = "Claims per policy-year")
  print(p)
  ggsave(paste0("plots/freq_by_", var, ".png"), plot = p, width = 7, height = 4)
}

# 3. Group the numeric variables into bands
dat$VehAgeBand     <- cut(dat$VehAge, breaks = c(-1, 0, 2, 5, 10, 15, 100))
dat$BonusMalusBand <- cut(dat$BonusMalus, breaks = c(49, 50, 60, 70, 80, 100, 150, 250))
dat$VehPowerGrp    <- factor(pmin(dat$VehPower, 9))   # 9 means "9 or more"

# 4. Use the function
plot_freq(dat, "BonusMalusBand")
plot_freq(dat, "VehAgeBand")
plot_freq(dat, "VehPowerGrp")
plot_freq(dat, "VehGas")

# 5. Area vs Density: are they measuring the same thing?
dat |>
  group_by(Area) |>
  summarise(median_density = median(Density))

# 6. Save the data with the new bands
saveRDS(dat, "dat_clean.rds")

#Check Assumptions
dat |>
  group_by(VehAgeBand) |>
  summarise(mean_driver_age = mean(DrivAge),
            mean_bonusmalus = mean(BonusMalus),
            mean_exposure   = mean(Exposure),
            total_exposure  = sum(Exposure))

dat$ExpBand <- cut(dat$Exposure, breaks = c(0, 0.25, 0.5, 0.75, 1))
plot_freq(dat, "ExpBand")

plot_freq(dat, "VehBrand")
plot_freq(dat, "Region")

dat |>
  group_by(VehBrand) |>
  summarise(share_new_car = mean(VehAge == 0),
            mean_exposure = mean(Exposure))
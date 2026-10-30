library(dplyr)

# 1. Load the data from Day 3 (with all the bands)
dat <- readRDS("dat_clean.rds")

# 2. Set the reference level of each factor = the group with the most exposure
set_ref <- function(x, w) {
  base <- names(which.max(tapply(w, x, sum)))
  relevel(x, ref = base)
}

factors <- c("DrivAgeBand", "BonusMalusBand", "VehAgeBand", "VehPowerGrp",
             "VehGas", "VehBrand", "Area", "Region")
for (f in factors) {
  dat[[f]] <- set_ref(dat[[f]], dat$Exposure)
}

# 3. Split into training data (80%) and test data (20%)
set.seed(2026)
idx   <- sample(nrow(dat), size = round(0.8 * nrow(dat)))
train <- dat[idx, ]
test  <- dat[-idx, ]

# 4. Fit the Poisson GLM
freq_glm <- glm(ClaimNb ~ DrivAgeBand + BonusMalusBand + VehAgeBand + VehPowerGrp +
                  VehGas + VehBrand + Area + Region + offset(log(Exposure)),
                family = poisson(link = "log"),
                data = train)
summary(freq_glm)

# 5. Convert coefficients into relativities
rel <- data.frame(relativity = round(exp(coef(freq_glm)), 3))
rel

# 6. Save for the next days
saveRDS(freq_glm, "freq_glm.rds")
saveRDS(train, "train.rds")
saveRDS(test,  "test.rds")

levels(train$DrivAgeBand)[1]     # which age band is the base?

dat |>
  group_by(DrivAgeBand) |>
  summarise(freq    = sum(ClaimNb) / sum(Exposure),
            mean_bm = mean(BonusMalus))

#Check base of relativity
levels(train$VehAgeBand)[1]
levels(train$VehBrand)[1]

sapply(train[factors], function(x) levels(x)[1])

train |>
  filter(DrivAgeBand == "(17,20]", BonusMalusBand == "(100,150]", Area == "F") |>
  summarise(policies = n(),
            exposure = sum(Exposure),
            actual_freq = sum(ClaimNb) / sum(Exposure))
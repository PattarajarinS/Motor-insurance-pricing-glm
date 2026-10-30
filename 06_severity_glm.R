library(dplyr)

train <- readRDS("train.rds")

# 1. Download the claim amounts (one row per claim)
url_sev <- "https://github.com/dutangc/CASdatasets/raw/c49cbbb37235fc49616cac8ccac32e1491cdc619/data/freMTPL2sev.rda"
download.file(url_sev, destfile = "freMTPL2sev.rda", mode = "wb")
load("freMTPL2sev.rda")

# 2. First look at claim amounts
nrow(freMTPL2sev)
summary(freMTPL2sev$ClaimAmount)
quantile(freMTPL2sev$ClaimAmount, c(0.5, 0.9, 0.99, 0.995, 0.999))

# 3. Cap large claims at the 99.5th percentile
cap_sev <- quantile(freMTPL2sev$ClaimAmount, 0.995)
cap_sev

sev <- freMTPL2sev |>
  mutate(ClaimCapped = pmin(ClaimAmount, cap_sev))

large_loading <- sum(sev$ClaimAmount) / sum(sev$ClaimCapped)
large_loading

# 4. One row per policy: number of claims and average capped claim
sev_pol <- sev |>
  group_by(IDpol) |>
  summarise(n_claims     = n(),
            total_capped = sum(ClaimCapped)) |>
  mutate(avg_claim = total_capped / n_claims)

# 5. Keep only training policies (same split as the frequency model)
sev_train <- train |>
  inner_join(sev_pol, by = "IDpol")
nrow(sev_train)
sum(sev_train$n_claims)

# 6. Quick one-way check: average claim by area
sev_train |>
  group_by(Area) |>
  summarise(claims   = sum(n_claims),
            avg_cost = sum(total_capped) / sum(n_claims))

# 7. Gamma GLM for severity
sev_glm <- glm(avg_claim ~ DrivAgeBand + BonusMalusBand + VehAgeBand + VehPowerGrp +
                 VehGas + VehBrand + Area + Region,
               family  = Gamma(link = "log"),
               weights = n_claims,
               data    = sev_train,
               control = glm.control(maxit = 100))
summary(sev_glm)
drop1(sev_glm, test = "F")
round(exp(coef(sev_glm)), 3)

# 8. Save
saveRDS(sev_glm, "sev_glm.rds")
saveRDS(sev_pol, "sev_pol.rds")
saveRDS(list(cap = cap_sev, loading = large_loading), "large_claims.rds")
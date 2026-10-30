library(dplyr)

# 1. Load the model and data from Day 4
freq_glm <- readRDS("freq_glm.rds")
train    <- readRDS("train.rds")

# 2. Likelihood ratio test: does each factor improve the model?
#    (this refits the model 8 times, may take 1-3 minutes)
drop1(freq_glm, test = "Chisq")

# 3. Alternative model: exposure as a variable instead of an offset
freq_glm2 <- glm(ClaimNb ~ DrivAgeBand + BonusMalusBand + VehAgeBand + VehPowerGrp +
                   VehGas + VehBrand + Area + Region + log(Exposure),
                 family = poisson(link = "log"),
                 data = train)

coef(freq_glm2)["log(Exposure)"]

# 4. Compare the two models
AIC(freq_glm, freq_glm2)

common  <- intersect(names(coef(freq_glm)), names(coef(freq_glm2)))
compare <- data.frame(model1_offset   = round(exp(coef(freq_glm)[common]), 3),
                      model2_variable = round(exp(coef(freq_glm2)[common]), 3))
compare

# 5. Save the second model
saveRDS(freq_glm2, "freq_glm2.rds")
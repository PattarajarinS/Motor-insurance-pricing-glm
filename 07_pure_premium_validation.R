library(dplyr)
library(ggplot2)

# 1. Load everything
test      <- readRDS("test.rds")
freq_glm  <- readRDS("freq_glm.rds")    # offset model (benchmark)
freq_glm2 <- readRDS("freq_glm2.rds")   # exposure-as-covariate model (main)
sev_glm   <- readRDS("sev_glm.rds")     # reduced severity model
lc        <- readRDS("large_claims.rds")

# 2. Actual claim costs per test policy (uncapped, real euros)
load("freMTPL2sev.rda")
actual_pol <- freMTPL2sev |>
  group_by(IDpol) |>
  summarise(actual_cost = sum(ClaimAmount))

test <- test |>
  left_join(actual_pol, by = "IDpol") |>
  mutate(actual_cost = coalesce(actual_cost, 0))

# 3. Predictions
test$sev_pred    <- predict(sev_glm, newdata = test, type = "response") * lc$loading
test$freq_period <- predict(freq_glm2, newdata = test, type = "response")

test_annual          <- test
test_annual$Exposure <- 1
test$freq_annual     <- predict(freq_glm2, newdata = test_annual, type = "response")

test$pure_premium  <- test$freq_annual * test$sev_pred    # annual premium
test$expected_cost <- test$freq_period * test$sev_pred    # cost over actual exposure

# 4. Overall check
summary(test$pure_premium)
sum(test$expected_cost) / sum(test$actual_cost)

# 5. Which frequency model predicts better on new data?
pois_dev <- function(y, mu) 2 * sum(ifelse(y == 0, 0, y * log(y / mu)) - (y - mu))
pois_dev(test$ClaimNb, predict(freq_glm, newdata = test, type = "response"))
pois_dev(test$ClaimNb, test$freq_period)

# 6. Lift chart
lift <- test |>
  mutate(decile = ntile(pure_premium, 10)) |>
  group_by(decile) |>
  summarise(exposure  = sum(Exposure),
            predicted = sum(expected_cost) / sum(Exposure),
            actual    = sum(actual_cost) / sum(Exposure))
lift

ggplot(lift, aes(x = decile)) +
  geom_line(aes(y = predicted, colour = "Predicted")) +
  geom_point(aes(y = predicted, colour = "Predicted")) +
  geom_line(aes(y = actual, colour = "Actual")) +
  geom_point(aes(y = actual, colour = "Actual")) +
  scale_x_continuous(breaks = 1:10) +
  labs(title = "Lift chart: predicted vs actual loss cost (test data)",
       x = "Decile of predicted pure premium (1 = lowest risk)",
       y = "Loss cost per policy-year (EUR)", colour = NULL)
ggsave("plots/lift_chart.png", width = 7, height = 4)

lift$actual[10] / lift$actual[1]

# 7. Save
saveRDS(test, "test_scored.rds")

test |>
  arrange(desc(pure_premium)) |>
  select(DrivAgeBand, BonusMalusBand, VehAgeBand, Area, pure_premium) |>
  head(5)

sum(test$expected_cost) / sum(test$actual_cost)

# Whole dataset: claims in policy data vs claims with amounts
sum(readRDS("dat_clean.rds")$ClaimNb)
nrow(freMTPL2sev)

# Test set only
sum(test$ClaimNb)
sum(freMTPL2sev$IDpol %in% test$IDpol)

train <- readRDS("train.rds")

# Share of claims that have a recorded amount (from training data only)
k <- sum(freMTPL2sev$IDpol %in% train$IDpol) / sum(train$ClaimNb)
k

test$pure_premium_adj  <- test$pure_premium  * k
test$expected_cost_adj <- test$expected_cost * k
sum(test$expected_cost_adj) / sum(test$actual_cost)

# Is the remaining gap from large claims? Compare without large claims
test <- test |>
  left_join(select(readRDS("sev_pol.rds"), IDpol, total_capped), by = "IDpol") |>
  mutate(total_capped = coalesce(total_capped, 0))
sum(test$expected_cost_adj / lc$loading) / sum(test$total_capped)

lift <- test |>
  mutate(decile = ntile(pure_premium_adj, 10)) |>
  group_by(decile) |>
  summarise(exposure  = sum(Exposure),
            predicted = sum(expected_cost_adj) / sum(Exposure),
            actual    = sum(actual_cost) / sum(Exposure))
lift

ggplot(lift, aes(x = decile)) +
  geom_line(aes(y = predicted, colour = "Predicted")) +
  geom_point(aes(y = predicted, colour = "Predicted")) +
  geom_line(aes(y = actual, colour = "Actual")) +
  geom_point(aes(y = actual, colour = "Actual")) +
  scale_x_continuous(breaks = 1:10) +
  labs(title = "Lift chart: predicted vs actual loss cost (test data)",
       x = "Decile of predicted pure premium (1 = lowest risk)",
       y = "Loss cost per policy-year (EUR)", colour = NULL)
ggsave("plots/lift_chart.png", width = 7, height = 4)

lift$actual[10] / lift$actual[1]
saveRDS(test, "test_scored.rds")

test |>
  mutate(decile = ntile(pure_premium_adj, 10)) |>
  group_by(decile) |>
  summarise(pred_claims   = sum(freq_period),
            actual_claims = sum(ClaimNb),
            share_new_car = mean(VehAge == 0),
            mean_bm       = mean(BonusMalus))

test |>
  left_join(select(readRDS("sev_pol.rds"), IDpol, n_claims), by = "IDpol") |>
  mutate(n_claims = coalesce(n_claims, 0),
         decile   = ntile(pure_premium_adj, 10)) |>
  group_by(decile) |>
  summarise(claims             = sum(ClaimNb),
            claims_with_amount = sum(n_claims),
            share_with_amount  = claims_with_amount / claims)

# 8. Frequency of claims WITH a recorded amount (paid claims)
sev_pol <- readRDS("sev_pol.rds")
add_paid <- function(df) {
  df |>
    select(-any_of("n_claims")) |>
    left_join(select(sev_pol, IDpol, n_claims), by = "IDpol") |>
    mutate(PaidNb = pmin(coalesce(n_claims, 0), 4))
}
train_paid <- add_paid(readRDS("train.rds"))
test       <- add_paid(test)

freq_paid <- update(freq_glm2, PaidNb ~ ., data = train_paid)

# New-vehicle relativity: all claims vs paid claims
exp(coef(freq_glm2)["VehAgeBand(-1,0]"])
exp(coef(freq_paid)["VehAgeBand(-1,0]"])

# 9. Pure premium without k
test_annual          <- test
test_annual$Exposure <- 1
test$pp_paid       <- predict(freq_paid, newdata = test_annual, type = "response") * test$sev_pred
test$exp_cost_paid <- predict(freq_paid, newdata = test, type = "response") * test$sev_pred

sum(test$exp_cost_paid) / sum(test$actual_cost)

# 10. New lift chart
lift2 <- test |>
  mutate(decile = ntile(pp_paid, 10)) |>
  group_by(decile) |>
  summarise(predicted = sum(exp_cost_paid) / sum(Exposure),
            actual    = sum(actual_cost) / sum(Exposure))
lift2

ggplot(lift2, aes(x = decile)) +
  geom_line(aes(y = predicted, colour = "Predicted")) +
  geom_point(aes(y = predicted, colour = "Predicted")) +
  geom_line(aes(y = actual, colour = "Actual")) +
  geom_point(aes(y = actual, colour = "Actual")) +
  scale_x_continuous(breaks = 1:10) +
  labs(title = "Lift chart: paid-claim frequency model (test data)",
       x = "Decile of predicted pure premium (1 = lowest risk)",
       y = "Loss cost per policy-year (EUR)", colour = NULL)
ggsave("plots/lift_chart_paid.png", width = 7, height = 4)

saveRDS(freq_paid, "freq_paid.rds")
saveRDS(test, "test_scored.rds")
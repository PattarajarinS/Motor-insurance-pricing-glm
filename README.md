# Motor Insurance Pricing with GLMs

A pure premium model for French motor third-party liability insurance, built in R with a Poisson GLM for claim frequency and a Gamma GLM for claim severity, validated on hold-out data.

## Key findings

- **New vehicles looked 2.4 times riskier, but are in fact 18% less risky.** Almost half of the claims in the highest-risk group had no recorded payment. Modelling only claims with a cost reversed the new-vehicle effect, consistent with the older, lower-risk drivers of new vehicles. Without this correction, new-vehicle owners would have been charged about three times their fair premium.
- **The final model separates risk well.** On hold-out data, the riskiest 10% of policies cost 3.6 times more than the safest 10%.
- **Bonus-malus is the strongest driver of claim frequency.** Drivers with a bonus-malus of 100–150 claim about 5.4 times as often as drivers with the maximum bonus, all else equal. Much of young drivers' apparent risk is captured by bonus-malus, because new drivers start without accumulated discounts.
- **Claim costs are heavily skewed.** The largest 0.5% of claims account for about 25% of total claim costs.

## Data

Two files from the `freMTPL2` dataset:

- **`freMTPL2freq`:** 678,013 motor third-party liability policies, mostly observed over one year, with policy and driver characteristics and the number of claims.
- **`freMTPL2sev`:** 26,639 individual claim amounts in euros, linked to policies by ID.

| Variable | Description | Role |
|---|---|---|
| `IDpol` | Policy ID | Identifier / link |
| `ClaimNb` | Number of claims | Response (frequency) |
| `ClaimAmount` | Claim amount in EUR | Response (severity) |
| `Exposure` | Years of coverage observed | Covariate |
| `DrivAge` | Driver age | Rating factor |
| `BonusMalus` | Bonus-malus level (50 = maximum discount, above 100 = surcharge) | Rating factor |
| `VehAge` | Vehicle age | Rating factor |
| `VehPower` | Vehicle power (ordered categories) | Rating factor |
| `VehGas` | Fuel type (Diesel / Regular) | Rating factor |
| `VehBrand` | Vehicle brand (anonymised, B1–B14) | Rating factor |
| `Area` | Area density class (A = rural, F = urban centre) | Rating factor |
| `Density` | Population density | Not used (see below) |
| `Region` | Region in France | Rating factor |

The overall claim frequency is 0.101 claims per policy-year, and about 95% of policies have no claims.

**Source:** Dutang, C. and Charpentier, A. (2024). *CASdatasets: Insurance datasets*, R package version 1.2-0. DOI: 10.57745/P0KHAG.

### Data quality issues

- **Claims without a recorded amount.** The policy data contains 36,056 claims, but only 26,639 claim amounts exist, so about 26% of claims have no recorded payment. This share is not uniform: it is much higher for short-exposure policies and new vehicles (see below). The reason cannot be determined from the data; possible explanations include claims closed without payment or open claims.
- **Unmatched claims.** 195 claim amounts (0.7%) have no matching policy and were excluded. This matches the known inconsistency between the two files.
- **Implausible values.** Nine policies had more than 4 claims (up to 16) within less than a year, and 1,224 policies had exposure above 1 year (up to 2.01). Claim counts were capped at 4 and exposure at 1 year. Together these affect less than 0.2% of policies. Capping claims at anywhere from 3 to 6 changes the overall frequency by less than 0.1%.

## Exploratory analysis

Claim frequency (claims per policy-year) was analysed one factor at a time. Plots are in the `plots/` folder.

- **Driver age:** U-shaped. Highest for ages 18–20 (0.249), lowest for ages 30–40 (0.090). A second rise for ages 40–60 likely reflects young family members driving their parents' cars, as only the main policyholder's age is recorded.
- **Bonus-malus:** Frequency rises steeply from about 0.08 at the maximum discount to about 0.37 for levels 100–150 (0.57 for levels 150–250, a small group of only 95 policy-years).

![Claim frequency by bonus-malus](plots/freq_by_BonusMalusBand.png)
- **Area:** Frequency increases from rural (A) to urban (F). `Area` is a banded version of population density (median density rises from 27 to 27,000 inhabitants/km²), so only `Area` was used, to avoid collinearity.
- **Vehicle power and fuel type:** Weak effects with no clear pattern.

### Investigation: why do new vehicles look so risky?

New vehicles (age 0) showed a claim frequency of about 0.31, roughly three times that of older vehicles. This was investigated step by step:

1. **Not the drivers.** New-vehicle drivers have the highest average age (47.3) and a low average bonus-malus (58.3).
2. **Short exposure.** New vehicles have a much shorter average exposure (0.29 years vs 0.48–0.59). Across the whole portfolio, frequency falls with exposure length: 0.285 for policies under 3 months vs 0.074 for policies of 9–12 months.
3. **Brand B12** has the highest frequency, 22.3% new vehicles (vs 3–7% for other brands) and the shortest exposure, pointing to the same effect.
4. **Exposure in the model.** Estimating exposure as a covariate instead of an offset gives a coefficient of 0.42 rather than 1, improves AIC by more than 5,000, and reduces the new-vehicle relativity from 3.1 to 2.4. The B12 effect almost disappears.
5. **Unpaid claims (resolution).** Validation showed that in the highest-risk decile, which is 62% new vehicles, only 52% of claims have a recorded amount, compared with 74–84% in other deciles. Modelling only claims with a cost changes the new-vehicle relativity from **2.38 to 0.82**.

The elevated frequency of new vehicles therefore consists largely of claims without payment. In terms of actual costs, new vehicles are a low-risk group.

## Model

**Pure premium = paid-claim frequency × expected claim severity × large-claim loading**

The data was split at random (seed 2026) into 80% training and 20% hold-out test data. The reference level of each factor is the group with the most exposure, and coefficients are exponentiated into multiplicative relativities.

### Frequency model (Poisson GLM)

The final frequency model predicts the number of **claims with a recorded amount**, so that frequency and severity describe the same claims. Exposure is included as a covariate rather than an offset, as this fits much better (see the investigation above). Annual premiums are calculated at exposure = 1, where the exposure term has no effect.

Likelihood ratio tests on the all-claims model ranked the rating factors as follows:

| Factor | Df | LRT |
|---|---|---|
| Vehicle age | 5 | 3,797 |
| Bonus-malus | 6 | 3,271 |
| Driver age | 7 | 720 |
| Vehicle power | 5 | 223 |
| Region | 21 | 155 |
| Area | 5 | 118 |
| Vehicle brand | 10 | 76 |
| Fuel type | 1 | 49 |

All factors are significant and reduce AIC, so all were kept. The high importance of vehicle age reflects the new-vehicle effect explained above.

### Severity model (Gamma GLM)

Claim amounts are positive and right-skewed: the mean (€2,279) is almost twice the median (€1,172). A Gamma GLM with log link was fitted to the average claim amount per policy, weighted by the number of claims.

**Large claims.** Claims were capped at the 99.5th percentile (€34,387), so that a few extreme claims do not distort relativities. The capped amount is added back to all policies through a large-claim loading of 1.339. The choice of cap matters, as the loading varies with it:

| Cap percentile | Cap (EUR) | Loading |
|---|---|---|
| 99% | 16,794 | 1.440 |
| 99.5% | 34,387 | 1.339 |
| 99.9% | 162,784 | 1.166 |

**Factor selection.** Fuel type (p = 0.58) and vehicle brand were removed: an F-test showed no significant loss from dropping both (p = 0.81), and AIC rose only slightly (by 3) despite 11 fewer parameters. The final severity model uses driver age, bonus-malus, vehicle age, vehicle power, area and region. Driver age is the most important factor for severity, unlike for frequency: what makes claims frequent is not the same as what makes them expensive. Urban areas have more frequent but cheaper claims.

## Validation on hold-out data

**Frequency models.** The exposure-as-covariate model reduced Poisson deviance on test data from 43,035 to 41,531 compared with the standard offset model, confirming that the improvement holds out of sample.

**Overall balance (predicted ÷ actual total costs):**

| Model | Ratio |
|---|---|
| All claims, no adjustment | 1.51 |
| All claims × share of claims with an amount (0.734) | 1.11 |
| **Paid-claim frequency model (final)** | **1.10** |
| Final model, excluding large claims on both sides | 0.98 |

Excluding large claims, the model predicts test costs within 2%. The remaining 10% gap comes from large claims: the test sample happened to contain fewer large claims than average, which is expected given their heavy tail.

**Lift chart.** Test policies were sorted by predicted premium into 10 equal groups, comparing predicted and actual loss cost per policy-year.

| Decile | All claims × 0.734: predicted | Actual | Paid-claim model: predicted | Actual |
|---|---|---|---|---|
| 1 (lowest risk) | 68 | 114 | 64 | 103 |
| 10 (highest risk) | 569 | 286 | 495 | 369 |
| Top ÷ bottom (actual) | | 2.5× | | **3.6×** |

![Lift chart of the final model](plots/lift_chart_paid.png)

The paid-claim model places genuinely more expensive policies in the top group and reduces the overprediction there from about 2× to about 1.3×. A uniform adjustment factor would have hidden this problem, as both approaches give almost the same overall balance.

## Limitations

- **Unpaid claims:** why about a quarter of claims have no recorded amount cannot be determined from the data.
- **Top-risk group:** the highest-risk 10% is still overpriced by about 20–30% after allowing for large-claim volatility. In practice, these premiums would need to be capped or reviewed.
- **No interactions:** the GLM assumes rating factors combine multiplicatively and independently.
- **Large claims** make actual costs volatile in small groups, so individual deciles fluctuate.
- **Missing information:** vehicle brands are anonymised, only the main policyholder's age is recorded, and there is no mileage data.
- **Bonus-malus** is based on past claims (a posteriori), so it overlaps with factors such as driver age.

## Possible extensions

- Interaction terms or a gradient boosting model to improve the top-risk group
- Credibility weighting for thin cells (for example, small regions)
- Separate modelling of the probability that a claim results in a payment

## Repository structure

```
motor-pricing/
├── 01_load_data.R                  # Download and first look at the data
├── 02_clean_explore.R              # Cleaning, capping, first plots
├── 03_explore_factors.R            # One-way analysis of all rating factors
├── 04_frequency_glm.R              # Poisson GLM with exposure offset
├── 05_model_testing.R              # Likelihood ratio tests, exposure as covariate
├── 06_severity_glm.R               # Large claims, Gamma GLM
├── 07_pure_premium_validation.R    # Pure premium, paid-claim model, lift charts
└── plots/                          # Saved charts
```

## Tools

R 4.6.1, dplyr, ggplot2

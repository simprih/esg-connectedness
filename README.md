# Interdependencies and Risk Transmission Across Major ESG Indices

Do MSCI Selection indices (formerly ESG Leaders) receive fewer volatility shocks than their parent indices, especially during crises? We study 17 assets: five MSCI regional indices, their ESG versions, and seven commodity, bond and currency series. Volatility spillovers are measured on weekly realized volatility with the Diebold-Yilmaz (2012) connectedness approach, in a static VAR and a TVP-VAR.

```mermaid
flowchart LR
    A[MSCI + Bloomberg daily data] --> B[Weekly realized volatility] --> C[Static connectedness]
    C -.-> D[Dynamic connectedness and crisis test] -.-> E[DCC-GARCH] -.-> F[Networks] -.-> G[Portfolios]
    classDef planned stroke-dasharray: 5 5
    class D,E,F,G planned
```

## Motivation

Investors often assume that ESG indices hold up better in crises and offer better diversification. The literature on ESG volatility spillovers gives mixed results. An ESG index and its parent share most of their constituents, so a direct comparison mostly measures their link with each other. We therefore separate the risk an index receives from its twin from the risk it receives from the rest of the system: other regions, commodities, bonds and the dollar.

## Methodology

- Static connectedness: VAR(4), generalized forecast error variance decomposition, H = 10 (Diebold and Yilmaz, 2012). Moving block bootstrap for the ESG minus parent gap.
- Dynamic connectedness: TVP-VAR (Antonakakis et al., 2020), with rolling-window Diebold-Yilmaz as a robustness check. Crisis and calm weeks are compared on crisis periods dated from events.
- Dynamic correlations: DCC-GARCH (Engle, 2002).
- Network structure: minimum spanning tree and planar maximally filtered graph.
- Portfolio implications: network-based allocation, compared with benchmark portfolios.

## Design choices

- Weekly data, Friday to Thursday: limits the effect of non-synchronous closing times across regions and avoids the Friday effect.
- Realized volatility from daily closes, since MSCI only provides closing levels.
- No look-ahead: the TVP-VAR prior is estimated on the first 104 weeks, which are then dropped from all measures.
- Crisis periods are fixed ex ante from dated events, before looking at any result.
- Inference by moving block bootstrap rather than by visual inspection of the series.

## Data

The data are licensed (MSCI, Bloomberg) and are not included in this repository.

| Series | Source |
|---|---|
| MSCI USA, Europe, Japan, Emerging Markets, Pacific ex Japan (Standard, Large+Mid Cap) | MSCI End of Day Index Data Search |
| The same five indices in their Selection (former ESG Leaders) version | MSCI End of Day Index Data Search |
| Brent crude oil, first-month futures | Bloomberg `CO1 Comdty` |
| Gold, spot | Bloomberg `XAU Curncy` |
| COMEX copper, first-month futures | Bloomberg `HG1 Comdty` |
| Dutch TTF natural gas, first-month futures, in USD | Bloomberg `TZT1 Comdty` |
| Bloomberg US Treasury Total Return Index | Bloomberg `LUATTRUU Index` |
| Bloomberg Euro-Aggregate Treasury Total Return Index, USD hedged | Bloomberg `H02004US Index` |
| US Dollar Index | Bloomberg `DXY Curncy` |

All series are daily closing levels in USD, from 1 September 2010. Place the raw files in `data/raw/`:

- 16 MSCI exports named `{lot}_{level}_{chunk}.xls`, with `lot` in `esg`, `parents`, `level` in `price`, `net`, and `chunk` in `2010-2014`, `2015-2019`, `2020-2024`, `2025-14102026`. Each file holds five indices.
- `bloomberg_daily.xlsx`: one sheet built with `BDH(ticker, "PX_LAST", ...)`, one block of three columns per asset (date, price, empty), asset names on the first row.

## Repository structure

```
config/crisis_periods.csv          crisis dates, fixed ex ante from dated events
python/config.py                   paths and parameters for the Python scripts
R/00_setup.R                       paths and parameters for the R scripts
python/01_build_daily_prices.py    raw MSCI and Bloomberg files to daily prices (17 assets)
python/02_build_weekly_series.py   weekly log returns and log realized volatility (Friday to Thursday)
python/03_descriptive_stats.py     descriptive statistics and unit-root tests (Table 1)
R/04_dy_static.R                   static Diebold-Yilmaz connectedness, lag selection, robustness
R/05_bootstrap_twins.R             moving block bootstrap of the ESG minus parent gap
python/06_count_crisis_weeks.py    crisis and calm weeks per crisis window
```

Scripts write to `data/processed/` and `output/tables/`, which are not tracked.

## Tools

- Python (pandas, NumPy, SciPy, statsmodels, arch) for the data, descriptive statistics and networks.
- R (ConnectednessApproach, vars, then rmgarch) for connectedness and DCC-GARCH.

## How to run

Tested with Python 3.14 and R 4.6. Python:

```
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

R, with the packages used by the R scripts:

```
install.packages(c("ConnectednessApproach", "vars", "zoo"))
```

Then run the scripts from the project root, in this order:

```
python python/01_build_daily_prices.py
python python/02_build_weekly_series.py
python python/03_descriptive_stats.py
Rscript R/04_dy_static.R
Rscript R/05_bootstrap_twins.R
python python/06_count_crisis_weeks.py
```

The bootstrap (`R/05`) takes a few minutes.

## Status

- Static connectedness: done.
- Dynamic connectedness: in progress.
- DCC-GARCH, networks, portfolios: planned.

The paper is in preparation.

## References

- Diebold, F. X. and Yilmaz, K. (2012). Better to give than to receive: Predictive directional measurement of volatility spillovers. International Journal of Forecasting, 28(1), 57-66.
- Antonakakis, N., Chatziantoniou, I. and Gabauer, D. (2020). Refined measures of dynamic connectedness based on time-varying parameter vector autoregressions. Journal of Risk and Financial Management, 13(4), 84.
- Brüggemann, R., Jentsch, C. and Trenkler, C. (2016). Inference in VARs with conditional heteroskedasticity of unknown form. Journal of Econometrics, 191(1), 69-85.
- Engle, R. F. (2002). Dynamic conditional correlation: A simple class of multivariate generalized autoregressive conditional heteroskedasticity models. Journal of Business and Economic Statistics, 20(3), 339-350.
- Mantegna, R. N. (1999). Hierarchical structure in financial markets. European Physical Journal B, 11, 193-197.
- Tumminello, M., Aste, T., Di Matteo, T. and Mantegna, R. N. (2005). A tool for filtering information in complex systems. PNAS, 102(30), 10421-10426.

## Author

Simon Prihnenko, ESILV, student researcher at the De Vinci Research Center.

Supervised by Dr. Duc-Thi Luu.

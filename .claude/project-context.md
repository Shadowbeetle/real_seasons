# Real Seasons of Budapest

## Inspiration

Based on [12seasons.nyc](https://12seasons.nyc) — a site that classifies NYC's current weather into one of 12 humorous seasons using historical temperature data and standard deviation analysis.

Source code: [github.com/x/nyc-seasons](https://github.com/x/nyc-seasons)

## Project Overview

A Phoenix web app for Budapest that classifies current weather into 12 seasons using 4 different historical baselines shown simultaneously. The frontend reuses the original site's static HTML/CSS approach; Phoenix provides the backend (data pipeline, API, serving).

## Titles

- **Hungarian:** Budapesten 12 ÉVSZAK VAN
- **English:** Budapest actually has 12 seasons

## The 12 Seasons

| # | Internal Key | Hungarian | English |
|---|-------------|-----------|---------|
| 0 | winter | Tél | Winter |
| 1 | fools_spring | Bolondok Tavasza | Fool's Spring |
| 2 | second_winter | Második Tél | Second Winter |
| 3 | deceptive_spring | Csalóka Tavasz | Deceptive Spring |
| 4 | third_winter | Harmadik Tél | Third Winter |
| 5 | poplar_bloom | Nyárfavirágzás | The Poplar Bloom |
| 6 | actual_spring | Igazi Tavasz | Actual Spring |
| 7 | summer | Nyár | Summer |
| 8 | hells_porch | A pokol tornáca | Hell's Front Porch |
| 9 | false_fall | Hamis Ősz | False Fall |
| 10 | indian_summer | Vénasszonyok Nyara | Indian Summer |
| 11 | actual_fall | Igazi Ősz | Actual Fall |

## 4 Baseline Tiers

All shown simultaneously, each with a colored dot indicator:

| Baseline | Label (HU) | Label (EN) | Color | Date Range |
|----------|-----------|------------|-------|------------|
| since1970 | 1970 óta | Since 1970 | #e74c3c (red) | 1970–2025 |
| last20y | Utolsó 20 év | Last 20 years | #f39c12 (orange) | 2006–2025 |
| last10y | Utolsó 10 év | Last 10 years | #3498db (blue) | 2016–2025 |
| last5y | Utolsó 5 év | Last 5 years | #2ecc71 (green) | 2021–2025 |

## Classification Algorithm

### Sub-Seasons (calendar-based)

12 sub-seasons: early/mid/late for each of the 4 astrological seasons. Same boundaries as the NYC original:

- earlySpring: 03-20 → 04-19
- midSpring: 04-19 → 05-22
- lateSpring: 05-22 → 06-21
- earlySummer: 06-21 → 07-21
- midSummer: 07-21 → 08-22
- lateSummer: 08-22 → 09-22
- earlyFall: 09-22 → 10-22
- midFall: 10-22 → 11-21
- lateFall: 11-21 → 12-21
- earlyWinter: 12-21 → 01-19
- midWinter: 01-19 → 02-18
- lateWinter: 02-18 → 03-20

### Temperature Classification

For a given baseline's mean and std at the current day-hour:
- **Cold:** apparent_temp < mean - 1.5 × std
- **Mid:** within ±1.5 × std of mean
- **Hot:** apparent_temp > mean + 1.5 × std

### Season Grid (sub-season × temperature class)

**Winter sub-seasons:**

|  | Early | Mid | Late |
|--|-------|-----|------|
| Cold | Tél | Tél | Második Tél |
| Mid | Tél | Tél | Második Tél |
| Hot | Bolondok Tavasza | Bolondok Tavasza | Bolondok Tavasza |

**Spring sub-seasons:**

|  | Early | Mid | Late |
|--|-------|-----|------|
| Cold | Harmadik Tél | Harmadik Tél | Harmadik Tél |
| Mid | Csalóka Tavasz | Igazi Tavasz | Igazi Tavasz |
| Hot | Csalóka Tavasz | Nyárfavirágzás | Nyárfavirágzás |

**Summer sub-seasons:**

|  | Early | Mid | Late |
|--|-------|-----|------|
| Cold | Nyár | Nyár | Hamis Ősz |
| Mid | Nyár | Nyár | Hamis Ősz |
| Hot | A pokol tornáca | A pokol tornáca | A pokol tornáca |

**Fall sub-seasons:**

|  | Early | Mid | Late |
|--|-------|-----|------|
| Cold | Tél | Tél | Tél |
| Mid | Igazi Ősz | Igazi Ősz | Igazi Ősz |
| Hot | Vénasszonyok Nyara | Vénasszonyok Nyara | Vénasszonyok Nyara |

## Tech Stack

- **Backend:** Elixir / Phoenix (no LiveView — static HTML/CSS frontend)
- **Data pipeline:** Mix task using PythonX + numpy for historical data fetching & stats computation
- **i18n:** Gettext (HU default, EN supported)
- **Historical data:** Open-Meteo Archive API (free, no key needed)
- **Current weather:** Open-Meteo Forecast API (free, no key needed)
- **Frontend:** Static HTML/CSS reusing the original 12seasons.nyc patterns, served by Phoenix

## Data Source

- **Budapest coordinates:** lat=47.498, lon=19.04
- **Historical API:** `https://archive-api.open-meteo.com/v1/archive?latitude=47.498&longitude=19.04&start_date=YYYY-01-01&end_date=YYYY-12-31&hourly=apparent_temperature&timezone=Europe/Budapest`
- **Current weather API:** `https://api.open-meteo.com/v1/forecast?latitude=47.498&longitude=19.04&current=apparent_temperature&timezone=Europe/Budapest`
- **Temperature unit:** Celsius
- **Data key format:** `"DDD-HH"` (zero-padded day-of-year 001-366, zero-padded hour 00-23)

## Architecture

1. **Mix task** (`mix real_seasons.fetch_data`): Fetches 56 years of hourly data year-by-year, caches raw responses, uses numpy via PythonX to compute mean/std for all 4 baselines, outputs `priv/data/temps.json`
2. **GenServer** (`RealSeasons.TempStats`): Loads pre-computed stats into memory at app startup
3. **Weather module** (`RealSeasons.Weather`): Fetches & caches current Budapest weather from Open-Meteo
4. **Classifier** (`RealSeasons.SeasonClassifier`): Pure functions — sub-season detection, temp classification, season grid lookup
5. **Controller/View**: Serves the static HTML page with season data injected server-side
6. **Gettext**: HU/EN translations for all UI strings

## UI Behavior

- All 4 baseline results shown simultaneously as colored dots next to season names
- Primary "You are here" / "Itt vagy!" arrow on the since-1970 baseline result
- Explainer text shows standard deviation info for the primary baseline
- Language toggle switches HU↔EN
- Methodology section in expandable `<details>` element

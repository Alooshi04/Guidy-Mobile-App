# Data sources for Cairo and Alexandria transit, October 2026

Research date: 31 October 2026. Backend checked: `youssefezat/guidy-backend` at
`66e96e3` (`gtfs_data/`, which is what the API loads; `GTFS_PATH` in `main.py`).
Nothing in the backend was changed. This file is for deciding what to integrate.

How to read it: each finding says where it comes from and how sure it is.
"Confirmed" means two or more independent reports, or one official one, agree.
"Reported" means one news report and nothing official found. Some hosts were
blocked by this session's network policy (mobilitydatabase.org,
data.transportforcairo.com, sis.gov.eg, masrawy.com, cairoscene.com,
manassa.news). For those pages only the search engine's summary was read, so
open them before acting on a figure.

## 1. What the backend has today (counted)

Counted from `gtfs_data/routes.txt`, `trips.txt` and `stop_times.txt`, with each
route's mode resolved by the engine's own rules (`resolve_vehicle_type` in
`raptor_engine.py`). A city is "Alexandria" for `ALX_*` agencies,
"Greater Cairo" for the rest; the three `ALX_INTERCITY` lines are Cairo/Giza to
Alexandria.

| | Greater Cairo | Alexandria | Cairo–Alexandria | Total |
|---|---:|---:|---:|---:|
| Microbus lines | 593 | 101 | 3 | **697** |
| Bus lines | 313 | 68 | | **381** |
| Minibus lines | 207 | 7 | | **214** |
| Metro lines | 3 | | | **3** |
| LRT branches | 2 | | | **2** |
| Monorail lines | 1 | | | **1** |
| BRT lines | 1 | | | **1** |
| Airport shuttle (APM) | 1 | | | **1** |
| All lines | 1,121 | 176 | 3 | **1,300** |
| Stops served by a line | 3,292 | 1,896 | 4 | **5,189** distinct |

Rail and BRT stations: metro 84 (Line 1: 35, Line 2: 20, Line 3: 34 on two
branches, 5 interchanges shared), monorail 22, LRT 12, BRT 14, airport shuttle 4.
There is no tram and no Abu Qir line in the feed (both correct today, see 3.4).

The website said 359 bus lines and 5,177 stops (counted 8 October 2026). The
backend has grown since; the site is updated to the numbers above.

## 2. Discrepancies, ranked

| # | What | Backend now | What sources say | Source | Confidence | Suggested action |
|---|---|---|---|---|---|---|
| 1 | **CTA bus fares** | `FLAT_FARE_BY_VEHICLE["bus"] = 20`, AC buses 45 EGP (`_estimate_leg_fare`) | Regular CTA bus 13 EGP (was 12), AC 25 EGP (was 23), from the 10 March 2026 fuel adjustment, 186 lines. Since 15 July 2026, card (prepaid) riders pay by distance: regular 13 / 8 / 5 (full, half, quarter), AC 25 / 18. Cash riders always pay full. | Youm7, 12 Mar 2026 ([1](https://www.youm7.com/7336809), [2](https://www.youm7.com/story/2026/3/10/%D8%AA%D8%B9%D8%B1%D9%8A%D9%81%D8%A9-%D8%B1%D9%83%D9%88%D8%A8-%D8%A3%D8%AA%D9%88%D8%A8%D9%8A%D8%B3%D8%A7%D8%AA-%D8%A7%D9%84%D9%86%D9%82%D9%84-%D8%A7%D9%84%D8%B9%D8%A7%D9%85-%D8%A8%D8%A7%D9%84%D9%82%D8%A7%D9%87%D8%B1%D8%A9-%D8%A7%D9%84%D9%83%D8%A8%D8%B1%D9%89-%D8%A8%D8%B9%D8%AF-%D8%AA%D8%AD%D8%B1%D9%8A%D9%83-%D8%A3%D8%B3%D8%B9%D8%A7%D8%B1/7334986)); Masrawy 19 Jul 2026 ([link](https://www.masrawy.com/news/news_egypt/details/2026/7/19/3019974)); Al-Ain ([link](https://al-ain.com/article/cairo-public-buses-new-ticket-system-july-2026)); Elbalad ([link](https://www.elbalad.news/7043488)) | Confirmed (several outlets, same figures) | High value: Guidy overstates the commonest bus fare by 7 EGP and AC by 20. Use 13 / 25 as the cash fare. Mwasalat Misr, Green Bus and TMG have their own tariffs (not found); don't move them with CTA without a source. |
| 2 | **Ring Road BRT phase 2** | Phase 1 only: 14 stations, Alexandria Agricultural Rd – Police Academy (`BRT_RING_P1`) | Phase 2 opened 26 Sep 2026: ~40 km from Ain Sokhna Rd to Sun Capital (Ring Road × Fayoum Rd), 16 stations, joined to phase 1 at the Alexandria Agricultural Rd junction. Named: Ain Sokhna Rd, Maadi, Mokattam, Algeria, El-Imamein, El-Zahraa, El-Bahr El-Aazam, Omraniya, Talbiya, Mariouteya, Sun Capital; Zahraa El-Maadi, Autostrad, Mansouriya to open "gradually". Fares 5 EGP (1–4 stations) up to 35 EGP (27–30). | Cairoscene ([link](https://cairoscene.com/News/Second-Phase-of-Cairo-BRT-Begins-Public-Operations)); see.news ([link](https://see.news/egypt-launches-2nd-phase-of-cairo-brt)); Al-Ahram Gate infographic, 30 stations in both phases ([link](https://gate.ahram.org.eg/News/5933505.aspx)); Al-Dostor fares ([link](https://www.dostor.org/5718715)) | Opening confirmed; station list and fare bands reported, not official, and they disagree (10 EGP for 9 vs 10 stations) | High value. Wait for an official station list (Ministry of Transport or Cairo Governorate portal) and coordinates before adding; the OSM busway can give geometry as for phase 1. Extend `BANDED_FARE_TIERS["brt"]` only from an official table. |
| 3 | **Monorail service hours** | `frequencies.txt`: `RL_MONO_EN_D0/D1` 06:00–18:00 | 06:00–21:00 since the full line opened on 27 Jun 2026. The engine's comment and `DEFAULT_SERVICE_WINDOWS_BY_VTYPE` already say 21:00; the feed rows still carry phase 1's 18:00. | SIS ([link](https://sis.gov.eg/en/media-center/news/2nd-phase-of-east-nile-monorail-launched-saturday-expanding-link-to-new-capital/)); Ahram Online ([link](https://english.ahram.org.eg/News/571668.aspx)); Egyptian Streets ([link](https://egyptianstreets.com/2026/06/26/egypt-to-launch-second-phase-of-east-nile-monorail-on-saturday/)) | Confirmed | Low, tidy-up: `load_data` already forces the monorail window to 06:00–21:00, so trips after 18:00 are offered. Only the headway after 18:00 comes from no feed row (falls back to the default). Set the two rows' end to 21:00:00 so the feed agrees with the engine. |
| 4 | **Cairo minibus fares** | 20 EGP flat | Ordinary minibus 18→19, AC 22→25 EGP after March 2026. | One search summary of a Cairo report; not opened | Reported | Medium: Guidy is 1 EGP high. Confirm against Cairo Governorate's March 2026 table before changing. |
| 5 | **Microbus fares, Cairo and Giza** | 10 / 12 / 15 EGP by distance (estimate) | Cairo +10–15% and Giza ~+17% on 10 Mar 2026, set per line (e.g. Hawamdeya–Giza 13, Hawamdeya–Moneeb 9.50). There is no flat schedule; each governorate publishes per-line tables. | Al-Qarar Al-Masry ([link](https://alqararalmasry.com/2026/03/10/%D8%A3%D8%AE%D8%A8%D8%A7%D8%B1-%D9%85%D8%B5%D8%B1/%D8%B2%D9%8A%D8%A7%D8%AF%D8%A9-%D8%A3%D8%AC%D8%B1%D8%A9-%D8%A7%D9%84%D9%85%D9%8A%D9%83%D8%B1%D9%88%D8%A8%D8%A7%D8%B5-%D8%A8%D8%A7%D9%84%D8%AC%D9%8A%D8%B2%D8%A9-%D8%A8%D8%B9%D8%AF-%D8%B1%D9%81%D8%B9/262391/)); Vetogate ([link](https://www.vetogate.com/5611165)); Maspero ([link](https://www.maspero.eg/our-reporters/2026/03/10/935369/)); Shbabbek, Cairo tables with images ([link](https://shbabbek.com/show/267581)) | Confirmed that it rose; per-line tables not extracted | Medium. The tables could give real per-line fares for the busiest Cairo/Giza terminals, the way `alex_fares.json` does for Alexandria. Labour: transcribing images. |
| 6 | **TfC Alexandria licence** | `alexandria_source/ATTRIBUTION.md` and the Terms say CC BY 4.0 | The portal metadata saved in `alexandria_source/doc92_meta.json` has `"license": {"identifier": ""}`: no licence is set for document 92. TfC's other feeds are CC BY-NC (see 3.1). | Backend file; portal page not reachable from here | Fact about our own copy; the licence itself unverified | High (legal), easy: confirm with TfC that the written permission noted in the backend's `DEPLOYMENT.md` ("GTFS data licensing: Resolved") covers the Alexandria survey too, or get the CC BY 4.0 in writing. Until then the website credits TfC for Alexandria without naming a licence. |
| 7 | **LRT phase 3** | 12 stations, ends at Arts and Culture City / Knowledge City | Phase 3 (20.4 km, 4 stations: Nativity Cathedral, Strategic Command, International Sports City, Central Capital). In January 2026 two stations were planned for trial in April 2026; no report found that they opened. | Al-Manassa ([link](https://almanassa.com/en/news/29531)); Wikipedia ([link](https://en.wikipedia.org/wiki/Cairo_Light_Rail_Transit)) | Unconfirmed opening | Don't add. Re-check in Arabic news (NAT). |
| 8 | **LRT fares** | 10 / 15 / 20 EGP for ≤3 / ≤7 / more hops, flagged unverified in code | 10 EGP up to 3 stations, 20 EGP beyond 7 (middle band not given); monthly passes 300–600. Other pages give 15–35 (older). | Egypt Independent ([link](https://www.egyptindependent.com/operating-hours-and-ticket-prices-for-cairos-light-rail-transit/)); Al-Manassa (above) | Reported | Keep. The middle band (15) is still unconfirmed. |
| 9 | Metro fares | 10 / 12 / 15 / 20 | 10 (9 stations), 12 (16), 15 (23), 20 (beyond) from 27 Mar 2026 | Egyptian Streets ([link](https://egyptianstreets.com/2026/03/27/egypt-raises-train-and-metro-ticket-prices-starting-today/)); AGBI ([link](https://www.agbi.com/transport/2026/03/egypt-raises-train-and-metro-ticket-prices-on-higher-oil-costs/)) | Confirmed | Matches. No change. |
| 10 | Monorail stations and fares | 22 stations, 20 / 40 / 55 / 80 | Full 22-station line open since 27 Jun 2026 (6 added: Cairo Stadium, Hesham Barakat, Al-Azhar University, Seventh District, Field Marshal Ahmed Ismail, Jehan El-Sadat); fares 20 / 40 / 55 / 80 for 5 / 10 / 15 / full | EgyptToday ([link](https://www.egypttoday.com/Article/1/148032/East-Nile-Monorail-Transport-Ministry-launches-2nd-phase-adds-6)); Egyptian Streets fares ([link](https://egyptianstreets.com/2026/05/09/egypt-announced-monorail-ticket-prices/)) | Confirmed | Matches, apart from the hours (#3). |
| 11 | Alexandria APTA bus fares | `null` in `alex_fares.json` (heuristic used) | APTA said in March 2026 its fares were not raised. Line fares from Oct 2025: 5.5 EGP (Km 21 – Wardian), 7 EGP (Km 21 – Misr Station / Mansheya). | Youm7, 10 Mar 2026 ([link](https://www.youm7.com/story/2026/3/10/%D8%A7%D9%84%D9%86%D9%82%D9%84-%D8%A7%D9%84%D8%B9%D8%A7%D9%85-%D8%A8%D8%A7%D9%84%D8%A5%D8%B3%D9%83%D9%86%D8%AF%D8%B1%D9%8A%D8%A9-%D9%84%D8%A7-%D8%B2%D9%8A%D8%A7%D8%AF%D8%A9-%D9%81%D9%89-%D8%AA%D8%B9%D8%B1%D9%8A%D9%81%D8%A9-%D8%A7%D9%84%D8%A3%D8%AA%D9%88%D8%A8%D9%8A%D8%B3%D8%A7%D8%AA-%D8%A7%D9%84%D8%AA%D8%A7%D8%A8%D8%B9%D8%A9-%D9%84%D9%84%D9%87%D9%8A%D8%A6%D8%A9/7336161)); Al-Mal ([link](https://almalnews.com/2080813/)) | Reported | Low–medium: two real fares are better than the heuristic for those lines. No full APTA table found. |
| 12 | Alexandria microbus tariff | March 2026 tariff (`alex_fares.json`) | The governorate's March 2026 table is published as a PDF by Al-Gomhuria | [Al-Gomhuria PDF](https://algomhuria.gomhuriaonline.com/wp-content/uploads/2026/03/%D8%AA%D8%B9%D8%B1%D9%8A%D9%81%D8%A9-%D8%A7%D9%84%D8%B1%D9%83%D9%88%D8%A8-%D9%85%D8%A7%D8%B1%D8%B3-202617-Copy-1.pdf) | Primary-ish (official table, newspaper copy) | Cross-check `alex_fares.json` against it; the backend cites shbabbek/masrawy republications. |

## 3. Sources, ranked by value and safety

"Commercial use" means use in Guidy as it is: free, ad-supported (AdMob).

### 3.1 Transport for Cairo (TfC)

| Dataset | URL | Date / coverage | Format | Licence | Commercial use | Notes |
|---|---|---|---|---|---|---|
| Greater Cairo road GTFS (document 88, Mobility Database `mdb-3355` "Agyad GTFS Schedule Feed") | data.transportforcairo.com document 88; [mobilitydatabase.org/feeds/gtfs/mdb-3355](https://mobilitydatabase.org/feeds/gtfs/mdb-3355) | Fieldwork 2019–2023, updated Oct 2025; service dates 2025-01-01 to 2025-12-31; 1,011 routes, all route_type 3 | GTFS | Labels disagree: CC BY-NC-SA 2.0 (Mobility Database), CC BY-NC 4.0 (other listings); TfC's GTFS page: commercial use needs a separate licence | **Not under the public licence.** Guidy has TfC's written approval per the backend's `DEPLOYMENT.md` | This looks like the base of Guidy's Cairo network (1,033 TfC-agency routes in the feed). Worth a diff against document 88's latest version: route additions and changed stops since Guidy's copy. Mobility Database re-downloads daily, so it can show when TfC republishes. |
| Cairo Metro GTFS (2022) | data.transportforcairo.com document 42 | Jul 2022, Lines 1–3 | GTFS | CC BY-NC 4.0 | Only under the TfC permission | Superseded by Guidy's own rail rows (Line 3 is complete in the feed). Low value. |
| Digital Cairo 2017 | [github.com/transportforcairo/Transit---GCR-Digital-Cairo-2017-](https://github.com/transportforcairo/Transit---GCR-Digital-Cairo-2017-) | Fares as of June 2018 | GTFS, shapefiles | CC BY-NC 4.0, with required credit text | Only under the TfC permission | Old. No value over document 88. |
| Alexandria GTFS (document 92) | data.transportforcairo.com document 92 | Field survey 4–14 Dec 2022 | GTFS | Portal shows none; backend says CC BY 4.0 | Unclear until confirmed (finding #6) | Already used. |
| Alexandria terminals (dataset 12) and route frequencies (dataset 91) | data.transportforcairo.com | 2022 survey | GIS layers | None listed | Same as above | Already used for the `ALX_TT_` lines. |

### 3.2 OpenStreetMap and Overpass

- **What:** route relations (`route=bus|minibus|share_taxi|subway|monorail|light_rail|tram|train`), stations, busways, footpaths. Overpass API for queries, Geofabrik for the Egypt extract.
- **Licence:** ODbL 1.0, © OpenStreetMap contributors ([openstreetmap.org/copyright](https://www.openstreetmap.org/copyright)). **Commercial use is allowed**, with attribution where the data is shown or used, and share-alike for a publicly used derivative database. Routing on OSM (OSRM) and showing results is a "produced work": attribution only.
- **Reliability for Cairo:** high for rail, poor for road transit. The backend's own Overpass pulls (9 Sep 2026, `osm_mode_*.json`) found 1 bus relation and 0 minibus or share-taxi relations in its Greater Cairo box, against 8 subway, 4 monorail and 8 train relations. OSM will not enrich Cairo's microbus network. It is still the best open geometry for new rail and BRT (the BRT phase 1 busway in `data/brt_phase1_busway.json` came from OSM ways).
- **Value:** medium, safe. Re-pull the BRT busway after phase 2 is mapped; check new OSM station nodes for BRT phase 2 and LRT phase 3.
- Already used by Guidy: walking routes (OSRM on the Geofabrik extract), rail station sequences (`scripts/feeds/build_rail_lines.py`), BRT busway, Alexandria names and landmarks.

### 3.3 Official operators and governorates

| Publisher | What | Licence | Commercial use | Value |
|---|---|---|---|---|
| Ministry of Transport / NAT (metro, monorail, LRT, BRT announcements) | Openings, fares, hours | Public announcements, facts | Facts (fares, station names, hours) can be used; don't copy text or maps | High: the authoritative source for #2, #3, #7 |
| Cairo Governorate portal ([cairo.gov.eg](https://www.cairo.gov.eg/en/governorate-services/transportation-services/light-electric-train/)) | Bus routes (already used as `GOV_CTA*`), LRT page, tariffs | Not stated | Facts only | High for fares (#1, #4, #5) |
| Giza Governorate | Microbus tariffs per line | Not stated | Facts only | Medium (#5) |
| Alexandria Passenger Transport Authority ([alexapta.gov.eg](https://alexapta.gov.eg/)) | Bus line list (already used) | Not stated | Facts only | Already used; no fare table found |
| Alexandria Governorate | March 2026 microbus tariff | Not stated | Facts only | Already used (#12) |

### 3.4 Network status, 2025–2026 (facts for the app and the site)

- **Cairo Metro Line 3:** complete, both western branches (Rod El-Farag Corridor and Cairo University) in the feed.
- **Line 1:** a new Sheikh Mansour station is under construction between Ezbet El-Nakhl and El-Marg (Scene Now, May 2026, [link](https://scenenow.com/Buzz/Construction-Begins-on-New-Sheikh-Mansour-Metro-Station)). Not open.
- **Line 4:** first phase (19 km, 17 stations incl. a Pyramids station) due in the first half of 2028 (NAT via Daily News Egypt, 28 Apr 2026, [link](https://www.dailynewsegypt.com/2026/04/28/cairo-metro-line-4-first-phase-to-open-in-2028-as-tunnelling-milestone-reached/); IRJ, [link](https://www.railjournal.com/passenger/metros/cairo-metro-line-4-opening-announced/)). Not open.
- **East Nile Monorail:** phase 1 (16 stations, Field Marshal Tantawi – Justice City) opened 6 May 2026; phase 2 (6 stations to Cairo Stadium) 27 Jun 2026; 22 stations, 06:00–21:00. In the feed.
- **LRT:** see #7, #8.
- **Ring Road BRT:** phase 1 trial from 1 Jun 2025 (Daily News Egypt, [link](https://www.dailynewsegypt.com/2025/06/01/egypt-launches-trial-operation-of-cairo-ring-road-brt-first-phase/)); phase 2 from 26 Sep 2026 (#2). Phase 3: no date.
- **Alexandria Raml tram:** service fully suspended on 1 Apr 2026 for conversion to a light-rail-style line; replacement buses and microbuses on the Corniche, a parallel road and Abu Qir St. Reopening given as end 2027 (government) or end 2028 (contractor ETF). (Reuters via US News, 29 Jan 2026, [link](https://www.usnews.com/news/world/articles/2026-01-29/historic-alexandria-tramway-prepares-to-shut-ahead-of-contested-overhaul); Egyptian Streets, [link](https://egyptianstreets.com/2026/02/02/alexandria-metro-and-raml-tram-undergo-major-overhaul/); ETF, [link](https://www.etf.fr/en/actualites-en/etf-egypt-remporte-un-contrat-pour-la-rehabilitation-du-tramway-al-raml-dalexandrie/).) Guidy has no tram: correct. The replacement services, if their routes are published, are worth adding.
- **Alexandria city tram (Victoria / Mansheya lines):** status not researched in depth; not in the feed.
- **Abu Qir metro (Alexandria Metro phase 1):** 20 stations, Abu Qir – Misr Station; trial March 2027, opening around May 2027; first trains due Dec 2026 (AIIB monitoring report, Mar 2026, [link](https://www.aiib.org/en/projects/details/2026/_download/Egypt/PIMR_SBF_Egypt_P000207_Alexandria-Abou-Qir-Metro-Line-Project_No3_March_2026_Public-Version.pdf); Cairoscene, Jun 2026). Not open; the old Abu Qir suburban train is closed for the conversion.

### 3.5 Aggregators

- **Mobility Database:** lists TfC's Cairo road feed (`mdb-3355`, predecessor `mdb-1825`). Useful as a change monitor, not a separate source. Licence is whatever TfC's is.
- **Transitland:** no Egypt-specific feed was found in search; not verified (site not reachable from here).
- **TUMI Data Hub** ([hub.tumidata.org](https://hub.tumidata.org/dataset/?tags=Egypt)): mirrors old TfC feeds and says its licence info may be out of date. No value over TfC.

## 4. Recommended order

1. CTA bus fares 13 / 25 (#1). Confirmed, large error, simple constant change; decide whether to model the July 2026 distance tiers for card riders (they need stop counts per line).
2. Ask TfC to confirm the Alexandria licence or that the permission covers it (#6).
3. BRT phase 2 (#2), once there is an official station list.
4. Cairo/Giza per-line microbus and minibus tariffs (#4, #5), starting with the busiest terminals.
5. Diff Guidy's Cairo network against TfC document 88's latest version (3.1).
6. Monorail feed hours (#3), a tidy-up.
7. Watch: LRT phase 3, Raml tram replacement routes, Abu Qir metro (2027), Line 4 (2028).

Guidy — Intelligent Public Transit Navigation App 🚐📍

is now on Play Store : https://play.google.com/store/apps/details?id=com.guidy.guidy_app Website : https://www.guidyapp.com

A cross-platform mobile application bridging Cairo's informal public transit data gap by mapping undocumented microbus networks and optimizing multi-modal journeys.

[https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter] [https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart] [https://img.shields.io/badge/Backend-FastAPI-009688?logo=fastapi] [https://img.shields.io/badge/Maps-OpenStreetMap-7EBC6F?logo=openstreetmap] [https://img.shields.io/badge/License-MIT-yellow.svg]


📌 Problem Overview
In Greater Cairo, informal microbuses account for roughly 63% of daily motorized transit trips, yet they remain virtually undocumented and digitally invisible. Commuters frequently face:

Information Scarcity: Reliance on asking passersby or word-of-mouth.
Unpredictable Travel Cost & Time: High travel impedance and traffic bottlenecks.
Lack of Multi-Modal Integration: No unified platform integrating formal transit (Metro, public buses) with informal microbuses.

🚀 Key Features
Multi-Objective Dynamic Routing:

⚡ Fastest Route: Prioritizes minimum travel time and avoids congestion.

💰 Cheapest Route: Minimizes financial fare cost, tailored for price-sensitive commuters.

⚖️ Regular Route: Balanced trade-off between time, fare, and transfer penalty.
Informal Network Mapping: Digitizes informal microbus routes into a graph topology using GPS data.
Dynamic Congestion ("Jam Factor"): Incorporates real-time congestion scores (0.0–10.0) into the cost function to re-route around bottlenecks.
Community Crowdsourcing:
Incident Reporting: Real-time crowd reports for accidents, jams, and fare changes verified via a user Trust Score algorithm.
"Record My Trip": Passive GPS logging to discover and map new, unrecorded route corridors.
Zero-Cost / High-Control Mapping Stack: OpenStreetMap (via flutter_map), TomTom Routing API for walking segments, and Photon Geocoding API.
Jank-Free 60 FPS UI: Utilizes selective state management (ValueNotifier<LatLng?> / ValueListenableBuilder) to isolate GPS marker updates without rebuilding map tiles or polyline layers.

🏗️ Architecture & Core Logic
1. Algorithmic Pathfinding
Engine: Multi-objective, time-weighted Dijkstra search over a directed graph 
G
(
V
,
E
)
 built from GTFS feeds and seeded microbus routes.
Generalized Travel Cost (Impedance): 
Score
=
(
W
1
×
Time
)
+
(
W
2
×
Cost
)
+
(
W
3
×
Congestion
)
+
(
W
4
×
Transfers
)
+
(
W
5
×
Incident Penalty
)

2. Tech Stack
Frontend (Mobile App): Flutter (Dart), flutter_map, OpenStreetMap tiles, TomTom Routing API.
Backend Core: Python, FastAPI, NetworkX graph modeling.
Real-Time Data: Firebase Realtime Database & Firebase Cloud Messaging (FCM).

📱 App UI Screenshots
Home Screen & Search: Location-aware origin/destination geocoding via Photon.
Route Comparison: Side-by-side breakdown of duration, fare in EGP, and transit modes.
Live Turn-by-Turn: Street-level routing with live GPS tracking and incident overlay.
Incident Reporting: Fast one-tap incident submissions (Heavy Traffic, Accidents, Road Closures).

🛠️ Getting Started
Prerequisites
Flutter SDK (3.x or higher)
Android Studio / Xcode
Git

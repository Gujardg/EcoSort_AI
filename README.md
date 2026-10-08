# EcoSort AI – Smart Waste Collection & Recycling Platform

> An end-to-end AI-powered platform that transforms urban waste management through intelligent classification, predictive scheduling, and real-time chain-of-custody tracking.

---

## Overview

EcoSort AI connects households, waste collectors, recycling centers, and city administrators in a unified digital ecosystem. Citizens scan their waste items to get an instant AI classification, schedule a pickup, and earn eco-points — while administrators get real-time demand forecasting, staffing recommendations, and route optimization powered by machine learning.

### 0.1 Prediction-Driven Assignment Engine

At the core of EcoSort AI is a multi-signal delay risk model. Every pickup request is scored for delay probability based on:

- **Collector historical punctuality** (rolling 30-day completion rate)
- **Zone congestion forecast** (traffic + request density heatmaps)
- **Weather data integration** (via API at scheduling time)
- **Time-of-day and day-of-week patterns** (learned from historical data)

Requests with high delay risk are **automatically re-ranked** in the assignment queue, escalated to human reviewers, and trigger **pre-emptive staffing alerts** — proposing additional collectors before the problem manifests. This shifts the operational model from *reactive* to *proactive*.

### 0.2 End-to-End Item-Level Chain of Custody

Every waste item scanned through the EcoSort app receives a unique audit trail:

1. **AI Scan** – Image classified by the Flask ML model (category + confidence score logged)
2. **Pickup Assignment** – Collector and pickup ID linked to the item record
3. **Collection Confirmation** – Collector marks items collected; weight and condition logged
4. **Delivery to Recycling Center** – Recycling center confirms receipt and material grade
5. **Processing Verification** – Final recycling outcome recorded

At every stage, an immutable log entry is written. Any discrepancy (e.g., collector marks "collected" but recycling center never receives) surfaces as an automatic audit flag. Users can view their item's journey from scan to recycled output, building trust and accountability.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | HTML5, CSS3, Vanilla JavaScript, Three.js r128 |
| **Backend / DB / Auth** | Supabase (PostgreSQL, Row Level Security, Realtime, Supabase Auth) |
| **AI / ML** | Python 3.x, Flask, scikit-learn, pandas, numpy |
| **Charts** | Chart.js (CDN) |
| **3D UI** | Three.js r128 (CDN) |
| **Auth Flow** | Supabase JWT + RLS policies + role-based routing |

---

## Project Structure

```
HACK/
├── css/
│   ├── style.css            # Global styles, design tokens
│   ├── dashboard.css        # Dashboard-specific layouts
│   ├── forms.css            # Form components
│   └── responsive.css       # Breakpoints and mobile styles
│
├── js/
│   ├── supabase.js          # Supabase client initialisation + DB export
│   ├── auth.js              # Auth guards, requireRole(), signOut()
│   └── utils.js             # Shared utilities (toasts, formatting, etc.)
│
├── user/
│   ├── dashboard.html       # User home – request history, eco points
│   ├── scan.html            # AI waste scanner (camera / upload)
│   ├── request-pickup.html  # New pickup request form
│   ├── my-pickups.html      # Track active & past pickups
│   ├── eco-points.html      # Eco points wallet & rewards
│   └── profile.html         # User account settings
│
├── collector/
│   ├── dashboard.html       # Collector home – assigned queue
│   ├── my-assignments.html  # Full pickup assignment list
│   ├── pickup-detail.html   # Individual pickup detail & chain-of-custody
│   └── profile.html         # Collector profile & availability toggle
│
├── recycling-center/
│   ├── dashboard.html       # Recycling center operations overview
│   ├── incoming.html        # Incoming deliveries from collectors
│   ├── process-batch.html   # Log processed batches by category
│   └── profile.html         # Center profile & capacity settings
│
├── admin/
│   ├── dashboard.html       # Admin command center
│   ├── pickup-requests.html # All pickup requests + assignment tools
│   ├── users.html           # User management
│   ├── collectors.html      # Collector management + performance
│   ├── recycling-centers.html
│   ├── waste-categories.html
│   ├── collection-centers.html   # Physical drop-off point management
│   ├── predictions.html          # AI prediction log & correction tracking
│   ├── analytics.html            # Platform-wide analytics (6 charts)
│   ├── staffing-alerts.html      # Proactive staffing recommendation feed
│   ├── activity-logs.html        # Full system audit log
│   └── notifications.html        # Admin notification center
│
├── python/
│   ├── app.py               # Flask API server (entry point)
│   ├── requirements.txt     # Python dependencies
│   ├── training/
│   │   ├── train_models.py  # Train all ML models
│   │   └── datasets/        # Training CSV data
│   └── models/              # Saved scikit-learn model files (.pkl)
│
├── index.html               # Landing + login page
└── README.md                # This file
```

---

## Quick Start

### Prerequisites

- **Python 3.8+** (for the Flask ML API)
- **Internet connection** (for CDN assets: Three.js, Chart.js, and Supabase)
- A modern browser (Chrome, Firefox, Edge)

> **Note:** The frontend runs in **LocalStorage fallback mode** if Supabase is not configured. All features work with seeded demo data out of the box.

---

### 1. Install Python Dependencies

```bash
cd python
python -m pip install -r requirements.txt
```

**Key packages installed:**
- `flask` + `flask-cors` – REST API server
- `scikit-learn` – ML models (RandomForest, GradientBoosting)
- `pandas` + `numpy` – Data processing
- `pillow` – Image preprocessing for waste classification
- `joblib` – Model serialisation

---

### 2. Train the ML Models

```bash
python training/train_models.py
```

This script trains and saves the following models to `python/models/`:

| Model | File | Purpose |
|---|---|---|
| Waste Classifier | `waste_classifier.pkl` | Image category prediction |
| Delay Predictor | `delay_predictor.pkl` | Pickup delay risk scoring |
| Demand Forecaster | `demand_forecaster.pkl` | Zone-level demand projection |
| Collector Ranker | `collector_ranker.pkl` | Best-fit collector recommendation |

> Training completes in ~30–60 seconds on a standard laptop.

---

### 3. Start the Flask API Server

```bash
python app.py
```

The API will start at **http://localhost:5000**

You should see:
```
 * Running on http://127.0.0.1:5000
 * EcoSort AI Flask API ready
```

---

### 4. Serve the Frontend

Open a **second terminal** from the project root directory:

```bash
python -m http.server 8080
```

Then open **http://localhost:8080** in your browser.

> Alternatively, open `index.html` directly in your browser (some features may require the HTTP server for CORS compatibility).

---

## Demo Login Credentials

The platform uses **role-based access control**. Use these credentials to explore each role. Any password is accepted in LocalStorage demo mode.

| Role | Email | Password | Access |
|---|---|---|---|
| **User** | `user@ecosort.ai` | `any` | User dashboard, scan, pickup requests, eco points |
| **Collector** | `collector@ecosort.ai` | `any` | Collector dashboard, assignment queue, pickup detail |
| **Recycling Center** | `recycling@ecosort.ai` | `any` | Incoming deliveries, batch processing |
| **Admin** | `admin@ecosort.ai` | `any` | Full admin panel, all data, analytics |

---

## API Endpoints

All endpoints are served by the Flask server at `http://localhost:5000`.

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/health` | Server health check and model status |
| `POST` | `/api/classify-waste` | Classify waste from image (base64 or multipart) |
| `POST` | `/api/predict-delay` | Score a pickup request for delay risk (0–1) |
| `POST` | `/api/predict-demand` | Forecast pickup demand by zone and time window |
| `POST` | `/api/rerank-queue` | Re-rank pickup queue by urgency + delay risk |
| `POST` | `/api/staffing-recommendations` | Generate collector staffing recommendations |
| `POST` | `/api/recommend-collector` | Recommend best collector for a specific pickup |
| `POST` | `/api/ai-corrections` | Submit human correction for a prediction (feedback loop) |
| `POST` | `/api/optimize-route` | Generate optimised route for a collector's assignments |
| `POST` | `/api/chat-assistant` | Multilingual chatbot for user queries |
| `GET` | `/api/activity-logs` | Retrieve paginated system activity log entries |

### Example: Classify Waste

```bash
curl -X POST http://localhost:5000/api/classify-waste \
  -H "Content-Type: application/json" \
  -d '{"image_base64": "<base64_string>", "user_id": "user-123"}'
```

**Response:**
```json
{
  "category": "Plastic",
  "confidence": 0.92,
  "prediction_id": "PRED-0041",
  "alternatives": [
    {"category": "E-Waste", "confidence": 0.05},
    {"category": "Metal",   "confidence": 0.03}
  ]
}
```

---

## Supabase Setup (Optional)

The app runs fully in **LocalStorage demo mode** without Supabase. To enable real authentication and persistent data:

### 1. Create a Supabase Project

1. Go to [https://supabase.com](https://supabase.com) and create a free project
2. Note your **Project URL** and **Anon Key** from Project Settings → API

### 2. Configure the Client

Edit `js/supabase.js` and replace the placeholder values:

```js
const SUPABASE_URL  = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_ANON = 'YOUR_ANON_KEY_HERE';
```

### 3. Run the SQL Schema

In the Supabase SQL Editor, run the schema file:

```
python/supabase_schema.sql
```

This creates all required tables with RLS policies:

- `profiles` – User profiles with role field
- `pickup_requests` – Pickup request records with full lifecycle
- `collectors` – Collector records and availability
- `recycling_centers` – Recycling center details
- `collection_centers` – Physical drop-off point data
- `waste_categories` – Waste category configuration
- `ai_predictions` – AI classification prediction log
- `eco_points` – User eco point transactions
- `notifications` – System notification records
- `activity_logs` – Full system audit trail
- `chain_of_custody` – Item-level tracking events

### 4. Enable Realtime

In Supabase Dashboard → Database → Replication, enable realtime for:
- `pickup_requests`
- `notifications`
- `staffing_alerts`

---

## Features

| Feature | Description |
|---|---|
| 🤖 **AI Waste Classification** | Camera or upload-based image classification with confidence scoring and correction feedback loop |
| 🔗 **Chain of Custody Tracking** | Immutable item-level audit trail from AI scan through collection to recycling |
| ⚡ **Delay Risk Prediction** | ML model scores every pickup for delay probability; high-risk items are auto-escalated |
| 🌟 **Eco Points System** | Users earn points for verified pickups; redeemable for rewards |
| 💬 **Multilingual Chatbot** | AI assistant supports multiple languages for user guidance |
| 🎮 **3D Three.js UI** | Interactive 3D visual elements on the landing page using Three.js r128 |
| 📊 **Real-Time Analytics** | 6-chart analytics dashboard with live KPIs, Chart.js visualisations |
| 🚦 **Proactive Staffing Alerts** | Pre-emptive staffing recommendations generated before shortfalls occur |
| 🗺️ **Route Optimisation** | Optimal collector routing via Flask API (nearest-neighbor + demand weighting) |
| 📍 **Collection Center Management** | Admin management of physical drop-off points with fill-level monitoring |
| 🔒 **Role-Based Access Control** | Four distinct roles (User, Collector, Recycling Center, Admin) with RLS enforcement |
| 📱 **Responsive Design** | Fully responsive across desktop, tablet, and mobile viewports |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    BROWSER (Frontend)                    │
│  HTML/CSS/JS  ·  Three.js  ·  Chart.js  ·  Supabase JS │
└──────────────────────┬──────────────────────────────────┘
                       │  REST (localhost:5000)
                       ▼
┌─────────────────────────────────────────────────────────┐
│               Flask API Server (Python)                  │
│  /classify-waste · /predict-delay · /recommend-collector │
│  scikit-learn models · pandas · numpy · Pillow           │
└──────────────────────┬──────────────────────────────────┘
                       │  Supabase SDK / PostgREST
                       ▼
┌─────────────────────────────────────────────────────────┐
│                  Supabase (Backend)                      │
│  PostgreSQL · Row Level Security · Auth · Realtime       │
└─────────────────────────────────────────────────────────┘
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m "feat: add my feature"`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

## License

MIT License — see `LICENSE` for details.

---

*Built with 💚 for a greener planet.*

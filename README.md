# HealthFlow 🌾

A Flutter-based personal healthcare and wellness application designed to help users manage their health, nutrition, and workout activities in one place.

HealthFlow aims to provide a simple and centralized way for users to record health metrics, track daily nutrition, manage workout progress, and view an overall summary through a personalized dashboard.

> **Academic Project**
> Developed as part of a Mobile Application Development course at Ho Chi Minh City University of Industry and Trade (HUIT).

---

## 📱 Project Overview

Managing personal health often involves tracking different types of information such as body measurements, blood pressure, meals, calories, and exercise activities.

HealthFlow brings these activities together into a single mobile application. 
Currently, the project focuses on delivering a rich, interactive user interface built with Flutter, using an **In-Memory Data Store** to simulate backend and local storage interactions.

The application is designed around four main areas:

* **Account Management** – Registration, login, and personal profile management.
* **Health Tracking** – Recording and monitoring personal health metrics.
* **Nutrition** – Managing meals, calories, and macronutrients.
* **Workout** – Browsing exercises and recording completed workouts.

A centralized **Dashboard** provides a quick overview of the user's recent health and wellness data.

---

## ✨ Features

### 🔐 Authentication & Profile

* User registration and login (Mocked with InMemory store)
* Personal profile management
* Health goal configuration
* Daily calorie goal
* Personal information such as height and current weight

### ❤️ Health Tracking

Users can record and monitor health-related data, including:

* Weight
* Blood pressure
* Heart rate
* Blood glucose
* Sleep
* Daily steps

The system can calculate **BMI** based on height and weight and display changes in health metrics over time.

### 🍎 Nutrition Tracking

* Search for food items
* Select meal type (Breakfast, Lunch, Dinner, Snack)
* Record food portions
* View daily nutrition summaries (Calories, Protein, Carbohydrates, Fat)
* Compare nutrition intake with daily goals

### 🏋️ Workout Tracking

* Browse available workouts
* Track workout duration and calories burned

### 📊 Dashboard

The Dashboard acts as the central hub of the application.

It is designed to provide a quick overview of:

* Recent health metrics
* BMI
* Daily calorie progress
* Nutrition summary
* Workout progress

---

## 🏗️ Architecture

HealthFlow is designed with a layered architecture to separate UI, application state, and data access.

```text
┌──────────────────────────────┐
│             UI               │
│       Screens / Widgets      │
└──────────────┬───────────────┘
               │
┌──────────────▼───────────────┐
│      State Management        │
│     ChangeNotifier           │
└──────────────┬───────────────┘
               │
┌──────────────▼───────────────┐
│         Repository           │
│   Data & Business Access     │
└──────────────┬───────────────┘
               │
┌──────────────▼───────────────┐
│      In-Memory Stores        │
│    (Mock Data Storage)       │
└──────────────────────────────┘
```

This structure is intended to make the project easier to maintain and extend later when a real backend or database is integrated.

---

## 🛠️ Tech Stack

### Frontend

* Flutter
* Dart
* Material Design

### State Management & Data

* Provider / ChangeNotifier
* In-Memory Collections (simulating database)

> **Note**: Firebase and SQLite integrations are planned for future phases. The current version runs fully in-memory and resets state upon restart.

---

## 📂 Project Structure

The project structure is organized by responsibility:

```text
lib/
├── main.dart
│
├── data/
│   ├── account_store.dart
│   ├── auth_repository.dart
│   ├── health_repository.dart
│   ├── health_store.dart
│   ├── nutrition_repository.dart
│   ├── nutrition_store.dart
│   ├── workout_repository.dart
│   └── workout_store.dart
│
├── models/
│   ├── health_metric.dart
│   ├── nutrition.dart
│   ├── user.dart
│   └── workout.dart
│
├── screens/
│   ├── add_food_screen.dart
│   ├── health_screen.dart
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── main_screen.dart
│   ├── nutrition_screen.dart
│   ├── register_screen.dart
│   ├── settings_screen.dart
│   ├── welcome_screen.dart
│   └── workout_screen.dart
│
├── theme/
├── utils/
└── widgets/
```

---

## 🚀 Development Roadmap

### Phase 1 — Analysis & Design ✅
* UI/UX planning and requirement analysis.

### Phase 2 — Flutter UI Development ✅
* Complete navigation structure.
* Authentication, Dashboard, Health, Nutrition, and Workout screens.
* In-memory mocked data layer.

### Phase 3 — Data Integration 🚧 (Next up)
* SQLite / Sqflite integration
* Firebase Authentication & Cloud Firestore

---

## ⚠️ Disclaimer

HealthFlow is an academic software project intended for personal health tracking and educational purposes.
The application is **not intended to diagnose, treat, or replace professional medical advice**.

---

## 📄 License

This project was created for educational and academic purposes.

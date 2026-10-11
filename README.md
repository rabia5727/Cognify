# Cognify: AI Powered Execution Hub for Productive Workflow Balance

Final Year Project, Department of Software Engineering, IISAT University
Group ID: SE-014 | Supervisor: Miss Amina Saba (HOD Software Engineering)

Team: Taiba Asif (1220100006), Rabia Noor (1220100614)

---

## About the project

Cognify is a mobile app for students who also work as freelancers. It brings
academic tasks and freelance work into one place and includes CoCo, an AI
assistant that helps users plan, prioritize and execute their work, using both
voice and touch.

**Main features**
- Voice and text task management (create, view, update, delete)
- CoCo AI assistant with specialized agents (Task, Execution, Scheduler, Analytics, Document)
- Proactive reminders and notifications
- Document generation and email drafting
- Google integration: Sign-In, Gmail, Drive, Classroom (External Data Sync)
- Dashboard with productivity analytics

## Tech stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter 3.32+ (Provider, fl_chart, flutter_tts) |
| Backend | Python 3.11, FastAPI |
| Database | MongoDB Atlas (Motor async driver) |
| AI | LangChain, Groq API (LLM), local Whisper (speech to text) |
| Scheduler | APScheduler |
| Auth | Google OAuth 2.0, Firebase |

## Project structure

```
Cognify/
  backend/        FastAPI server, AI agents, database code
  frontend/       Flutter mobile app
  requirements.txt  Python dependencies (install from this folder)
  README.md
```

## Requirements

Install these first:
- Python 3.11 ([python.org](https://www.python.org/downloads/))
- Flutter SDK 3.32 or newer ([flutter.dev](https://docs.flutter.dev/get-started/install)) with Android Studio
- Git
- A MongoDB Atlas account (free tier works)
- A Groq API key ([console.groq.com](https://console.groq.com))
- A Google Cloud project with OAuth credentials (only needed for Google features)
- An Android phone or emulator

## Backend Setup

1. Open a terminal in the project root folder (the folder that contains
   `backend` and `frontend`).

2. Create and activate a virtual environment:
```
   python -m venv venv
   venv\Scripts\activate
```

3. Install dependencies:
```
   pip install -r requirements.txt
```

4. Go to the backend folder, copy `.env.example` to `.env`, and fill in your
   own keys (Groq API key and your MongoDB Atlas connection string):
```
   cd backend
   copy .env.example .env
```

5. Start the server from the backend folder:
```
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

6. Open http://localhost:8000/docs to confirm the server is running.

## Frontend Setup

1. Open a new terminal, go to the frontend folder and install packages:
```
   cd frontend
   flutter pub get
```

2. Set the backend URL in the app's config file to your computer's address,
   for example `http://10.0.2.2:8000` for an Android emulator.

3. Run the app:
```
   flutter run
```

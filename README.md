# 🏦 FinTrust Agent

FinTrust Agent is a digital financial management and AI-assisted application designed for informal lending and savings groups (like Chamas, Esusus, and worker associations). 

Our core mission is to eliminate language barriers, enforce absolute financial accountability via an immutable ledger, and improve transparency for all group members.

---

## 🚀 Core Features

* **Immutable Financial Ledger:** Automated tracking of contributions, loans, repayments, and penalties with zero-deletion accounting records.
* **Role-Based Access Control (RBAC):** Distinct dashboards and security clearances for Chairmen, Treasurers, and general Members.
* **AI/ML Multilingual Agent:** A conversational interface powered by Google Gemini that understands local African languages (e.g., Swahili, Yoruba, Zulu).
* **Bylaw Mediation (RAG):** The AI answers member questions and helps resolve disputes based directly on the group's specific constitution.

---

## 🛠️ The Tech Stack (Free Tier)

* **Frontend & API:** Next.js (React) hosted for free on **Vercel**
* **Database:** PostgreSQL with Row Level Security hosted on **Supabase**
* **AI Layer:** Google AI Studio (**Gemini API**) & `pgvector` for memory embeddings

---

## ⚙️ How to Set Up Locally

### 1. Prerequisites
You will need a free GitHub account, a Supabase project, and a Google AI Studio API key.

### 2. Configuration
Create a `.env.local` file in the root directory of the project and add your credentials:

```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
GEMINI_API_KEY=your_gemini_api_key

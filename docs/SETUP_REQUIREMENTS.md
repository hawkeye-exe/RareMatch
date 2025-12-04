# RareMatch Setup Requirements (Supabase Edition)

To deploy the RareMatch system with Supabase, the following inputs are required.

## 1. Supabase Project
- **Project URL**: The REST URL of your Supabase project.
- **Anon Key**: The public anonymous key for frontend usage.
- **Service Role Key**: The secret key for backend microservices (bypasses RLS).
- **Database Password**: For direct PostgreSQL connection (if needed).

## 2. AI & Machine Learning
- **Google AI API Key**: For accessing Gemini Pro.
  - *Get it here*: [Google AI Studio](https://makersuite.google.com/app/apikey)

## 3. External Services
- **SendGrid API Key**: For sending transactional emails (optional, Supabase handles Auth emails).
- **Stripe API Key**: For processing payments.
- **Sentry DSN**: For error tracking.

## 4. Application Details
- **App Name**: (Default: RareMatch)
- **Package Name**: (Default: `com.rarematch.app`)

---

## Quick Start (Development)
We can proceed with **mock values** for now.
- **Supabase**: I will set up the code to expect Supabase env vars. You will need to create a free Supabase project and plug in the keys later.

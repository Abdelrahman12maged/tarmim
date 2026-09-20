# 📱 Tarmeem | The Smart Cloud Platform for Device Repair Shop Management

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Flutter%20%7C%20Android%20%7C%20iOS%20%7C%20Web-02569B?logo=flutter" alt="Platform" />
  <img src="https://img.shields.io/badge/Database-Cloud%20Firestore%20(Multi--Tenant)-FFCA28?logo=firebase" alt="Firebase" />
  <img src="https://img.shields.io/badge/Storage-Supabase%20Storage-3ECF8E?logo=supabase" alt="Supabase" />
  <img src="https://img.shields.io/badge/Architecture-Offline--First%20%26%20Cloud%20Sync-4CAF50" alt="Architecture" />
  <img src="https://img.shields.io/badge/Status-Production%20Ready-blue" alt="Status" />
</p>

---

## 💡 Elevator Pitch

**Tarmeem** is a complete cloud platform built specifically for phone, laptop, and electronics repair shop owners. It transforms workshop management from error-prone paper logs into a **fully automated, professional operation** — delivering a polished digital experience to customers while giving owners full control over revenue, branches, and inventory, anytime and from anywhere.

---

## 🌟 Why Repair Shops Choose Tarmeem (Customer Value Proposition)

| The Problem with Traditional Management ❌ | The Tarmeem Solution ✅ |
| :--- | :--- |
| **Lost paper receipts** and customer disputes over device condition or cost at drop-off. | **Instant digital receipt** with a permanent cloud tracking link and a precise intake inspection photo. |
| **Repeated customer calls**: *"Is my device ready yet?"* | **Live online tracking portal** — customers check real-time repair status using their ticket number or phone number. |
| **Difficulty overseeing multiple branches** without being physically present. | **Centralized multi-branch system** letting owners switch between branches or view total shop revenue with one tap. |
| **No visibility into real net profit** after wholesale parts costs. | **Advanced financial dashboard** that calculates wholesale cost, labor margin, deposits, and balances — while keeping parts pricing fully hidden from customers. |
| **Work stops when the shop loses internet.** | **Offline-first architecture** — devices can still be received and delivered with no connection, syncing automatically once back online. |

---

## 🚀 Feature Showroom

### 1. 📋 Smart Ticket Lifecycle & Inspection Documentation
- **Automatic sequential ticket numbers** for every device (e.g., `TR-1001`, `TR-1002`).
- **Cloud-based photo documentation:** capture the device's external condition (scratches, cracks, screen damage) and upload it to Supabase Storage — eliminating disputes at pickup.
- **Precise status tracking:**
  - 🟡 **Diagnostic Inspection**
  - 🟠 **Awaiting Spare Part**
  - 🟢 **Ready for Pickup**
  - 🔵 **Delivered to Customer**
  - 🔴 **Returned / Cancelled**

---

### 2. 🌐 Live Customer Tracking Portal
- A dedicated link for every device:
  `https://tarmim-769e5.web.app/track/TR-1001`
- **No login or app download required from the customer.**
- Shows the customer:
  - Current repair status and progress stages.
  - The intake inspection photo.
  - Financials (total cost, deposit paid, remaining balance).
  - Shop details (name, address, and one-tap call/message buttons).
- **Full privacy by design:** wholesale parts cost and technician margin are automatically hidden — customers only see the final approved price.

---

### 3. 💬 Official WhatsApp & SMS Notifications Suite
- **One-tap official WhatsApp messaging:** opens a pre-filled, professional message directly in the customer's WhatsApp — including repair details, invoice, and the live tracking link (100% safe, no third-party service that could risk the shop's number being banned).
- **Native SMS Gateway:** send SMS directly from the phone's SIM, with Dual SIM support and automatic background sending.

---

### 4. 🏢 Multi-Branch Management & Role-Based Access Control
- **Centralized owner control:**
  - The owner sees every branch (Main Branch, Maadi, Dokki, etc.).
  - Switch between branches or select **"View All Branches"** for a network-wide overview.
- **Complete data isolation per branch:**
  - Branch staff only see tickets and devices for their own branch; the branch switcher and subscription pages are automatically locked.
- **Flexible PIN-based login:**
  - Branches can share **the same shop phone number** — the system distinguishes owner vs. branch automatically via PIN code, with no need for extra SIM cards per branch.

---

### 5. 📊 Analytics & Financial Dashboard
- **Real-time workshop KPIs:**
  - Total revenue and true net profit after parts cost.
  - Devices completed, under inspection, and awaiting parts.
  - Average repair time and customer conversion rate.
- **Advanced period filtering:** detailed daily, weekly, monthly, and yearly reports to support business decisions and growth.

---

### 6. 🚨 Smart Alert & Operations Center
- An interactive notification bell that intelligently flags:
  - ⚠️ Devices that have exceeded their expected repair time.
  - 📦 Devices awaiting spare parts that need to be ordered from suppliers immediately.
  - 🔔 Devices ready for pickup for more than 48 hours without customer collection.

---

### 7. 👥 Customer CRM Directory
- A complete profile for every customer, including:
  - Phone numbers and address.
  - Full history of every device previously repaired at the shop.
  - Payment history and outstanding balances.
  - One-tap call and WhatsApp buttons directly from their profile.

---

### 8. 🎨 World-Class UX / UI Design System
- **Full native Arabic RTL support.**
- **Premium Dark Mode** for technicians working late, alongside a classic Light Mode.
- **Smart exit confirmation dialog** to prevent accidental app closure mid-task and protect data.

---

## 💎 Subscription Plans & SaaS Monetization Model

Built to be sold as a Software-as-a-Service product with a secure cloud licensing system:

```
┌───────────────────────────┐      ┌───────────────────────────┐      ┌───────────────────────────┐
│         Trial Plan        │      │       Pro Plan            │      │     Enterprise Plan       │
│                            │      │    (Single Shop)          │      │  (Multi-Branch Network)   │
├───────────────────────────┤      ├───────────────────────────┤      ├───────────────────────────┤
│ • 14 days free            │      │ • One main branch         │      │ • Unlimited branches      │
│ • Full feature access     │      │ • Unlimited tickets       │      │ • Independent branch      │
│ • Live tracking support   │      │ • WhatsApp & SMS tracking │      │   permissions             │
│ • Cloud sync              │      │ • Support & updates       │      │ • Consolidated financial  │
│                           │      │                           │      │   reports                 │
│                           │      │                           │      │ • Dedicated 24/7 support  │
└───────────────────────────┘      └───────────────────────────┘      └───────────────────────────┘
```

- **Instant activation via digital license keys:** single-use, prepaid license codes (`XXXX-XXXX-XXXX-XXXX`) can be generated to activate customer subscriptions with zero banking complexity.

---

## 📢 Ready-to-Use Sales & Marketing Copy

### 📣 Version 1: Targeting Repair Shop Owners (Facebook / TikTok Ads)
> **"Still logging repairs in a paper notebook while customers keep asking: 'Is it ready yet?' 📱🤦‍♂️"**
>
> Upgrade your shop today with **Tarmeem**, the most powerful cloud platform for managing phone and electronics repair centers:
>
> ✅ **Instant digital receipt with a live tracking link**, sent to your customer on WhatsApp with an inspection photo of their device.
> ✅ **Automatic WhatsApp notification** the moment a device is repaired — no third-party middleman involved.
> ✅ **See your real profit** after wholesale parts costs, calculated automatically.
> ✅ **Manage every branch from one account** and track your business from home.
> ✅ **Keeps working even when the internet is down!**
>
> 🎁 Try it free for 14 days and see the difference for yourself!
> 🔗 Live demo: [https://tarmim-769e5.web.app](https://tarmim-769e5.web.app)

---

### 📣 Version 2: Direct Sales Message (WhatsApp Outreach)
> Hey there 🤝
> If you run a repair shop or service center, we'd love to introduce you to **Tarmeem** — a system built specifically to organize repair operations and build customer trust.
> It gives you a free live tracking link for your customers, automatic WhatsApp notifications, and clear profit/cost calculations — no notebooks or messy spreadsheets — plus the ability to manage every branch from a single screen.
>
> Try the platform and check out the live demo here:
> 🌐 [https://tarmim-769e5.web.app](https://tarmim-769e5.web.app)

---

## 🛠️ Technical Stack

- **Framework:** Flutter 3.38+ (Dart 3.10+)
- **State Management:** BLoC / Cubit Architecture
- **Cloud Database:** Google Firebase Cloud Firestore (Multi-Tenant Schemas)
- **Cloud Storage:** Supabase Object Storage (public image buckets for inspection photos)
- **Local Storage:** Hive & SharedPreferences (offline-first caching engine)
- **Messaging:** Official WhatsApp Deep-Link Launcher + Android Native Telephony SMS
- **Hosting & Web:** Firebase Hosting (Progressive Web App with HTML5 history routing)

---

## 🚀 Quickstart

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/tarmim.git
   cd tarmim
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run static analysis:**
   ```bash
   flutter analyze
   ```

4. **Run on an emulator or device:**
   ```bash
   flutter run
   ```

5. **Build the production web release:**
   ```bash
   flutter build web --release
   ```

---

<p align="center">
  Built with care and passion to empower the electronics repair industry across the Arab world 🛠️❤️<br>
  <b>Tarmeem — Your Smart Partner in Running and Growing Your Workshop</b>
</p>

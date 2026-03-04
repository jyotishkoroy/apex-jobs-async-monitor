# Apex Jobs & Async Monitor

A polished Lightning Web Components (LWC) app that helps admins and developers **monitor Apex async activity** in Salesforce:
- **AsyncApexJob** dashboard (Queueable, Batch, Future, Scheduled Apex executions)
- **Scheduled jobs** dashboard (CronTrigger / CronJobDetail)
- **Error drill-down** via `ExtendedStatus` and job context
- Optional **Abort job** action (requires permission)

> No custom objects. No external dependencies. Works in any org that supports Lightning Experience.

---

## Screens / Features

### Overview
- High-level health counters: active jobs, failures, error-heavy jobs
- Quick filters and one-click refresh
- Auto-refresh (optional)

### Async Jobs
- Filter by status / job type / time window
- Search by job id / class name
- Drill into job details (status, progress, duration, error status)
- Export visible table to CSV

### Scheduled Jobs
- View scheduled jobs and their next/previous fire times
- Search by name / job type
- Export visible table to CSV

---

## Install

### Option A — Salesforce DX (recommended)
1. Clone the repo
2. Authenticate and deploy:
   ```bash
   sf org login web
   sf project deploy start
   ```
3. Assign the permission set:
   ```bash
   sf org assign permset --name Apex_Jobs_Async_Monitor
   ```
4. Open **App Launcher** → search **Apex Jobs & Async Monitor** (tab)  
   or place the component on a Home/App page via **Lightning App Builder**.

### Option B — Metadata API (package.xml)
1. Use `manifest/package.xml` and deploy with your preferred tool (VS Code, ANT, CI).
2. Assign the permission set `Apex_Jobs_Async_Monitor`.

---

## Permissions

This app reads **setup objects** like `AsyncApexJob` and `CronTrigger`. For a smooth experience:

- **Required:** `View Setup and Configuration`
- **Optional (for Abort):** `Manage Async Apex Jobs`

A permission set is provided:  
`force-app/main/default/permissionsets/Apex_Jobs_Async_Monitor.permissionset-meta.xml`

If a user lacks access, the UI shows a clear message and keeps the rest of the app stable.

---

## Supported Orgs

- Lightning Experience
- Enterprise / Unlimited / Developer / Sandbox
- Compatible with production orgs and scratch orgs
- No requirement for custom objects, named credentials, or external services

---

## Architecture

- **LWC UI** calls a thin Apex controller (`@AuraEnabled`)  
- Controller delegates to a service layer for:
  - query composition
  - DTO mapping
  - guard rails and friendly error handling
- Tests create real async records by running:
  - a Queueable job
  - a Batch job
  - a scheduled job

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT © 2026 Jyotishko Roy (https://orcid.org/0009-0000-2837-4731)  
See [LICENSE](LICENSE).

---

## Security

See [SECURITY.md](SECURITY.md).

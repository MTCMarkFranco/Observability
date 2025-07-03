# 🗓️ Full-Day Observability Walkthrough – Presenter Notes

---

## ⏰ 09:00 – 09:15 | Kickoff & Objectives

**Goal:** Set expectations and align on outcomes.

**Presenter Notes:**
- Introduce yourself as the Sr Hub Tech Architect.
- Share the agenda and emphasize the hands-on Azure Portal focus.
- Ask the customer about their current observability maturity and tools in use.

**Resources:**
- Slide 1: Agenda
- Slide 2: Customer goals alignment

---

## ⏰ 09:15 – 09:45 | What is Observability?

**Goal:** Establish foundational understanding.

**Presenter Notes:**
- Define observability vs. monitoring.
- Introduce the three pillars: logs, metrics, traces.
- Use real-world analogies (e.g., car dashboard vs. engine diagnostics).
- Emphasize why observability matters for cloud-native apps.

**Resources:**
- Slide deck: "Observability Overview"
- GitHub: [docs/best-practices-guide.md](docs/best-practices-guide.md)

---

## ⏰ 09:45 – 10:30 | Architecture Deep Dive

**Goal:** Show how observability components fit together.

**Presenter Notes:**
- Walk through your reference architecture (include App Insights, Log Analytics, Azure Monitor, OpenTelemetry).
- Highlight data flow: app → telemetry SDK → ingestion → analysis.
- Discuss integration points (e.g., AKS, App Services, Functions).

**Resources:**
- Architecture diagram (from repo or draw live)
- Azure Architecture Center (for reference)

---

## ⏰ 10:30 – 10:45 | ☕ Break

---

## ⏰ 10:45 – 12:00 | Azure Monitor & Log Analytics

**Goal:** Show how to collect and query telemetry.

**Presenter Notes:**
- Demo: Enable Azure Monitor on a resource group.
- Show how to connect to Log Analytics workspace.
- Use KQL to query logs (e.g., failed requests, performance bottlenecks).
- Explain retention, cost, and workspace design.

**Resources:**
- Azure Portal
- Sample KQL queries (from repo or create live)
- GitHub: any demo scripts or dashboards

---

## ⏰ 12:00 – 13:00 | 🍽️ Lunch

---

## ⏰ 13:00 – 14:00 | Application Insights

**Goal:** Instrument and analyze an app.

**Presenter Notes:**
- Demo: Enable App Insights on a sample web app.
- Show live metrics, dependency maps, and failure analysis.
- Discuss sampling, custom events, and telemetry correlation.

**Resources:**
- Azure Portal
- Sample app (from repo or Azure Quickstart)
- GitHub: any App Insights config or SDK examples

---

## ⏰ 14:00 – 14:45 | Distributed Tracing with OpenTelemetry

**Goal:** Show end-to-end traceability.

**Presenter Notes:**
- Explain OpenTelemetry and its role in vendor-neutral tracing.
- Demo: Trace a request across services using App Insights or Azure Monitor.
- Discuss instrumentation libraries and exporters.

**Resources:**
- GitHub: OpenTelemetry examples (if available)
- Azure Monitor Application Map
- OpenTelemetry Collector (optional)

---

## ⏰ 14:45 – 15:30 | Dashboards & Alerts

**Goal:** Visualize and act on telemetry.

**Presenter Notes:**
- Demo: Create a workbook dashboard with metrics and logs.
- Set up alerts for CPU, error rates, or custom events.
- Discuss action groups and integrations (email, Teams, Logic Apps).

**Resources:**
- Azure Portal
- GitHub: any workbook templates or alert rules

---

## ⏰ 15:30 – 15:45 | ☕ Break

---

## ⏰ 15:45 – 16:30 | Best Practices & Governance

**Goal:** Ensure scalable, secure observability.

**Presenter Notes:**
- Walk through best-practices-guide.md:
  - Resource naming
  - RBAC and access control
  - Cost management
  - Data retention and compliance
- Discuss tagging strategy and automation.

**Resources:**
- GitHub: [best-practices-guide.md](docs/best-practices-guide.md)
- Azure Policy and Cost Management

---

## ⏰ 16:30 – 17:00 | Q&A + Next Steps

**Goal:** Wrap up and define follow-up actions.

**Presenter Notes:**
- Recap key takeaways.
- Ask for feedback.
- Offer to co-develop a pilot or proof-of-value.
- Share links to repo, docs, and contact info.

**Resources:**
- Slide: Summary & Next Steps
- GitHub repo link
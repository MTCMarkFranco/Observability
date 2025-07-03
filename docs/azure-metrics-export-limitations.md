# Azure Metrics Export Limitations for Partner Solutions (e.g., Dynatrace)

## Why Are Some Azure Metrics/Dimensions Not Exported to Partner Solutions?

Azure restricts the export of certain metrics and dimensions to partner solutions (like Dynatrace, Datadog, etc.) for several reasons:

### 1. **Platform Security and Privacy**
- Some metrics/dimensions may contain sensitive or customer-specific data (e.g., user identities, IP addresses, business KPIs).
- Exporting these could violate compliance, privacy, or regulatory requirements.

### 2. **Technical and Architectural Constraints**
- Many Azure PaaS/SaaS services generate high-cardinality or high-frequency metrics that are not designed for external streaming.
- Some metrics are only available within Azure’s internal monitoring systems and are not exposed via public APIs.
- Multi-dimensional metrics (e.g., per-endpoint, per-user) can be very large and are not supported by the current export mechanisms.

### 3. **Cost and Performance Considerations**
- Exporting all metrics (especially with all dimensions) would create significant data egress and processing costs for both Azure and customers.
- Azure optimizes for in-platform analytics and cost control, limiting what is sent externally.

### 4. **Product Strategy and Ecosystem Boundaries**
- Some advanced features (e.g., Application Insights custom metrics, AI-driven diagnostics) are designed to differentiate Azure’s native tools.
- Not all features are intended to be available to third-party platforms.

---

## Table: Azure Metrics/Dimensions Not Exported to Partner Solutions

| Service/Type         | Example Metrics/Dimensions                | Exported? | Why Not Exported?                                                                                 |
|---------------------|-------------------------------------------|-----------|---------------------------------------------------------------------------------------------------|
| Azure SQL Database  | DTU/EDTU usage, geo-replication lag, failover events | ❌        | Platform-only, high-cardinality, sensitive to internal operations                                 |
| Cosmos DB           | RU/s, partition key metrics, throttled requests     | ❌        | High-frequency, internal partitioning, not exposed via public APIs                                |
| Azure Functions     | Cold start time, trigger type, retry count         | ❌        | Only available in internal logs, not surfaced via metrics API                                     |
| App Service         | App restart count, HTTP queue length, sandbox CPU  | ❌        | Platform diagnostics, not supported for external streaming                                        |
| AKS (Kubernetes)    | Control plane metrics, node pool scaling events    | ❌        | Control plane is managed by Azure, not exposed externally                                         |
| Custom Metrics      | App Insights/Monitor SDK custom metrics            | ❌        | Designed for in-platform analytics, not exported                                                  |
| Diagnostic Logs     | Custom dimensions, user agent, operation name      | ❌        | May contain sensitive or high-cardinality data, not supported by export APIs                      |
| Resource Health     | Health status, maintenance events                  | ❌        | Internal service health, not available via export                                                 |
| Security/Compliance | Security Center recommendations, policy results    | ❌        | Compliance and security boundaries, not for external consumption                                  |
| Networking          | ExpressRoute circuit metrics, NSG flow logs        | ❌        | High-volume, privacy-sensitive, not supported for partner export                                  |
| Standard Metrics    | InstanceId, SlotName, Region, ResourceGroup        | ⚠️ Partial| Some dimensions are stripped or aggregated before export                                          |

---

## Summary

- **Azure only exports a subset of metrics and dimensions to partner solutions.**
- Most platform, custom, and diagnostic metrics are only available within Azure Monitor, Log Analytics, or Application Insights.
- This is due to a combination of security, technical, cost, and product strategy reasons.
- For full-fidelity monitoring, use Azure-native tools in addition to any partner solution.

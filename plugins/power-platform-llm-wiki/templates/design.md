---
type: design
status: draft
owner: {{technical owner}}
updated: {{YYYY-MM-DD}}
implements: [{{REQ-AREA-NNN}}]
sources: [{{raw/specs/tdd-file.md}}]
tags: [{{component}}]
---

# {{Design title}}

> {{What is being built and why, in one paragraph.}}

## Scope

- In scope: {{...}}
- Out of scope: {{...}}

## Solution overview

```mermaid
flowchart LR
    User[{{Actor}}] --> App[{{Application}}]
    App --> Service[{{Component}}]
```

## Components

| Component | Type                                        | Responsibility   | Code page                       |
| --------- | ------------------------------------------- | ---------------- | ------------------------------- |
| {{name}}  | {{plugin / X++ class / flow / integration}} | {{what it does}} | [{{page}}]({{../code/page.md}}) |

## Data model

{{Tables / entities touched, new fields, relationships.}}

## Integrations

| Interface | Direction  | Protocol                              | Frequency             | Error handling      |
| --------- | ---------- | ------------------------------------- | --------------------- | ------------------- |
| {{name}}  | {{in/out}} | {{REST / OData / file / Service Bus}} | {{real-time / batch}} | {{retry, alerting}} |

## Security

{{Roles, privileges, data access, secrets management.}}

## Deployment and configuration

{{Solutions / models / pipelines, environment variables, feature flags.}}

## Decisions

- [{{ADR-NNN}}]({{../reference/decisions/ADR-NNN-slug.md}})

## Source references

- `{{raw/specs/tdd-file.md}}`

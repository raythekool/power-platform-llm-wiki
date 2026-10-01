---
type: code
status: draft
updated: {{YYYY-MM-DD}}
project: {{repo name}}
commit: "{{repo@sha}}"
implements: [{{REQ-AREA-NNN}}]
sources: [{{raw/code/repo-YYYY-MM-DD.json}}, {{path/in/repo}}]
tags: [{{plugin|pcf|xpp|flow|integration}}]
---

# {{Component name}}

> {{What the component does in business terms (as built, derived from the code).}}

## Responsibilities

- {{responsibility}}

## How it works

```mermaid
sequenceDiagram
    participant Caller as {{Trigger}}
    participant Comp as {{Component}}
    Caller->>Comp: {{event / call}}
    Comp-->>Caller: {{result}}
```

## Technical details

| Item                   | Value                                              |
| ---------------------- | -------------------------------------------------- |
| Location               | `{{path/in/repo}}`                                 |
| Trigger / registration | {{message, stage, entity / CoC method / schedule}} |
| Dependencies           | {{tables, services, configuration}}                |

## Traceability

| Requirement                                                  | Evidence                  | Notes                         |
| ------------------------------------------------------------ | ------------------------- | ----------------------------- |
| [{{REQ-AREA-NNN}}]({{../requirements/REQ-AREA-NNN-slug.md}}) | `{{file:line or method}}` | {{matches / partial / drift}} |

## Source references

- `{{repo}}@{{sha}}:{{path}}`

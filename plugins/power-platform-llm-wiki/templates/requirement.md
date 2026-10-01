---
type: requirement
req_id: {{REQ-AREA-NNN}}
status: draft
owner: {{functional owner}}
updated: {{YYYY-MM-DD}}
priority: {{Must|Should|Could|Won't}}
devops_id: "{{US-1234}}"
implemented_by: []
sources: [{{raw/analysis/fdd-file.md}}]
tags: [{{process-area}}]
---

# {{REQ-AREA-NNN}} {{Requirement title}}

> {{One-paragraph statement of the business need, written so a key user can validate it.}}

## Business context

{{Process, actors, triggers, volumes.}}

## Functional description

1. {{Step or rule}}

## Business rules

| ID  | Rule     |
| --- | -------- |
| BR1 | {{rule}} |

## Acceptance criteria

1. **Given** {{context}} **when** {{action}} **then** {{expected result}}.

## Non-functional requirements

- {{performance, security, availability, data retention}}

## Open questions

- 🎯 **Action:** @{{Owner}} - {{question to close}} by {{YYYY-MM-DD}}.

## Implementation

{{Filled by `update --source code`: links to the code/design pages that implement this requirement, plus drift notes.}}

## Source references

- `{{raw/analysis/fdd-file.md}}` section {{n}}

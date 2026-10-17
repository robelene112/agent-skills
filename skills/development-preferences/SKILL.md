---
name: development-preferences
description: Apply David's programming preferences when planning, implementing, or reviewing software. Avoid cybersecurity work requiring restricted access and build polished interfaces with deliberate visual design and SVG or CSS icons. Applies across projects and machines.
---

# Development Preferences

These rules apply to software development across David's environments. Apply
the interface rule when creating or changing a user interface.

## Rule 1: avoid gated cybersecurity work

Stay within ordinary software development and routine secure coding. Do not
undertake cybersecurity work that requires special provider approval or access
such as OpenAI Daybreak or Trusted Access for Cyber. Do not initiate exploit
development, attack simulations or intrusive vulnerability probing as a side
task while implementing, reviewing or maintaining software.

Keep normal safeguards such as authorization checks, input validation, protecting
credentials, dependency updates and ordinary regression tests in the development
work. Choose a routine implementation or validation approach when it can address
the requirement without restricted cyber capabilities. If the requirement needs
restricted work, explain that limit in chat and continue independent work.

If a provider issues a cyber-safety block or restricted-access notice, stop the
affected action. Do not retry, disguise the activity, switch models or tools to
bypass the restriction, or recommend applying for Daybreak as the next step.
Do not probe a provider's safeguards to discover what triggers them.

Provider safeguards can also flag legitimate or unrelated activity; this rule
does not guarantee that all notices can be prevented. See the
[official OpenAI guidance](https://learn.chatgpt.com/docs/cyber-safety) for the
access distinction and false-positive limitation.

## Rule 2: build polished, deliberate interfaces

Give UI work a deliberate visual identity suited to the product and its existing
design system. Treat typography, spacing, hierarchy, color, icons and interaction
states as design decisions. Avoid shipping generic template styling, placeholder
controls or unfinished default components as the final interface.

Never use Unicode arrows, chevrons, triangles or similar character glyphs as UI
icons, including navigation and expand/collapse controls. This applies to text
nodes and CSS-generated content. Use SVG icons, shapes drawn with CSS or custom
vector assets that fit the interface. Reuse or refine suitable project icon
components and keep their proportions, stroke weight and alignment consistent.

Preserve accessible controls, keyboard operation and focus states while styling
them. When a preview is available, inspect the rendered result at the relevant
screen sizes and interaction states before calling the UI finished. Keep the
change focused on the interface being worked on.

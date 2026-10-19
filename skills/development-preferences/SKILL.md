---
name: development-preferences
description: Apply David's development preferences when planning, implementing, or reviewing software. Prioritize user experience over developer convenience, build polished and consistent interfaces, and avoid cybersecurity work requiring restricted access. Applies across projects and machines.
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

## Rule 2: user experience comes first

Make user experience the primary decision criterion in planning, implementation
and review. Favor UX over developer experience: David accepts substantially more
development effort, implementation complexity and reduced developer convenience
even for a marginal improvement in the user's experience. Handle that complexity
in the implementation so the user's workflow stays effortless.

Choose thoughtful defaults suited to the user's actual task. Minimize required
setup, clicks, navigation and repeated input. Make the current state, relevant
information, progress, results and next actions easy to understand at a glance.
Evaluate the complete task flow, including the first-use experience and the
default path, rather than only individual screens.

Make the interface easy to control and visually appealing enough to feel like
eye candy. Aim for the "dopamine" feeling David requests: satisfying interactions,
immediate and clear feedback, visible progress and results, and polished visual
details and motion that make using the application enjoyable. Apply the design
and interaction requirements below consistently throughout the application.

Match the surrounding UI and the application's established design language.
Keep typography, spacing, hierarchy, color, component shapes, icons, interaction
states and motion consistent across the application. When no design language
exists, establish a coherent one for the product before building individual
screens. Record and reuse its shared design tokens and components so subsequent
work follows the same choices. Avoid shipping generic template styling,
placeholder controls or unfinished default components as the final interface.

Never use Unicode arrows, chevrons, triangles or similar character glyphs as UI
icons, including navigation and expand/collapse controls. This applies to text
nodes and CSS-generated content. Use SVG icons, shapes drawn with CSS or custom
vector assets that fit the interface. Reuse or refine suitable project icon
components and keep their proportions, stroke weight and alignment consistent.

Add short, fluid animations to interactions and state changes, especially when
expanding or collapsing content. Reuse the application's motion conventions;
where none exist, define consistent durations and easing alongside the visual
design. Start around 150-200 ms for small transitions and adjust to the component.
Keep the interface responsive and avoid slow animations, artificial waits or
blocking interaction until a transition finishes. Respect reduced-motion
preferences with minimal or no motion.

Preserve accessible controls, keyboard operation and focus states while styling
them. When a preview is available, exercise the default path and main user tasks,
checking unnecessary steps, clarity and feedback alongside the rendered result
at relevant screen sizes and interaction states before calling the UI finished.
Keep the change focused on the interface being worked on.

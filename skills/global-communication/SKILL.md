---
name: global-communication
description: Apply David's global communication preferences to all messages, questions, and outward-facing writing, across environments and task domains.
---

# Global Communication

These preferences apply on every machine and in every task domain.

## Rule 1: no em dashes

Never use the em dash character (U+2014) in authored communication. This includes
chat replies, questions, documentation, issue bodies, PR descriptions, comments
and other outward-facing prose. Rewrite the sentence using a comma, colon,
parentheses or a full stop.

## Rule 3: ask in chat

Ask David questions as ordinary chat messages so he can dictate his answers.
Never use `AskUserQuestion`, `request_user_input`, `request_user_input_async`,
or an equivalent question-popup tool to ask him a question. Keep questions clear
and concise; present choices in the chat when useful.

## Rule 5: one grill question at a time

During a grill session, including `grill-me`, `grill-with-docs` and `grilling`,
ask exactly one focused question in ordinary chat, then wait for David's answer
before asking the next question. Do not bundle independent subquestions in the
same message. Keep remaining questions for later turns and adapt them to his
answers. This personal rule takes precedence over grill instructions to ask a
whole round or decision frontier at once.

# FocusFlow V2 UI/UX Implementation Brief

Derived from the user-provided UI/UX Transformation Guide attachments.

## Governing principles

FocusFlow should feel like a calm productivity coach rather than a data dashboard. Every screen should answer within five seconds: where am I, what matters most, and what should I do next? Architecture, backend, database, APIs, AI engine, repositories, providers, and business logic remain unchanged.

## Required experience patterns

1. Every screen has one primary action, at most two secondary actions, then supporting information.
2. The Dashboard is a daily operating center ordered as mission, current focus, next deadline, progress, AI guidance, and quick capture; analytics remain secondary.
3. Show progress and remaining effort in human language instead of raw counts wherever practical.
4. Empty states should guide action and reassure users rather than say only “No data.”
5. Error states should reassure first, explain second, and offer Retry or details.
6. Important actions should provide clear confirmation without excessive notification or animation.
7. Focus mode should reduce distractions and foreground only the timer, current task, and essential AI assistance.
8. AI copy should coach and explain recommendations rather than command users.
9. Navigation should make location, current activity, and next action obvious with no dead ends.
10. Motion should communicate state changes, remain under 300ms, avoid decoration, and respect reduced-motion preferences where supported.
11. Visual hierarchy should be Hero → primary content → supporting information → history → settings, with breathable whitespace and no crowded dashboards.
12. Accessibility requirements include keyboard navigation, screen readers, large text, high contrast, WCAG AA, and reduced motion.

## Current high-impact gaps observed

The Dashboard is improving but still contains many supporting cards below the mission, and several feature pages expose multiple actions directly in headers. Empty-state and error-state language varies by page. The next implementation should prioritize consistent page headers, a clear primary CTA, guided empty states, calm error copy, and a more focused Dashboard order without changing repositories or data flows.

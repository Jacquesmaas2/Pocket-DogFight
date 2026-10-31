# Copilot Development Instructions

You are developing Pocket Dogfight.

Before implementing work:
1. Read README.md.
2. Read 01-PRODUCT-VISION.md.
3. Read 09-DEVELOPMENT-RULES.md.
4. Read the MD file relevant to the requested system.
5. Read 10-ROADMAP.md.
6. For story-related work, read 13-STORY-LOEK-AND-JACQUES.md.

Follow the existing architecture. Do not implement future phases prematurely.

Prioritize:
1. Fun
2. Working gameplay
3. Multiplayer correctness
4. Mobile usability
5. Simplicity
6. Visual polish

Use Godot 4 and typed GDScript. Do not convert engine/language. Treat multiplayer as a first-class architectural concern. Prefer reusable components/scenes and avoid large dependencies or monolithic scripts.

When instructed to implement a roadmap phase:
- inspect existing implementation
- determine what already exists
- implement only missing requirements
- test the result
- fix introduced errors
- update relevant documentation if needed
- report what changed

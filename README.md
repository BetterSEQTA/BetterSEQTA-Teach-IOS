# TechQTA

TechQTA is a small, opinionated iPhone app that gives SEQTA Teach users a cleaner, faster way to see the things they check all the time: **today’s classes** and **Direqt messages**.

It sits on top of your existing SEQTA Teach site – you log in the same way you do in the browser – and then keeps a lightweight, read‑only view of your day in your pocket.

> TechQTA is a personal / experimental project and is **not** affiliated with, endorsed, or supported by SEQTA or Education Horizons.

## What the app does

- **Home dashboard**
  - At a glance, see **today’s timetable** and your **most recent Direqt messages**.
  - Tap a lesson or message to jump straight into the full view.

- **Timetable**
  - Scrollable list of lessons for a chosen day.
  - Simple day‑to‑day navigation so you can quickly check yesterday, today, and tomorrow.

- **Direqt messages**
  - Inbox‑style list of messages with sender, subject, and time.
  - Full detail view that can show both plain text and rich HTML messages.

- **Guided login**
  - Short setup cards explain how login works and what’s happening behind the scenes.
  - You enter your school’s SEQTA Teach URL, sign in as normal in a secure in‑app browser, then tap **Done** when you’re in.

## How login and security work (in plain terms)

- You **never** type your password into TechQTA itself – you always log in on your school’s SEQTA Teach site.
- Once you’re successfully logged in, the app securely stores the session token from that browser **only on your device**.
- That token is used to load your timetable and messages; if it stops working, you’ll be asked to log in again.
- You can log out at any time, which clears the stored session and takes you back through the setup flow on next launch.

## Why this exists

TechQTA is mainly for people who:

- Live inside SEQTA Teach all day.
- Want a quick, phone‑friendly way to check **“Where am I next?”** and **“Has anyone messaged me?”** without digging around in a full browser.
- Prefer a simple, focused app over a full web UI squeezed into a mobile screen.

## Status

This is an experimental project and may change, break, or disappear at any time. It’s shared in case it’s useful or interesting to others working with SEQTA Teach.

For licensing details, see the `LICENSE` file (MIT).


# Air quality pipeline

> Starter file: save it as `CLAUDE.md` in the root of a new, empty repository (`piemonte-air-quality`).

## Goal
A personal portfolio project: a daily ELT pipeline for air quality in Torino and other towns in Piemonte, built to learn Airflow, Jenkins and MCP well enough to defend every line in a technical interview.

## How to work with me
- Talk to me in Spanish. Code, commits and README are in English.
- I know SQL and dbt well. Airflow, Jenkins and MCP are what I'm learning.
- **Be a tutor.** I write the DAG, the Jenkinsfile and the MCP tool definitions. Explain, give hints, review. Only write those files if I explicitly ask, then make me explain them back.
- You may write boilerplate (Docker Compose, .gitignore) and explain it briefly.
- Keep Python to the minimum Airflow needs. Transformations are SQL in dbt.
- One phase at a time. At the end of each, ask me three interview-style questions about it.

## Architecture
Open-Meteo (CSV) -> PostgreSQL (raw) -> dbt (staging, marts, tests) -> MCP (read-only)
Airflow has a daily schedule. Jenkins tests and deploys changes. Everything runs in Docker inside GitHub Codespaces.

## Environment: GitHub Codespaces
- 4-core / 16 GB machine. Free quota is about 30 hours a month on it, so remind me to stop it when we finish.
- Set up `.devcontainer/devcontainer.json` with Docker-in-Docker and the Claude Code feature (`ghcr.io/anthropics/devcontainer-features/claude-code:1.0`).
- It is not always on: use catchup so missed days load on start. Never describe it as running in production.
- It is disposable: everything must rebuild from the repository with one command plus a backfill. Push before stopping.

## Data
- Docs: https://open-meteo.com/en/docs/air-quality-api
- Variables: pm10, pm2_5, nitrogen_dioxide, ozone (hourly, µg/m³). Use `format=csv` and `domains=cams_europe`.
- The European grid is about 11 km, so districts of one city return nearly identical values. Use towns far apart: Torino, Ivrea, Susa, Pinerolo, Carmagnola.
- These are model estimates, not sensor measurements. Say so in the README and the MCP tool descriptions.
- Fetch and store in UTC. The API ignores DST changes inside a requested range.
- Use start_date / end_date per run so retries and backfills are idempotent.
- Look up current EU limits in the official directive before coding them. Keep them in a dbt seed with the source.
- Credit both CAMS and Open-Meteo in the README. The free API is for non-commercial use.

## Phases
1. **Base:** Postgres, raw load without duplicates, 4-5 dbt models, tests for missing hours, duplicates and impossible values.
2. **Airflow:** daily DAG, retries, failure alert, backfill.
3. **Jenkins:** on a pull request, check the DAG and build modified models in a test schema; block on failure; deploy on merge to main. Measure build time before and after.
4. **README:** diagram, screenshots, a deliberately failing PR, limitations.
5. **MCP:** MCP Toolbox for Databases with 3-4 parameterised SQL tools, a database user that can only read the marts, and an evaluation of 10 questions with known answers.

## Safety
- Public data only. Never use code, names, documents or course material from any employer or client.
- Secrets live in `.env`, never committed. No personal documents in this repository.
- Jenkins must never build pull requests from forks: the repository is public and Jenkins has access to my Codespace.
- Keep every forwarded port private. Do not expose Jenkins, Airflow, Postgres or the MCP server.

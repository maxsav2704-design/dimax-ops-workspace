# Demo Deploy

This is a demo-grade deployment path for the current web-first DIMAX stack.

It is intended for:

- customer demos
- internal review environments
- non-production preview servers

It is not a replacement for a hardened production rollout.

## What it starts

- PostgreSQL
- MinIO
- FastAPI backend
- Next.js frontend in production mode

Compose file:

- `docker-compose.demo.yml`

Frontend image:

- `dimax-operations-suite-main/Dockerfile.demo`

## 1. Prepare env

Copy:

- `.env.demo.example` -> `.env.demo`

Then replace at minimum:

- `POSTGRES_PASSWORD`
- `JWT_SECRET`
- `SEED_ADMIN_PASSWORD`
- `MINIO_ACCESS_KEY`
- `MINIO_SECRET_KEY`
- `PUBLIC_BASE_URL`
- `CORS_ALLOW_ORIGINS`
- `NEXT_PUBLIC_API_BASE_URL`

Recommended demo DNS:

- frontend: `https://demo.example.com`
- api: `https://api.demo.example.com`

Public server checklist:

- `DEMO_SERVER_CHECKLIST.md`

Nginx reverse proxy example:

- `infra/nginx/dimax-demo.conf.example`

## 2. Validate backend/frontend env contracts

Backend:

```powershell
cd backend
python scripts/validate_production_env.py --env-file .env
```

Frontend:

```powershell
cd dimax-operations-suite-main
npm run check:env:production -- --env-file .env.production.local
```

For demo compose, keep frontend and compose env aligned:

- `NEXT_PUBLIC_API_BASE_URL` in `.env.demo`
- `NEXT_PUBLIC_API_BASE_URL` in `dimax-operations-suite-main/.env.production.local`

## 3. Start demo stack

From workspace root:

```powershell
docker compose --env-file .env.demo -f docker-compose.demo.yml up -d --build
```

## 4. Seed demo users

```powershell
docker compose --env-file .env.demo -f docker-compose.demo.yml exec -T api python -m app.scripts.seed_dev
```

Default seeded users:

- admin: `admin@dimax.dev / admin12345`
- installer: `installer1@dimax.dev / installer12345`

If you changed `SEED_ADMIN_PASSWORD`, use the value from your env instead of the default above.

## 5. Demo URLs

- frontend: `http://<host>:5173/login`
- admin workspace: `http://<host>:5173/`
- operations center: `http://<host>:5173/operations`
- installer workspace: `http://<host>:5173/installer`
- installer calendar: `http://<host>:5173/installer/calendar`
- api health: `http://<host>:8000/health`
- minio console: `http://<host>:9021`

## 6. Demo smoke

Check:

1. `/health` returns `200`
2. admin login works
3. installer login works
4. `/operations` opens
5. `/reports` opens
6. `/installer` opens
7. one installer project page opens

## 7. Stop demo stack

```powershell
docker compose --env-file .env.demo -f docker-compose.demo.yml down
```

With volumes:

```powershell
docker compose --env-file .env.demo -f docker-compose.demo.yml down -v
```

## Notes

- current local workspace compose is dev-oriented and runs `npm ci` + `next dev`
- demo compose is production-oriented and avoids live-reload behavior
- keep demo deploys separate from release/prod environments
- for a public URL, put Nginx + TLS in front of ports `5173` and `8000`

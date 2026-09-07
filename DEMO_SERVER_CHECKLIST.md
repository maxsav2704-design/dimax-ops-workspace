# Demo Server Checklist

This is the fastest safe path to a public demo URL.

## Target shape

- frontend: `https://demo.example.com`
- api: `https://api.demo.example.com`
- reverse proxy: Nginx
- runtime: Docker Compose on one Linux VPS

## Minimum server

- Ubuntu 24.04 LTS
- 2 vCPU
- 4 GB RAM
- 30+ GB SSD
- public static IP

This is enough for:

- PostgreSQL
- MinIO
- FastAPI
- Next.js
- Nginx

## DNS

Create `A` records:

- `demo.example.com` -> `<server_ip>`
- `api.demo.example.com` -> `<server_ip>`

Wait until both resolve before requesting TLS.

## Packages on server

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin nginx certbot python3-certbot-nginx
sudo systemctl enable --now docker
sudo systemctl enable --now nginx
```

## Copy project

Clone:

```bash
git clone https://github.com/maxsav2704-design/dimax-ops-workspace.git
cd dimax-ops-workspace
git checkout feature/final-production-maturity
```

If you want the released baseline only, switch to `main` after the PRs are merged.

## Prepare env

```bash
cp .env.demo.example .env.demo
```

Edit `.env.demo` and replace at minimum:

- `POSTGRES_PASSWORD`
- `JWT_SECRET`
- `SEED_ADMIN_PASSWORD`
- `MINIO_ACCESS_KEY`
- `MINIO_SECRET_KEY`
- `PUBLIC_BASE_URL`
- `CORS_ALLOW_ORIGINS`
- `NEXT_PUBLIC_API_BASE_URL`

Expected values:

- `PUBLIC_BASE_URL=https://api.demo.example.com`
- `CORS_ALLOW_ORIGINS=https://demo.example.com`
- `NEXT_PUBLIC_API_BASE_URL=https://api.demo.example.com`

## Start stack

```bash
docker compose --env-file .env.demo -f docker-compose.demo.yml up -d --build
docker compose --env-file .env.demo -f docker-compose.demo.yml exec -T api python -m app.scripts.seed_dev
```

Check:

```bash
docker compose --env-file .env.demo -f docker-compose.demo.yml ps
curl -i http://127.0.0.1:8000/health
curl -I http://127.0.0.1:5173/login
```

## Nginx reverse proxy

Use:

- `infra/nginx/dimax-demo.conf.example`

Install:

```bash
sudo cp infra/nginx/dimax-demo.conf.example /etc/nginx/sites-available/dimax-demo.conf
sudo ln -s /etc/nginx/sites-available/dimax-demo.conf /etc/nginx/sites-enabled/dimax-demo.conf
sudo nginx -t
sudo systemctl reload nginx
```

## TLS

```bash
sudo certbot --nginx -d demo.example.com -d api.demo.example.com
```

Then test:

```bash
curl -I https://demo.example.com/login
curl -i https://api.demo.example.com/health
```

## Public demo smoke

1. `https://demo.example.com/login` opens
2. admin login works
3. installer login works
4. `https://demo.example.com/operations` opens
5. `https://demo.example.com/reports` opens
6. `https://demo.example.com/installer` opens
7. `https://api.demo.example.com/health` returns `200`

Record smoke in:

- `POST_DEPLOY_SMOKE.md`

## Default demo credentials

- admin: `admin@dimax.dev / admin12345`
- installer: `installer1@dimax.dev / installer12345`

If `SEED_ADMIN_PASSWORD` was changed, use that value instead of the default admin password.

## Stop / update

Stop:

```bash
docker compose --env-file .env.demo -f docker-compose.demo.yml down
```

Update after new pull:

```bash
git pull
docker compose --env-file .env.demo -f docker-compose.demo.yml up -d --build
```

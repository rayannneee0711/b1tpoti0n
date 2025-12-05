<p align="center">
  <img src="b1tpoti0n.png" alt="b1tpoti0n" width="200">
</p>

# b1tpoti0n

Private BitTorrent tracker in Elixir.

## Features

- HTTP/HTTPS tracker (BEP 3)
- UDP tracker (BEP 15)
- Passkey authentication
- User ratio tracking
- Client whitelist
- IP banning
- Rate limiting
- Hit-and-Run detection
- Bonus points system
- Freeleech and multipliers
- Prometheus metrics
- SQLite or PostgreSQL database
- In-memory or Redis peer storage
- Optional clustering (Horde + Redis)

## Quick Start

```bash
# Install dependencies
mix deps.get

# Setup database
mix ecto.create && mix ecto.migrate

# Start tracker
iex -S mix
```

Default port: HTTP 8080 (UDP disabled by default, set `udp_port` to enable)

## Endpoints

- `GET /:passkey/announce` - Announce
- `GET /:passkey/scrape` - Scrape
- `GET /health` - Health check
- `GET /stats` - Basic statistics
- `GET /metrics` - Prometheus metrics
- `/admin/*` - Admin REST API
- `GET /ws` - WebSocket (real-time updates)

## Configuration

See `config/config.exs` for all options.

Key settings:
- `http_port` / `https_port` / `udp_port` - Network ports
- `admin_token` - Admin API authentication (required in production)
- `peer_storage` - `:memory` (default) or `:redis` for clustering
- `hnr` - Hit-and-Run detection settings
- `bonus_points` - Bonus points system settings
- `enforce_torrent_whitelist` - Require torrent pre-registration.

For production, set environment variables (see DOCUMENTATION.md):
- `ADMIN_TOKEN`, `HTTP_PORT`, `UDP_PORT`, `DATABASE_URL`, etc.

## Documentation

See [DOCUMENTATION.md](DOCUMENTATION.md) for complete documentation including:
- Full configuration reference
- Architecture overview
- Admin API reference
- Deployment guide

## Admin UI

A standalone admin interface is available at `admin-ui/index.html`.

## Tests

```bash
mix test
```

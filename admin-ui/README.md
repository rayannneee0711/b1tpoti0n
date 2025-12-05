# b1tpoti0n Admin UI

A standalone admin interface for managing the b1tpoti0n tracker.

## Files

- `index.html` - HTML structure
- `admin.css` - CSS styles
- `admin.js` - JavaScript application logic (Alpine.js)

## Usage

1. Start the tracker:
   ```bash
   iex -S mix
   ```

2. Open `index.html` directly in your browser:
   ```bash
   open admin-ui/index.html
   # or just double-click the file
   ```

3. Configure connection:
   - **API URL**: `http://localhost:8080` (default)
   - **Admin Token**: Your configured admin token (from config)
   - Click "Connect" to verify

## Features

### Dashboard
- Overview stats (users, torrents, swarms, snatches, HnR, bans)
- Quick actions (flush stats, run HnR check, calculate bonus, cleanup bans)

### Users
- List/search users
- Create new users
- Edit user stats (uploaded/downloaded)
- Toggle leech permissions
- Reset passkeys
- Clear HnR warnings
- Delete users

### Torrents
- List all torrents
- Register new torrents
- Toggle freeleech
- Set upload/download multipliers
- Edit torrent stats
- Delete torrents

### Whitelist
- View whitelisted clients
- Add new clients
- Remove clients

### IP Bans
- View all/active bans
- Ban IP addresses (with optional duration)
- Unban IPs
- Cleanup expired bans

### Rate Limits
- View rate limiter stats
- Check rate limit for specific IP
- Reset rate limits

### Snatches
- View snatches by user or torrent
- Clear HnR flags
- Delete snatches

### Hit-and-Run
- View all HnR violations
- Trigger manual HnR check
- Clear individual HnR flags

### Bonus Points
- View calculator stats
- Get/add/remove user points
- Redeem points for upload credit
- Trigger manual calculation

### Swarms
- View active swarm workers
- See seeder/leecher counts per torrent

### System
- Flush stats buffer
- Run HnR check
- Calculate bonus points
- Cleanup expired bans
- Clear verification cache
- View peer verification stats

## Tech Stack

- Alpine.js for reactive UI
- No build step required
- Single external dependency (Alpine.js CDN)
- Dark theme UI
- Separated HTML/CSS/JS for maintainability

## UX Features

- Connection status indicator with visual feedback
- Loading spinners when fetching data
- Empty state messages for empty tables
- Tooltips explaining technical terms (HnR, FL, S/L, etc.)
- Clickable dashboard stats to navigate to sections
- Section descriptions explaining each feature

## Configuration

The admin token is configured in the tracker:

```elixir
# config/config.exs or config/dev.exs
config :b1tpoti0n,
  admin_token: "your_secret_token"
```

If no token is configured, the Admin API is disabled and returns 503 errors.

## CORS Configuration

CORS is configurable via `cors_origins` setting or `CORS_ORIGINS` environment variable:

```bash
# Allow all origins (default, for development)
CORS_ORIGINS="*"

# Single origin
CORS_ORIGINS="https://admin.example.com"

# Multiple origins (comma-separated)
CORS_ORIGINS="https://admin.example.com,https://backup.example.com"
```

For local development, you can open the HTML file directly (file:// protocol) or use a simple HTTP server:

```bash
# Python
python3 -m http.server 3000 --directory admin-ui

# Node.js
npx serve admin-ui

# Then open http://localhost:3000
```

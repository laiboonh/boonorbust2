# Claude Code Configuration

This document contains configuration and commands for working with this project in Claude Code.

## Development Commands

### Quality & Testing
```bash
# Run all quality checks (format, credo, dialyzer)
mix quality

# Run tests
mix test

# Format code
mix format

# Run Credo (static analysis)
mix credo --strict

# Run Dialyzer (type checking)
mix dialyzer
```

### Development Server
```bash
# Start development server
mix phx.server

# Start with interactive shell
iex -S mix phx.server
```

### Database
```bash
# Setup database
mix ecto.setup

# Reset database
mix ecto.reset

# Create migration
mix ecto.gen.migration migration_name

# Run migrations
mix ecto.migrate
```

### Assets
```bash
# Build assets
mix assets.build

# Setup assets (install dependencies)
mix assets.setup

# Deploy assets (minified)
mix assets.deploy
```

## Project Structure

### Controllers & Views
- **lib/boonorbust2_web/controllers/** - Phoenix controllers
  - `page_controller.ex` - Home page
  - `dashboard_controller.ex` - Portfolio dashboard
  - `asset_controller.ex` - Asset management
  - `portfolio_transaction_controller.ex` - Portfolio transactions
  - `auth_controller.ex` - Google OAuth authentication
  - `user_controller.ex` - User management
- **lib/boonorbust2_web/controllers/*_html.ex** - HTML templates
  - `dashboard_html.ex` - Dashboard views
  - `asset_html.ex` - Asset views with modals
  - `portfolio_transaction_html.ex` - Transaction views
- **lib/boonorbust2_web/components/layouts/** - Layout templates

### Core Business Logic
- **lib/boonorbust2/** - Context modules
  - `assets.ex` - Asset management with price fetching
  - `portfolio_transactions.ex` - Transaction CRUD
  - `portfolio_positions.ex` - Position calculations
  - `accounts.ex` - User account management
  - `http_client.ex` - HTTP client behavior for price APIs
  - `currency.ex` - Currency utilities with CLDR

### Database
- **priv/repo/migrations/** - Database migrations

## Key Features

### Authentication
- Google OAuth integration via Ueberauth
- User management with Ecto schemas

### Dashboard & Portfolio Management
- **Dashboard** - Displays latest portfolio positions with real-time calculations
- **Assets** - CRUD operations with modal-based UI
  - Asset price tracking via external API
  - Automatic price updates (24-hour rate limiting)
  - Price validation with URL format checking
  - Inline editing with loading overlays
- **Portfolio Transactions** - Buy/sell transaction tracking
  - Transaction history per asset
  - Position calculations based on transaction date
  - Amount on hand tracking
- **Portfolio Positions** - Real-time position tracking
  - Latest positions calculated from all transactions
  - Modal view showing transaction history per asset
  - Automatic position recalculation on transaction changes
  - Amount on hand displayed with transaction details
- **Real-time Updates** - HTMX for dynamic interactions without page reloads
  - Loading spinners with icon toggle
  - Modal overlays for save operations
  - Error handling without page refresh

### UI/UX
- **MOBILE-FIRST APP** - Primary focus on mobile web experience
- Mobile-optimized layouts and spacing (no scrolling required)
- Touch-friendly buttons and interactions
- Simplified, centered designs for small screens
- Tailwind CSS for styling with mobile-first breakpoints
- Consistent emerald branding and circular logo design
- Header with app version, user greeting, and logout
- Minimal content density optimized for mobile viewing

### User Feedback Pattern
- **NO FLASH MESSAGES** - This app does not use Phoenix flash messages
- All user feedback is handled via HTMX and direct DOM updates
- Success/error messages display in modals or dedicated UI elements
- Real-time feedback without page redirects or flash containers

## Notes

- App version: 0.1.0 (displayed in header)
- Uses Phoenix 1.8+ with LiveView
- PostgreSQL database
- Elixir ~> 1.18

## IMPORTANT: Pre-commit Hooks

**NEVER skip pre-commit checks** - Always resolve all errors and warnings before committing:

1. **Pre-commit hooks are mandatory** - They run automatically on `git commit`
2. **Quality checks must pass**: format, credo, dialyzer, tests
3. **If hooks fail**: Fix all issues and commit again
4. **Don't force commits** - Always let the hooks complete successfully
5. **Code formatting**: Hooks will auto-format code - commit the formatted version

The project uses these quality tools:
- `mix format` - Code formatting
- `mix credo --strict` - Static code analysis
- `mix dialyzer` - Type checking
- `mix test` - Test suite

All must pass before code can be committed to maintain code quality.

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

- **lib/boonorbust2_web/controllers/** - Phoenix controllers
- **lib/boonorbust2_web/controllers/page_html/** - Home page templates
- **lib/boonorbust2_web/controllers/message_html.ex** - Messages page HTML
- **lib/boonorbust2_web/components/layouts/** - Layout templates
- **lib/boonorbust2/** - Core business logic
- **priv/repo/migrations/** - Database migrations

## Key Features

### Authentication
- Google OAuth integration via Ueberauth
- User management with Ecto schemas

### Messages System
- CRUD operations for messages
- Modal-based message creation
- HTMX for dynamic interactions

### UI/UX
- **MOBILE-FIRST APP** - Primary focus on mobile web experience
- Mobile-optimized layouts and spacing (no scrolling required)
- Touch-friendly buttons and interactions
- Simplified, centered designs for small screens
- Tailwind CSS for styling with mobile-first breakpoints
- Consistent emerald branding and circular logo design
- Header with app version, user greeting, and logout
- Minimal content density optimized for mobile viewing

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

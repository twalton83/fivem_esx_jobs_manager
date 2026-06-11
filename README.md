# FiveM Jobs Panel

An in-game admin panel for managing jobs, ranks, salaries, and player employment on ESX Legacy servers. Built with React + Tailwind for the UI and Lua + oxmysql for the backend.

## Features

- **Job Management** — Create, edit, and delete jobs with full rank/salary control. Writes directly to ESX `jobs` and `job_grades` tables and calls `ESX.RefreshJobs()` automatically.
- **Player Management** — Browse all players, assign or change jobs and ranks. Updates both the database and online players in real-time.
- **Templates** — Reusable rank structures for quickly setting up new jobs. Stored locally per admin.
- **Activity Logs** — Audit trail of every admin action (job creates, updates, deletes, player reassignments), stored in the database.
- **Discord Webhooks** — Every job/player change posts a color-coded embed to your Discord channel. Optional.
- **FiveManage Logging** — Optional integration with FiveManage's logging API.
- **Settings** — Dark/light mode, custom color pickers (primary, secondary, accent), and server branding (name + logo).

## Tech Stack

| Layer      | Technology                               |
| ---------- | ---------------------------------------- |
| UI         | React 18, React Router 7, Tailwind CSS 4 |
| Components | Radix UI, Lucide icons, Recharts         |
| Build      | Vite 6                                   |
| Backend    | Lua 5.4, ESX Legacy callbacks            |
| Database   | MySQL via oxmysql                        |

## Dependencies

- [ESX Legacy](https://github.com/esx-framework/esx_core)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. **Clone or download** this resource into your server's `resources/` folder.

2. **Install Node dependencies and build the UI:**

   ```
   npm install
   npm run build
   ```

3. **Configure** — Edit `config.lua`:

   ```lua
   Config.Command       = 'jobspanel'        -- chat command to open the panel
   Config.Keybind       = 'F7'               -- default key mapping
   Config.AcePermission = 'jobspanel.admin'  -- required ACE permission

   Config.DiscordWebhook = 'https://discord.com/api/webhooks/...'  -- optional
   Config.FiveManageKey  = ''                                       -- optional
   ```

4. **Grant the ACE permission** to your admin group in your `server.cfg`:

   ```
   add_ace group.admin jobspanel.admin allow
   ```

5. **Add to your server config:**

   ```
   ensure Fivemjobspanel
   ```

   The `jobspanel_logs` table is created automatically on first start — no manual SQL import needed.

6. **In-game:** Type `/jobspanel` or press `F7` (rebindable in FiveM settings).

## Development

For local UI development outside of FiveM (hot-reload in browser):

```
npm run dev
```

The app runs in dev mode with mock data and localStorage persistence — no server or database needed.

When ready to test in-game, rebuild:

```
npm run build
```

Then `ensure Fivemjobspanel` or restart the resource in your server console.

## Permissions

Access is controlled by the ACE permission defined in `Config.AcePermission`. Only players with that permission can open the panel. All server callbacks verify permissions before executing any database operation. A rate limiter prevents spam (500ms cooldown per action).

## License

GPL-3.0

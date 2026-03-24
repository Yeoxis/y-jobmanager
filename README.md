A comprehensive job management app for CodeM Phone v2 & QBCore that includes multi-job functionalities, boss menu, time tracking, and discord webhooks. This is configured as a default app, you can change it if needed.
I do **not** plan on adding anything other then QBCore but the files are open to do what you please with it!

Showcase Video: https://www.youtube.com/watch?v=7WQ2GOFKGq0

## Dependencies
- **OxMySQL**
- **QBCore**

### 📱 Phone App (CodeM Phone v2)
- **Multi-Job Management** - Players can hold multiple jobs simultaneously
- **Job Switching** - Switch between jobs instantly from your phone
- **Duty Toggle** - Clock in/out with automatic time tracking
- **Quit Button** - Hold for 5 seconds to quit your job
- **Boss Menu** - Hire, fire, promote/demote employees (ability to hire people offline by CID)
- **Time Tracking** - View weekly and all-time hours worked
- **Rank Permissions** - Granular permission system by rank

### ⏰ Time Tracking
- Automatic clock in/out when toggling duty
- Tracks weekly and all-time hours per job (weekly resets every monday)
- Auto-logout on disconnect
- Discord webhooks for all clock events

### 🔐 Permission System
- **'all' perms** - Can manage employees at equal rank and below
- **Partial perms** - Can only manage employees below your rank
- **Configurable per job** - Set permissions by rank/grade
- Prevents firing or promoting above your authority

### 🎨 Customization
- **Color Theme** - Single config option changes entire UI color
- **App Icon** - You can change the icon (located in ui folder) to any webp file
- **Per-Job Webhooks** - Separate webhooks for timeclock and boss menu
- **Flexible Permissions** - Assign perms to single or multiple ranks

## Installation

### 1. Database Setup
Run the SQL file to create required tables:
```sql
-- Run install.sql in your database
-- Creates: multijobs and y_timeclock tables
```


### 2. Resource Installation
1. Extract `y-jobmanager` folder to your resources directory
2. Add to `server.cfg`:
```
ensure y-jobmanager
```

### 3. Configuration
Edit `config.lua`:

#### UI Color Theme
```lua
Config.AccentColor = '#a693ac'  -- Change to any hex color
```

#### Webhook Settings
```lua
-- Timeclock webhooks (clock in/out)
Config.TimeclockWebhook = {
    botName = 'Time Clock',
    botAvatar = 'https://your-image-url.png',
    colors = {
        clockIn = 3066993,   -- Green
        clockOut = 15158332, -- Red
    }
}

-- Boss menu webhooks (hire/fire/rankchange/quit)
Config.BossMenuWebhook = {
    botName = 'Job Management',
    botAvatar = 'https://your-image-url.png',
    colors = {
        hire = 3447003,
        fire = 15158332,
        promote = 15844367,
        demote = 12745742,
        quit = 10038562,
    }
}
```

#### Job Configuration
```
['police'] = { -- job code
        label = 'Los Santos Police Department', -- job label that shows in the app and webhooks title
        icon  = '🚔', -- shows in the multijob menu
        permissions = {
            { grades = {0, 1}, perms = {} }, -- no permissions
			{ grades = 2, perms = {'hire'} }, -- only has access to hire people
            { grades = 3, perms = {'hire', 'change_rank'} }, -- only has access to hiring people and changing 0-2 ranks
            { grades = 4, perms = {'hire', 'change_rank', 'fire'} }, -- has access to hiring, changing ranks, and firing anyone below them
            { grades = 5, perms = {'all'} }, -- has access to all permissions
        },
        timeclockwebhook = 'YourDiscordWebhookLink', -- 'link' or nil
        bossmenuwebhook = nil, -- 'link' or nil
    },
```

## Permission Types

### Available Permissions
- `hire` - Can hire new employees
- `fire` - Can fire employees
- `change_rank` - Can promote/demote employees
- `all` - Grants all permissions (hire + fire + change_rank)

### Permission Examples

**Single Grade:**
```lua
{ grades = 5, perms = {'hire', 'change_rank'} }
```

**Multiple Grades:**
```lua
{ grades = {4, 5, 6}, perms = {'all'} }
```

**No Permissions:**
```lua
{ grades = {0, 1, 2}, perms = {} }
```

## Rank Restrictions

### With 'all' Permissions
- Can manage employees at **equal rank and below**
- Can promote someone up to your own rank
- Can fire employees at your rank
- Cannot manage anyone above your rank

### With Partial Permissions
- Can manage employees **below your rank only**
- Can promote up to (but not including) your rank
- Cannot fire employees at your rank
- Cannot manage equal or higher ranks

### Examples
**Rank 5 Chief (all perms):**
- ✅ Can fire other Rank 5 Chiefs
- ✅ Can promote Rank 4 to Rank 5
- ✅ Can manage Ranks 0-5
- ✅ Can manage Rank 6+

**Rank 4 Lieutenant (hire + change_rank):**
- ✅ Can promote Rank 2 to Rank 4
- ✅ Can manage Ranks 0-3
- ❌ Cannot fire Rank 4
- ❌ Cannot manage Rank 4+

## Discord Webhooks

### Timeclock Webhooks
Sent to `timeclockwebhook` URL:
- **Clock In** - Shows current hours
- **Clock Out** - Shows session time and totals

### Boss Menu Webhooks
Sent to `bossmenuwebhook` URL:
- **Hired** - Shows who hired and new employee
- **Fired** - Shows who fired the employee
- **Promoted** - Shows new rank and who promoted
- **Demoted** - Shows new rank and who demoted
- **Quit** - Shows who quit

## File Structure
```
y-jobmanager/
├── client/
│   └── main.lua           # Phone app registration
├── server/
│   ├── jobmanager.lua     # Job management logic
│   └── timeclock.lua      # Time tracking & webhooks
├── ui/
│   ├── index.html         # Phone app interface
│   └── icon.webp          # App icon
├── config.lua             # All configuration
├── fxmanifest.lua         # Resource manifest
├── readme.md              # Resource information
└── install.sql            # Database setup
```

## Dependencies
- **qb-core** - QBCore Framework
- **codem-phone** - Phone system
- **oxmysql** - Database queries


## Credits
- **Developer:** Yeox
- **Framework:** QBCore

This resource is provided as-is for QBCore servers.

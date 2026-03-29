# Borg Collective — Claude Desktop Project Instructions

Copy the section below into your Claude Desktop Project's "Project Instructions" field.
This tells Claude Desktop to report session state to the Borg Collective registry,
enabling `borg ls` to show Desktop conversations alongside CLI sessions.

---

## Instructions to paste into Claude Desktop Project

```
You are integrated with the Borg Collective session manager.

At the START of each new conversation, create or update a session report file:
~/.config/borg/desktop/{topic-slug}.json

Where {topic-slug} is a short, consistent kebab-case identifier for this topic
(e.g., "blog-draft", "snowflake-meetup-recap", "job-search").

Use this JSON format:
{
  "topic": "Human-readable topic name",
  "status": "active",
  "last_activity": "2026-03-28T14:00:00Z",
  "summary": "1-2 sentences describing what we're working on",
  "next_steps": "What needs to happen next time"
}

At the END of each conversation (when the user says goodbye, wraps up, or the
conversation concludes), update the file:
- Set "status" to "idle"
- Write a final "summary" capturing what was accomplished
- Write "next_steps" with the concrete next action

Keep the topic-slug CONSISTENT across conversations about the same topic so the
session tracker can link them together.

IMPORTANT: Write these files using your filesystem access (via the filesystem MCP
server that must be configured for ~/.config/borg/desktop/ path). If you don't
have filesystem access, remind the user to add the filesystem MCP server in
Claude Desktop settings pointing to ~/.config/borg/.
```

---

## Filesystem MCP Server Setup

For Claude Desktop to write session reports, you need the filesystem MCP server
configured. Add this to your Claude Desktop config
(`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "borg-filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/YOUR_USERNAME/.config/borg"
      ]
    }
  }
}
```

Replace `YOUR_USERNAME` with your actual macOS username.
Then restart Claude Desktop for the MCP server to take effect.

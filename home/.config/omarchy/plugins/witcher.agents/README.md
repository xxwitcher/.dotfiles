# Agent Chat (witcher.agents)

A clone of Omarchy's `omarchy.agents` bar widget that turns the usage panel
into a chat with Omarchy's default agent (`omarchy default agent <name>`).

- **Top:** one compact line with the agent's mark, name and plan, then the
  session and weekly limits side by side. Usage data comes from the stock
  `Main.qml` / `Agent.qml`, unchanged.
- **Below:** the chat. Enter sends, Stop cancels a running turn, New chat
  starts over, Esc closes. Replies render as Markdown and are selectable;
  tool calls show as dim `⚙ Tool · detail` lines.

Each message runs `bin/agent-chat`, which starts the default agent headless
with the same auto-approve flag `omarchy agent` uses, from
`~/.local/state/agent-chat`, so the agent's own Omarchy skills and rules still
apply. Claude streams its reply and resumes the conversation by session id;
the other agents (codex, opencode, crush, pi, omp, grok, agy, copilot, hermes,
ori) reply in one piece and continue their latest session in that directory
(ori can only answer each message on its own). Only Claude has been tested.

IPC: `omarchy-shell witcher.agents <open|close|toggle|refresh|next>`.
Bar icon: left = panel, right = launch the agent in a terminal.

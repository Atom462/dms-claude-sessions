import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Claude Sessions — background daemon for DankMaterialShell.
//
// Polls kitty's remote-control API for panes whose foreground process is
// `claude`. Claude Code keeps its own status in the pane title:
//
//     ◑ 项目名     turn in progress
//     ✳ 项目名     idle / ready for input
//
// So a ◑ -> ✳ transition is "this session just finished a turn". On that
// transition we post a DMS notification; clicking it focuses the pane.
//
// Nothing on the Claude Code side needs to be configured — no hooks, no
// settings.json changes. The plugin is self-contained in this directory.

PluginComponent {
    id: root

    readonly property int pollIntervalMs: 2000
    readonly property string idleGlyph: "✳"
    readonly property string iconPath: Quickshell.env("HOME")
        + "/.config/DankMaterialShell/plugins/claudeSessions/claude-pixel.png"
    readonly property string focusScript: Quickshell.env("HOME")
        + "/.config/DankMaterialShell/plugins/claudeSessions/focus-pane.sh"
    readonly property string logPath: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/claudeSessions.log"

    // paneId (string) -> { busy: bool, name: string }
    property var paneStates: ({})
    property int pollCount: 0

    // ── Polling ──────────────────────────────────────────────
    Timer {
        interval: root.pollIntervalMs
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: listProc.running = true
    }

    Process {
        id: listProc
        command: ["bash", "-lc",
            "pid=$(pgrep -x kitty | head -n1) || exit 0; exec kitten @ --to \"unix:@mykitty-$pid\" ls"]

        stdout: StdioCollector {
            onStreamFinished: root.handleList(text)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim();
                if (msg)
                    console.warn("claudeSessions:", msg);
            }
        }
    }

    // ── Parsing / state transitions ──────────────────────────
    function cleanTitle(raw) {
        // Claude Code prefixes the pane title with a status glyph
        // (◑ while a turn is running, ✳ when idle). Strip that, plus any
        // variation selector / joiner and surrounding blanks.
        //
        // NOTE: do not use \p{L}/\p{N} here. Qt's JS engine does not
        // implement unicode property escapes — the regex compiles but
        // silently matches nothing, which is exactly how the glyph used
        // to leak into the notification title.
        const stripped = String(raw || "")
            .replace(/^[◐◑◒◓●○◎◍✳✲✱\uFE0F\u200D\s]+/u, "")
            .trim();
        return stripped || "Claude 会话";
    }

    function handleList(raw) {
        let list;
        try {
            list = JSON.parse(raw);
        } catch (e) {
            return;
        }
        if (!Array.isArray(list))
            return;

        const now = {};
        for (const osWindow of list) {
            for (const tab of (osWindow.tabs || [])) {
                for (const win of (tab.windows || [])) {
                    const procs = win.foreground_processes || [];
                    if (!procs.length)
                        continue;
                    const cmd = (procs[0].cmdline || [""])[0];
                    if (cmd !== "claude")
                        continue;
                    const title = win.title || "";
                    now[String(win.id)] = {
                        busy: title.indexOf(root.idleGlyph) !== 0,
                        name: root.cleanTitle(title)
                    };
                }
            }
        }

        const baseline = root.pollCount === 0;
        root.pollCount++;

        if (!baseline) {
            for (const id in now) {
                const prev = root.paneStates[id];
                if (prev && prev.busy && !now[id].busy)
                    root.notifyDone(id, now[id].name);
            }
        }

        root.paneStates = now;
    }

    // ── Notification ─────────────────────────────────────────
    function notifyDone(paneId, name) {
        console.info("claudeSessions: finished pane " + paneId + " (" + name + ")");
        root.log("finished pane=" + paneId + " name=" + name);
        const n = notifierComp.createObject(root, {
            paneId: paneId,
            sessionName: name
        });
        if (n)
            n.running = true;
    }

    Component {
        id: notifierComp

        Process {
            id: notifyProc
            property string paneId: ""
            property string sessionName: ""

            command: [
                "notify-send",
                "-p", // print the notification id on stdout (first line)
                "-a", "Claude Code",
                "-i", root.iconPath,
                "-u", "normal",
                "-A", "default=跳转到终端",
                "-w",
                "Claude · " + sessionName,
                "这一轮已完成"
            ]

            // stdout is "137\n" if the notification just went away, or
            // "137\ndefault\n" if the user clicked the action.
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.split("\n").map(s => s.trim()).filter(s => s.length > 0);
                    const id = /^\d+$/.test(lines[0] || "") ? lines[0] : "";
                    const action = id && lines.length > 1 ? lines[lines.length - 1] : "";
                    root.log("action=[" + action + "] id=" + id + " pane=" + notifyProc.paneId);
                    if (action === "default" || action === "0") {
                        // Belt and braces. Quickshell dismisses a
                        // non-resident notification when its action is
                        // invoked, so DMS normally drops this entry by
                        // itself. Closing it explicitly guarantees the
                        // entry cannot linger in the center's waiting list.
                        root.closeNotification(id);
                        root.focusPane(notifyProc.paneId);
                    }
                }
            }

            onExited: destroy()
        }
    }

    // ── Tell the notification server we are done with it ─────
    function closeNotification(id) {
        if (!id)
            return;
        closeProc.notifId = String(id);
        closeProc.running = true;
    }

    Process {
        id: closeProc
        property string notifId: ""

        command: ["gdbus", "call", "--session",
            "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.CloseNotification",
            notifId]

        onExited: exitCode => root.log("close id=" + notifId + " exit=" + exitCode)
    }

    // ── Focus the pane that sent the notification ────────────
    function focusPane(paneId) {
        focusProc.paneId = String(paneId);
        focusProc.running = true;
    }

    Process {
        id: focusProc
        property string paneId: ""

        command: ["bash", root.focusScript, paneId]

        stdout: StdioCollector {
            onStreamFinished: {
                const msg = text.trim();
                if (msg)
                    root.log(msg);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim();
                if (msg)
                    root.log("focus stderr: " + msg);
            }
        }

        onExited: exitCode => root.log("focus pane=" + focusProc.paneId + " exit=" + exitCode)
    }

    // ── Tiny append-only log (no Qt logging plumbing needed) ─
    Process {
        id: logProc
        property string line: ""
        environment: ({ "LINE": line, "LOGFILE": root.logPath })
        command: ["bash", "-c",
            "printf '%s  %s\\n' \"$(date +%F\\ %T)\" \"$LINE\" >> \"$LOGFILE\""]
    }

    function log(msg) {
        logProc.line = msg;
        logProc.running = true;
    }

    Component.onCompleted: console.info("claudeSessions: daemon started (poll " + pollIntervalMs + " ms)")
    Component.onDestruction: console.info("claudeSessions: daemon stopped")
}

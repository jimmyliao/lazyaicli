package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const version = "dev"

type backend struct{ name, direct, executable string }
type session struct {
	id, title, cwd string
	modified       time.Time
}

var backends = []backend{
	{"agy", "ags", "agy"},
	{"claude", "ccs", "claude"},
	{"codex", "cxs", "codex"},
}

func main() {
	if err := run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, "lazyai:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	name := filepath.Base(args[0])
	if b, ok := directBackend(name); ok {
		return runBackend(b, args[1:])
	}
	args = args[1:]
	if len(args) == 0 {
		name, err := readDefault()
		if err != nil {
			return err
		}
		b, _ := findBackend(name)
		return runBackend(b, nil)
	}
	switch args[0] {
	case "-h", "--help", "help":
		printHelp(os.Stdout)
		return nil
	case "-V", "--version":
		fmt.Printf("lazyai %s\n", version)
		return nil
	case "default":
		return defaultCommand(args[1:])
	case "list":
		return listBackends()
	case "doctor":
		return doctor()
	}
	b, ok := findBackend(args[0])
	if !ok {
		return fmt.Errorf("unknown backend or command: %s", args[0])
	}
	return runBackend(b, args[1:])
}

func printHelp(w io.Writer) {
	fmt.Fprint(w, `lazyai — browse and resume AI coding sessions

Usage:
  lazyai [backend] [query]
  lazyai default [backend]
  lazyai list
  lazyai doctor
  lazyai [options]

Backends:
  agy       Antigravity sessions (default)
  claude    Claude Code sessions
  codex     Codex sessions

Commands:
  lazyai                 Open the default backend
  lazyai agy             Open AGY session picker
  lazyai claude          Open Claude session picker
  lazyai codex           Open Codex session picker
  lazyai list            List available backends
  lazyai default         Show the default backend
  lazyai default <name>  Set the default backend
  lazyai doctor          Check installation and configuration

Session selection:
  lazyai codex -l        List Codex sessions
  lazyai claude 1        Resume the newest Claude session
  lazyai agy keyword     Resume the newest matching AGY session

Options:
  -l, --list             List sessions without resuming
  -h, --help             Show help
  -V, --version          Show version

Direct commands:
  ags                    Same as: lazyai agy
  ccs                    Same as: lazyai claude
  cxs                    Same as: lazyai codex

Examples:
  lazyai
  lazyai default codex
  lazyai claude auth
  lazyai codex -l
`)
}

func directBackend(name string) (backend, bool) {
	for _, b := range backends {
		if b.direct == name {
			return b, true
		}
	}
	return backend{}, false
}
func findBackend(name string) (backend, bool) {
	for _, b := range backends {
		if b.name == name || b.direct == name {
			return b, true
		}
	}
	return backend{}, false
}

func configPath() (string, error) {
	if p := os.Getenv("LAZYAI_CONFIG"); p != "" {
		return p, nil
	}
	d, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(d, "lazyai", "config.toml"), nil
}
func readDefault() (string, error) {
	p, err := configPath()
	if err != nil {
		return "", err
	}
	b, err := os.ReadFile(p)
	if errors.Is(err, os.ErrNotExist) {
		return "agy", nil
	}
	if err != nil {
		return "", err
	}
	for _, line := range strings.Split(string(b), "\n") {
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 && strings.TrimSpace(parts[0]) == "default" {
			v := strings.Trim(strings.TrimSpace(parts[1]), `"`)
			if _, ok := findBackend(v); ok {
				return v, nil
			}
			return "", fmt.Errorf("unknown backend in config: %s", v)
		}
	}
	return "agy", nil
}
func defaultCommand(args []string) error {
	if len(args) == 0 {
		v, err := readDefault()
		if err == nil {
			fmt.Println(v)
		}
		return err
	}
	if len(args) != 1 {
		return errors.New("usage: lazyai default [agy|claude|codex]")
	}
	b, ok := findBackend(args[0])
	if !ok {
		return fmt.Errorf("unknown backend: %s", args[0])
	}
	p, err := configPath()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(p), 0755); err != nil {
		return err
	}
	if err := os.WriteFile(p, []byte(fmt.Sprintf("default = %q\n", b.name)), 0644); err != nil {
		return err
	}
	fmt.Printf("Default backend: %s\n", b.name)
	return nil
}

func listBackends() error {
	def, err := readDefault()
	if err != nil {
		return err
	}
	for _, b := range backends {
		_, e := exec.LookPath(b.executable)
		state := "not found"
		if e == nil {
			state = "ready"
		}
		mark := " "
		if b.name == def {
			mark = "*"
		}
		fmt.Printf("%s %-7s %s\n", mark, b.name, state)
	}
	return nil
}
func doctor() error {
	fmt.Println("lazyai doctor")
	if p, err := configPath(); err == nil {
		fmt.Println("config:", p)
	}
	return listBackends()
}

func runBackend(b backend, args []string) error {
	if len(args) > 0 {
		switch args[0] {
		case "-h", "--help":
			printBackendHelp(b)
			return nil
		case "-V", "--version":
			fmt.Printf("lazyai %s (%s)\n", version, b.direct)
			return nil
		}
	}
	sessions, err := gather(b.name)
	if err != nil {
		return err
	}
	if len(sessions) == 0 {
		return fmt.Errorf("no %s sessions found", b.name)
	}
	sort.Slice(sessions, func(i, j int) bool { return sessions[i].modified.After(sessions[j].modified) })
	if len(args) > 0 && (args[0] == "-l" || args[0] == "--list" || args[0] == "list" || args[0] == "ls") {
		printSessions(sessions)
		return nil
	}
	var selected *session
	if len(args) > 0 {
		selected = matchSession(sessions, args[0])
	} else {
		selected, err = pickSession(sessions)
	}
	if err != nil {
		return err
	}
	if selected == nil {
		return errors.New("no matching session")
	}
	return resume(b, *selected)
}

func printBackendHelp(b backend) {
	fmt.Printf("Usage: %s [list|-l|SESSION_NUMBER|ID_PREFIX|KEYWORD]\n\nBrowse %s sessions and resume one with %s.\n", b.direct, b.name, b.executable)
}
func printSessions(ss []session) {
	for i := len(ss) - 1; i >= 0; i-- {
		fmt.Printf("%2d) %s\n", i+1, display(ss[i]))
	}
}
func display(s session) string {
	age := time.Since(s.modified)
	unit := fmt.Sprintf("%ds ago", int(age.Seconds()))
	if age >= 48*time.Hour {
		unit = fmt.Sprintf("%dd ago", int(age.Hours()/24))
	} else if age >= 90*time.Minute {
		unit = fmt.Sprintf("%dh ago", int(age.Hours()))
	} else if age >= 90*time.Second {
		unit = fmt.Sprintf("%dm ago", int(age.Minutes()))
	}
	home, _ := os.UserHomeDir()
	cwd := strings.Replace(s.cwd, home, "~", 1)
	return fmt.Sprintf("%8s  [%s]  %s", unit, s.title, cwd)
}
func matchSession(ss []session, q string) *session {
	if n, err := strconv.Atoi(q); err == nil {
		if n >= 1 && n <= len(ss) {
			return &ss[n-1]
		}
		return nil
	}
	q = strings.ToLower(q)
	for i := range ss {
		if strings.HasPrefix(strings.ToLower(ss[i].id), q) || strings.Contains(strings.ToLower(ss[i].title), q) {
			return &ss[i]
		}
	}
	return nil
}
func pickSession(ss []session) (*session, error) {
	printSessions(ss)
	fmt.Print("Pick # (Enter to cancel): ")
	line, err := bufio.NewReader(os.Stdin).ReadString('\n')
	if err != nil && err != io.EOF {
		return nil, err
	}
	line = strings.TrimSpace(line)
	if line == "" {
		return nil, nil
	}
	return matchSession(ss, line), nil
}
func resume(b backend, s session) error {
	if os.Getenv("LAZYAI_EMIT") == "1" {
		fmt.Printf("%s\t%s\t%s\n", b.name, s.cwd, s.id)
		return nil
	}
	if os.Getenv("LAZYAI_DRYRUN") == "1" || os.Getenv(strings.ToUpper(b.direct)+"_DRYRUN") == "1" {
		fmt.Printf("→ cd %s && %s\n", s.cwd, resumeArgs(b, s.id))
		return nil
	}
	if _, err := exec.LookPath(b.executable); err != nil {
		return fmt.Errorf("%s not found on PATH", b.executable)
	}
	if err := os.Chdir(s.cwd); err != nil {
		return fmt.Errorf("session directory: %w", err)
	}
	parts := strings.Fields(resumeArgs(b, s.id))
	cmd := exec.Command(parts[0], parts[1:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
func resumeArgs(b backend, id string) string {
	switch b.name {
	case "claude":
		return "claude --resume " + id
	case "agy":
		return "agy --conversation " + id
	default:
		return "codex resume " + id
	}
}

func gather(name string) ([]session, error) {
	switch name {
	case "claude":
		return gatherClaude()
	case "codex":
		return gatherCodex()
	case "agy":
		return gatherAgy()
	}
	return nil, nil
}
func gatherClaude() ([]session, error) {
	root := os.Getenv("CLAUDE_PROJECTS")
	if root == "" {
		h, _ := os.UserHomeDir()
		root = filepath.Join(h, ".claude", "projects")
	}
	files, _ := filepath.Glob(filepath.Join(root, "*", "*.jsonl"))
	out := []session{}
	for _, p := range files {
		info, e := os.Stat(p)
		if e != nil {
			continue
		}
		s := session{id: strings.TrimSuffix(filepath.Base(p), ".jsonl"), title: "untitled", modified: info.ModTime()}
		scanJSONL(p, func(m map[string]any) {
			if s.cwd == "" {
				if v, ok := m["cwd"].(string); ok {
					s.cwd = v
				}
			}
			if v, ok := m["customTitle"].(string); ok {
				s.title = v
			} else if s.title == "untitled" {
				if v, ok := m["aiTitle"].(string); ok {
					s.title = v
				}
			}
		})
		if s.cwd == "" {
			s.cwd = os.Getenv("HOME")
		}
		out = append(out, s)
	}
	return out, nil
}
func gatherCodex() ([]session, error) {
	root := os.Getenv("CODEX_HOME")
	if root == "" {
		h, _ := os.UserHomeDir()
		root = filepath.Join(h, ".codex")
	}
	files := []string{}
	filepath.WalkDir(filepath.Join(root, "sessions"), func(p string, d os.DirEntry, e error) error {
		if e == nil && !d.IsDir() && strings.HasSuffix(p, ".jsonl") {
			files = append(files, p)
		}
		return nil
	})
	out := []session{}
	for _, p := range files {
		info, e := os.Stat(p)
		if e != nil {
			continue
		}
		s := session{title: "untitled", modified: info.ModTime()}
		scanJSONL(p, func(m map[string]any) {
			if m["type"] == "session_meta" {
				if x, ok := m["payload"].(map[string]any); ok {
					s.id, _ = x["id"].(string)
					s.cwd, _ = x["cwd"].(string)
				}
			} else if s.title == "untitled" {
				if x, ok := m["payload"].(map[string]any); ok {
					if x["role"] == "user" {
						if c, ok := x["content"].([]any); ok {
							for _, v := range c {
								if z, ok := v.(map[string]any); ok {
									if text, ok := z["text"].(string); ok && !strings.HasPrefix(text, "<") {
										s.title = strings.TrimSpace(text)
										break
									}
								}
							}
						}
					}
				}
			}
		})
		if s.id != "" {
			out = append(out, s)
		}
	}
	return out, nil
}
func gatherAgy() ([]session, error) {
	root := os.Getenv("AGY_HOME")
	if root == "" {
		h, _ := os.UserHomeDir()
		root = filepath.Join(h, ".gemini", "antigravity-cli")
	}
	files, _ := filepath.Glob(filepath.Join(root, "conversations", "*"))
	cwdByID := map[string]string{}
	if b, e := os.ReadFile(filepath.Join(root, "cache", "last_conversations.json")); e == nil {
		var m map[string]string
		if json.Unmarshal(b, &m) == nil {
			for cwd, id := range m {
				cwdByID[id] = cwd
			}
		}
	}
	out := []session{}
	for _, p := range files {
		ext := filepath.Ext(p)
		if ext != ".db" && ext != ".pb" {
			continue
		}
		info, e := os.Stat(p)
		if e != nil || info.IsDir() {
			continue
		}
		id := strings.TrimSuffix(filepath.Base(p), ext)
		title := "conversation"
		if ext == ".db" {
			title = agySQLiteTitle(p)
		} else if b, e := os.ReadFile(p); e == nil {
			if candidate := agyUserInput(b); candidate != "" {
				title = candidate
			}
		}
		cwd := cwdByID[id]
		if cwd == "" {
			cwd = os.Getenv("HOME")
		}
		out = append(out, session{id: id, title: title, cwd: cwd, modified: info.ModTime()})
	}
	return out, nil
}
func scanJSONL(path string, fn func(map[string]any)) {
	f, e := os.Open(path)
	if e != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	buf := make([]byte, 64*1024)
	sc.Buffer(buf, 2*1024*1024)
	for sc.Scan() {
		var m map[string]any
		if json.Unmarshal(sc.Bytes(), &m) == nil {
			fn(m)
		}
	}
}

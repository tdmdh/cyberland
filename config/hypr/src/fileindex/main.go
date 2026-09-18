// fileindex: the file source for the Spotlight launcher (deck/views/LauncherView.qml).
//
// Lists files with fd, which already honours .gitignore -- without that a
// repo's build output outnumbers everything else in ~ four to one -- and
// answers queries from memory. A keystroke costs a scan of ~56k lowercase
// names instead of a 20-75ms fd run.
//
// One JSON object per line:
//
//	stdin   {"q":"notes","limit":8}   search
//	        {"recent":true,"limit":30} recently used files, newest first (q "" in reply)
//	        {"rescan":true}           relist, if the index is over a minute old
//	stdout  {"q":"notes","hits":[...]}  one reply per search, q echoed back
//
// Queries under three characters search only recently used files
// (~/.local/share/recently-used.xbel); longer ones search everything.
//
// Build: cd ~/.config/hypr/src/fileindex && go test && go build -o ../../bin/fileindex
package main

import (
	"bufio"
	"encoding/json"
	"encoding/xml"
	"math"
	"mime"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

var home = os.Getenv("HOME")

// Skipped everywhere: build output and dependency trees.
var noise = []string{".git", "node_modules", "__pycache__", ".venv", "venv", "target",
	"dist", "build", ".next", ".cache", "site-packages", "vendor"}

// Skipped at the top of ~: the Go module cache, a Wine prefix, game installs.
var skipTop = []string{"/go", "/PortProton", "/Games"}

// ~/.config is hidden but is where half the work on this box happens, so it
// is listed too, three levels deep, minus browser and Electron profiles.
var skipConfig = []string{"google-chrome", "chromium", "BraveSoftware", "Code", "discord", "Electron"}

type entry struct {
	path   string
	lname  string // lowercase base name
	lrel   string // lowercase path under ~, for "hypr/conf" style queries
	dir    bool
	depth  int
	recent time.Time // zero unless in recently-used.xbel; copied in so search skips a map lookup per entry
}

type hit struct {
	Path    string  `json:"path"`
	Name    string  `json:"name"`
	Dir     string  `json:"dir"` // parent, ~ for home
	IsDir   bool    `json:"isDir"`
	Mime    string  `json:"mime"`
	Icon    string  `json:"icon"`    // freedesktop name guessed from the mime type
	Generic string  `json:"generic"` // fallback when the theme lacks Icon
	Text    bool    `json:"text"`    // worth previewing as text
	Size    int64   `json:"size"`
	Mtime   int64   `json:"mtime"`
	Recent  bool    `json:"recent"`
	Score   float64 `json:"score"`
}

type index struct {
	mu      sync.RWMutex
	all     []entry
	recent  map[string]time.Time
	builtAt time.Time
	busy    bool
}

func mkEntry(p string, dir bool) entry {
	p = strings.TrimSuffix(p, "/")
	rel := strings.TrimPrefix(p, home+"/")
	return entry{
		path:  p,
		lname: strings.ToLower(filepath.Base(p)),
		lrel:  strings.ToLower(rel),
		dir:   dir,
		depth: strings.Count(rel, "/"),
	}
}

func excludes(names ...[]string) []string {
	var a []string
	for _, list := range names {
		for _, n := range list {
			a = append(a, "-E", n)
		}
	}
	return a
}

// list runs fd over ~ and ~/.config. A failed run just leaves its part out:
// a partial index is better than none.
func list() []entry {
	var out []entry
	run := func(base []string, typ string) {
		b, err := exec.Command("fd", append(base, "-t", typ, "-0")...).Output()
		if err != nil {
			return
		}
		for _, p := range strings.Split(string(b), "\x00") {
			if p != "" {
				out = append(out, mkEntry(p, typ == "d"))
			}
		}
	}
	homeArgs := append([]string{".", home}, excludes(noise, skipTop)...)
	confArgs := append([]string{"-H", "--max-depth", "3", ".", filepath.Join(home, ".config")}, excludes(noise, skipConfig)...)
	for _, args := range [][]string{homeArgs, confArgs} {
		run(args, "f")
		run(args, "d")
	}
	return out
}

// recents reads the freedesktop recently-used list: path -> last modified.
func recents(path string) map[string]time.Time {
	out := map[string]time.Time{}
	b, err := os.ReadFile(path)
	if err != nil {
		return out
	}
	var doc struct {
		Bookmarks []struct {
			Href     string `xml:"href,attr"`
			Modified string `xml:"modified,attr"`
		} `xml:"bookmark"`
	}
	if xml.Unmarshal(b, &doc) != nil {
		return out
	}
	for _, bm := range doc.Bookmarks {
		u, err := url.Parse(bm.Href)
		if err != nil || u.Scheme != "file" {
			continue
		}
		t, _ := time.Parse(time.RFC3339Nano, bm.Modified)
		out[u.Path] = t
	}
	return out
}

func (ix *index) rebuild() {
	all := list()
	rec := recents(filepath.Join(home, ".local/share/recently-used.xbel"))
	// Recent files outside what fd lists (/tmp, a hidden dir) still count.
	seen := make(map[string]bool, len(all))
	for _, e := range all {
		seen[e.path] = true
	}
	for p := range rec {
		if st, err := os.Stat(p); err == nil && !seen[p] {
			all = append(all, mkEntry(p, st.IsDir()))
		}
	}
	for i := range all {
		all[i].recent = rec[all[i].path]
	}
	ix.mu.Lock()
	ix.all, ix.recent, ix.builtAt, ix.busy = all, rec, time.Now(), false
	ix.mu.Unlock()
}

// maybeRebuild relists in the background if the index is older than maxAge.
// Searches keep answering from the old list meanwhile.
func (ix *index) maybeRebuild(maxAge time.Duration) {
	ix.mu.Lock()
	stale := !ix.busy && time.Since(ix.builtAt) > maxAge
	if stale {
		ix.busy = true
	}
	ix.mu.Unlock()
	if stale {
		go ix.rebuild()
	}
}

// tier mirrors match() in deck/views/rank.js; keep the two in step.
// 100 exact, 90 prefix, 75 word start, 70 initials, 50 substring,
// 20 letters in order, 0 no match. q is lowercase and trimmed.
func tier(t, q string) float64 {
	if t == "" || q == "" {
		return 0
	}
	if t == q {
		return 100
	}
	if strings.HasPrefix(t, q) {
		return 90
	}
	// Word starts and initials in one pass. It runs for every name in ~ on
	// every keystroke, so it allocates nothing: splitting into a slice of
	// words here was most of a 7ms query.
	initials, n := 0, 0 // count of initials seen, and how many matched q so far
	for i := 0; i < len(t); {
		if isSep(t[i]) {
			i++
			continue
		}
		j := i
		for j < len(t) && !isSep(t[j]) {
			j++
		}
		if strings.HasPrefix(t[i:j], q) {
			return 75
		}
		if n == initials && n < len(q) && t[i] == q[n] {
			n++
		}
		initials++
		i = j
	}
	if len(q) >= 2 && n == len(q) {
		return 70
	}
	if strings.Contains(t, q) {
		return 50
	}
	if len(q) >= 3 && inOrder(q, t) {
		return 20
	}
	return 0
}

func isSep(c byte) bool {
	return c == ' ' || c == '-' || c == '_' || c == '.' || c == ':' || c == '/'
}

func inOrder(q, t string) bool {
	i := 0
	for k := 0; k < len(t) && i < len(q); k++ {
		if t[k] == q[i] {
			i++
		}
	}
	return i == len(q)
}

// recentBonus: up to 25 points, halving every 14 days since last use.
func recentBonus(t, now time.Time) float64 {
	days := math.Max(0, now.Sub(t).Hours()/24)
	return 25 * math.Pow(0.5, days/14)
}

func (ix *index) search(q string, limit int, now time.Time) []hit {
	q = strings.ToLower(strings.TrimSpace(q))
	hits := []hit{}
	if q == "" {
		return hits
	}
	ix.mu.RLock()
	defer ix.mu.RUnlock()

	type cand struct {
		e *entry
		s float64
	}
	var cs []cand
	onlyRecent := len([]rune(q)) < 3
	for i := range ix.all {
		e := &ix.all[i]
		isRecent := !e.recent.IsZero()
		if onlyRecent && !isRecent {
			continue
		}
		s := tier(e.lname, q)
		// Letters-in-order (20) is fine over a hundred app names and noise over
		// 56k file names: "arknights" matched deep Minecraft recipe files.
		// Files need a run of the query, in the name or the path.
		if s < 40 {
			s = 0
			if strings.Contains(e.lrel, q) {
				s = 40
			}
		}
		if s == 0 {
			continue
		}
		if isRecent {
			s += recentBonus(e.recent, now)
		}
		s -= math.Min(10, float64(e.depth)) * 0.5
		cs = append(cs, cand{e, s})
	}
	sort.Slice(cs, func(a, b int) bool {
		if cs[a].s != cs[b].s {
			return cs[a].s > cs[b].s
		}
		return cs[a].e.path < cs[b].e.path
	})
	if len(cs) > limit {
		cs = cs[:limit]
	}
	for _, c := range cs {
		hits = append(hits, toHit(c.e, c.s))
	}
	return hits
}

// recentList is the Files view before anything is typed: recently used
// files, newest first.
func (ix *index) recentList(limit int) []hit {
	ix.mu.RLock()
	defer ix.mu.RUnlock()
	var es []*entry
	for i := range ix.all {
		if !ix.all[i].recent.IsZero() {
			es = append(es, &ix.all[i])
		}
	}
	sort.Slice(es, func(a, b int) bool { return es[a].recent.After(es[b].recent) })
	hits := []hit{}
	for i, e := range es {
		if i == limit {
			break
		}
		hits = append(hits, toHit(e, 0))
	}
	return hits
}

func toHit(e *entry, score float64) hit {
	h := hit{Path: e.path, Name: filepath.Base(e.path), IsDir: e.dir, Score: math.Round(score*10) / 10}
	h.Recent = !e.recent.IsZero()
	dir := filepath.Dir(e.path)
	if dir == home || strings.HasPrefix(dir, home+"/") {
		dir = "~" + strings.TrimPrefix(dir, home)
	}
	h.Dir = dir
	h.Mime, h.Icon, h.Generic, h.Text = kind(h.Name, e.dir)
	if st, err := os.Stat(e.path); err == nil {
		h.Size, h.Mtime = st.Size(), st.ModTime().Unix()
	}
	return h
}

// Extensions worth a text preview that the system mime table misses or
// files under application/*.
var textExt = map[string]bool{
	".md": true, ".txt": true, ".lua": true, ".qml": true, ".js": true, ".ts": true,
	".tsx": true, ".jsx": true, ".go": true, ".py": true, ".sh": true, ".zsh": true,
	".json": true, ".toml": true, ".yaml": true, ".yml": true, ".conf": true,
	".ini": true, ".css": true, ".html": true, ".rs": true, ".c": true, ".h": true,
	".cpp": true, ".nix": true, ".sql": true, ".csv": true, ".log": true, ".xml": true,
}

func kind(name string, dir bool) (mimeType, icon, generic string, text bool) {
	if dir {
		return "inode/directory", "folder", "folder", false
	}
	ext := strings.ToLower(filepath.Ext(name))
	mimeType, _, _ = strings.Cut(mime.TypeByExtension(ext), ";")
	major, _, _ := strings.Cut(mimeType, "/")
	text = major == "text" || textExt[ext]
	switch {
	case major == "image":
		generic = "image-x-generic"
	case major == "audio":
		generic = "audio-x-generic"
	case major == "video":
		generic = "video-x-generic"
	case text:
		generic = "text-x-generic"
	case strings.Contains(mimeType, "zip") || strings.Contains(mimeType, "tar") || strings.Contains(mimeType, "compress"):
		generic = "package-x-generic"
	default:
		generic = "unknown"
	}
	icon = generic
	if mimeType != "" {
		icon = strings.ReplaceAll(mimeType, "/", "-")
	}
	return
}

func main() {
	ix := &index{}
	ix.rebuild() // ~30ms; the first query waits for it rather than seeing nothing

	in := bufio.NewScanner(os.Stdin)
	in.Buffer(make([]byte, 64*1024), 1024*1024)
	out := json.NewEncoder(os.Stdout) // unbuffered: each reply is flushed as written
	for in.Scan() {
		var req struct {
			Q      string `json:"q"`
			Limit  int    `json:"limit"`
			Rescan bool   `json:"rescan"`
			Recent bool   `json:"recent"`
		}
		if json.Unmarshal(in.Bytes(), &req) != nil {
			continue
		}
		if req.Rescan {
			ix.maybeRebuild(time.Minute)
			continue
		}
		if req.Limit <= 0 || req.Limit > 50 {
			req.Limit = 8
		}
		hits := ix.search(req.Q, req.Limit, time.Now())
		if req.Recent {
			hits = ix.recentList(req.Limit)
		}
		out.Encode(struct {
			Q    string `json:"q"`
			Hits []hit  `json:"hits"`
		}{req.Q, hits})
	}
}

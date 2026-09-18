package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

// The same cases as deck/selftest.sh checks against rank.js, so the two
// rankers cannot drift apart silently.
func TestTier(t *testing.T) {
	for _, c := range []struct {
		text, q string
		want    float64
	}{
		{"firefox", "firefox", 100},
		{"firefox", "fir", 90},
		{"advanced network configuration", "net", 75},
		{"visual studio code", "vsc", 70},
		{"advanced network configuration", "fig", 50},
		{"thunderbird", "tbd", 20},
		{"firefox", "xyz", 0},
		{"", "a", 0},
		{"binds.lua", "lua", 75}, // extension is a word
	} {
		if got := tier(c.text, c.q); got != c.want {
			t.Errorf("tier(%q, %q) = %v, want %v", c.text, c.q, got, c.want)
		}
	}
}

func testIndex(now time.Time) *index {
	ix := &index{recent: map[string]time.Time{}}
	for _, p := range []string{
		home + "/.config/hypr/conf/binds.lua",
		home + "/notes/binder-notes.md",
		home + "/Documents/deep/a/b/c/d/binds.lua",
		home + "/Pictures/wall.png",
	} {
		ix.all = append(ix.all, mkEntry(p, false))
	}
	ix.recent[home+"/Pictures/wall.png"] = now.Add(-24 * time.Hour)
	for i := range ix.all {
		ix.all[i].recent = ix.recent[ix.all[i].path]
	}
	return ix
}

func TestSearch(t *testing.T) {
	now := time.Date(2026, 9, 18, 12, 0, 0, 0, time.UTC)
	ix := testIndex(now)

	got := ix.search("binds", 8, now)
	if len(got) < 2 || got[0].Path != home+"/.config/hypr/conf/binds.lua" {
		t.Fatalf("binds: shallow binds.lua should lead, got %+v", got)
	}
	if got[0].Dir != "~/.config/hypr/conf" || !got[0].Text {
		t.Errorf("binds: dir %q text %v", got[0].Dir, got[0].Text)
	}

	// Short queries only search recent files.
	if got := ix.search("wa", 8, now); len(got) != 1 || got[0].Name != "wall.png" || !got[0].Recent {
		t.Errorf("wa: want only the recent wall.png, got %+v", got)
	}
	if got := ix.search("bi", 8, now); len(got) != 0 {
		t.Errorf("bi: non-recent files must wait for 3 chars, got %+v", got)
	}

	// A path fragment finds files by folder.
	if got := ix.search("hypr/conf", 8, now); len(got) != 1 || got[0].Name != "binds.lua" {
		t.Errorf("hypr/conf: got %+v", got)
	}

	// Letters in order ("bnl" in binds.lua) rank apps, never files.
	if got := ix.search("bnl", 8, now); len(got) != 0 {
		t.Errorf("bnl: in-order matches must not surface files, got %+v", got)
	}

	if got := ix.search("binds", 1, now); len(got) != 1 {
		t.Errorf("limit ignored: %d hits", len(got))
	}
	if got := ix.search("   ", 8, now); got == nil || len(got) != 0 {
		t.Errorf("blank query should give an empty, non-nil list")
	}
}

func TestRecentList(t *testing.T) {
	now := time.Date(2026, 9, 18, 12, 0, 0, 0, time.UTC)
	ix := testIndex(now)
	older := home + "/.config/hypr/conf/binds.lua"
	ix.recent[older] = now.Add(-72 * time.Hour)
	for i := range ix.all {
		ix.all[i].recent = ix.recent[ix.all[i].path]
	}
	got := ix.recentList(8)
	if len(got) != 2 || got[0].Name != "wall.png" || got[1].Path != older {
		t.Fatalf("want wall.png then the older binds.lua, got %+v", got)
	}
	if got := ix.recentList(1); len(got) != 1 {
		t.Errorf("limit ignored: %d", len(got))
	}
}

func TestRecents(t *testing.T) {
	p := filepath.Join(t.TempDir(), "recently-used.xbel")
	os.WriteFile(p, []byte(`<?xml version="1.0"?>
<xbel version="1.0">
  <bookmark href="file:///home/x/My%20Notes.md" modified="2026-09-01T10:00:00.5Z"/>
  <bookmark href="https://example.com/" modified="2026-09-01T10:00:00Z"/>
</xbel>`), 0o600)
	r := recents(p)
	if len(r) != 1 {
		t.Fatalf("want 1 file bookmark, got %v", r)
	}
	if ts, ok := r["/home/x/My Notes.md"]; !ok || ts.Day() != 1 {
		t.Errorf("percent-decoding or time parse failed: %v", r)
	}
	if len(recents(filepath.Join(t.TempDir(), "missing"))) != 0 {
		t.Error("missing file should give an empty map")
	}
}

func TestKind(t *testing.T) {
	if m, icon, gen, text := kind("x.png", false); m != "image/png" || icon != "image-png" || gen != "image-x-generic" || text {
		t.Errorf("png: %s %s %s %v", m, icon, gen, text)
	}
	if _, _, gen, text := kind("binds.lua", false); gen != "text-x-generic" || !text {
		t.Errorf("lua: %s %v", gen, text)
	}
	if m, icon, _, _ := kind("conf", true); m != "inode/directory" || icon != "folder" {
		t.Errorf("dir: %s %s", m, icon)
	}
}

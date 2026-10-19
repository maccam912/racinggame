package names

import (
	"bytes"
	"os"
	"strings"
	"testing"
)

func TestCanonicalAndGraphemeNames(t *testing.T) {
	for input, want := range map[string]string{"Cafe\u0301": "Café", "A\u030a": "Å", "\u1100\u1161\u11a8": "각", "é": "é"} {
		if got := NFC(input); got != want {
			t.Fatalf("NFC %q = %q, want %q", input, got, want)
		}
	}
	for _, value := range []string{"👨‍👩‍👧‍👦ab", "Driver0742", "Café", "नमस्तेab"} {
		if _, err := Validate(value, 16); err != nil {
			t.Fatalf("valid name %q rejected", value)
		}
	}
	for _, value := range []string{"ab", "<color>", "A\nB", strings.Repeat("👨‍👩‍👧‍👦", 4), "A\u202eB"} {
		if _, err := Validate(value, 16); err == nil {
			t.Fatalf("invalid name %q accepted", value)
		}
	}
	long := "a" + strings.Repeat("\u0301", 31) + "bc"
	if strings.ContainsRune(NFC(long), '\u034f') {
		t.Fatal("normalization inserted a joiner")
	}
}

func TestNormalizationTablesMatchTheGame(t *testing.T) {
	source, err := os.ReadFile("../../../../game/content/unicode_nfc.json")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(bytes.TrimSpace(source), bytes.TrimSpace(tableJSON)) {
		t.Fatal("Go and Godot normalization tables drifted; regenerate with tools/generate_unicode.py")
	}
}

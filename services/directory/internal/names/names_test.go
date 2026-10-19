package names

import (
	"bytes"
	"encoding/json"
	"os"
	"reflect"
	"strings"
	"testing"
	"unicode/utf8"

	"github.com/clipperhouse/uax29/v2/graphemes"
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

func TestUnicode16OfficialGraphemeBoundariesMatchGameContract(t *testing.T) {
	data, err := os.ReadFile("../../../../tests/fixtures/grapheme_break_16.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		Version string `json:"unicode_version"`
		Cases   []struct {
			Points []rune `json:"points"`
			Breaks []int  `json:"breaks"`
		} `json:"cases"`
	}
	if err := json.Unmarshal(data, &fixture); err != nil || fixture.Version != "16.0.0" || len(fixture.Cases) != 1093 {
		t.Fatalf("invalid Unicode conformance fixture: %v", err)
	}
	for index, test := range fixture.Cases {
		iterator := graphemes.FromString(string(test.Points))
		got, position := []int{0}, 0
		for iterator.Next() {
			position += utf8.RuneCountInString(iterator.Value())
			got = append(got, position)
		}
		if !reflect.DeepEqual(got, test.Breaks) {
			t.Fatalf("Unicode 16 case %d: boundaries %v, want %v", index, got, test.Breaks)
		}
	}
	if _, err := Validate(strings.Repeat("👨‍👩‍👧‍👦", 3)+"aa", 16); err != nil {
		t.Fatal("the eight-player Android regression name must match directory validation")
	}
}

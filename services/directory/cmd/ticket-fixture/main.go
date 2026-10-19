package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"github.com/maccam912/racinggame/services/directory/internal/directory"
	"os"
)

func main() {
	output := flag.String("output", "../../reports/ticket-fixture.json", "test fixture output")
	compat := flag.String("compatibility", "../../game/content/compatibility.json", "content definition")
	rules := flag.String("rules", "../../game/content/rules.json", "protocol definition")
	flag.Parse()
	var content struct {
		Hash string `json:"content_hash"`
	}
	var versions struct {
		Protocol int `json:"protocol_version"`
	}
	a, err := os.ReadFile(*compat)
	if err == nil {
		err = json.Unmarshal(a, &content)
	}
	if err == nil {
		a, err = os.ReadFile(*rules)
	}
	if err == nil {
		err = json.Unmarshal(a, &versions)
	}
	if err == nil {
		err = directory.WriteTicketFixture(*output, content.Hash, versions.Protocol)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

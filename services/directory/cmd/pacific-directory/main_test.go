package main

import (
	"encoding/base64"
	"encoding/json"
	"io"
	"os"
	"runtime"
	"testing"
)

func TestVersionReportsRuntimeAndEmbeddedIdentityWithoutKeys(t *testing.T) {
	oldArgs, oldOutput, oldIdentity := os.Args, os.Stdout, buildIdentityB64
	defer func() { os.Args, os.Stdout, buildIdentityB64 = oldArgs, oldOutput, oldIdentity }()
	for _, embedded := range []string{"", base64.RawURLEncoding.EncodeToString([]byte(`{"build_number":80,"commit":"test-commit","service_schema":99,"go_version":"wrong"}`))} {
		reader, writer, err := os.Pipe()
		if err != nil {
			t.Fatal(err)
		}
		os.Args = []string{"pacific-directory", "version"}
		os.Stdout = writer
		buildIdentityB64 = embedded
		err = run()
		writer.Close()
		os.Stdout = oldOutput
		data, readErr := io.ReadAll(reader)
		reader.Close()
		if err != nil || readErr != nil {
			t.Fatal(err, readErr)
		}
		var value map[string]any
		if err = json.Unmarshal(data, &value); err != nil {
			t.Fatal(err)
		}
		if value["go_version"] != runtime.Version() || value["service_schema"] != float64(3) {
			t.Fatal("runtime identity was replaced", value)
		}
		if embedded != "" && (value["commit"] != "test-commit" || value["build_number"] != float64(80)) {
			t.Fatal("embedded public identity lost", value)
		}
	}
	for _, invalid := range []string{"!", base64.RawURLEncoding.EncodeToString([]byte("null")), base64.RawURLEncoding.EncodeToString([]byte("[]"))} {
		buildIdentityB64 = invalid
		if err := run(); err == nil {
			t.Fatal("accepted invalid embedded identity")
		}
	}
	buildIdentityB64 = ""
	os.Args = []string{"pacific-directory", "version", "unexpected"}
	if err := run(); err == nil {
		t.Fatal("version silently ignored arguments")
	}
}

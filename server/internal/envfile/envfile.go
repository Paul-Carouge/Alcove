// Package envfile loads KEY=VALUE configuration files written by the installer.
package envfile

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Flag is the command-line flag pointing to the file.
const Flag = "--env-file"

// Take removes "--env-file=PATH" (or "--env-file PATH") from args and returns
// the path and the remaining arguments.
func Take(args []string) (string, []string) {
	var out []string
	path := ""
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch {
		case strings.HasPrefix(a, Flag+"="):
			path = strings.TrimPrefix(a, Flag+"=")
		case a == Flag && i+1 < len(args):
			path = args[i+1]
			i++
		default:
			out = append(out, a)
		}
	}
	return path, out
}

// Load sets variables from the file; variables already in the environment win.
// Lines are KEY=VALUE; blank lines and lines starting with # are ignored;
// values may be wrapped in single or double quotes.
func Load(path string) error {
	f, err := os.Open(path) // #nosec G304 -- path chosen by the administrator
	if err != nil {
		return err
	}
	defer func() { _ = f.Close() }()
	sc := bufio.NewScanner(f)
	for n := 1; sc.Scan(); n++ {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		key = strings.TrimSpace(key)
		if !ok || key == "" || strings.ContainsAny(key, " \t") {
			return fmt.Errorf("%s:%d: expected KEY=VALUE", path, n)
		}
		value = strings.TrimSpace(value)
		if len(value) >= 2 && value[0] == '"' && value[len(value)-1] == '"' {
			unq, err := strconv.Unquote(value) // Write uses Go quoting
			if err != nil {
				return fmt.Errorf("%s:%d: bad quoted value", path, n)
			}
			value = unq
		} else if len(value) >= 2 && value[0] == '\'' && value[len(value)-1] == '\'' {
			value = value[1 : len(value)-1]
		}
		if _, exists := os.LookupEnv(key); !exists {
			if err := os.Setenv(key, value); err != nil {
				return err
			}
		}
	}
	return sc.Err()
}

// Write saves vars as a 0600 KEY="VALUE" file (it holds secrets).
func Write(path string, header string, vars [][2]string) error {
	var b strings.Builder
	for _, l := range strings.Split(strings.TrimSpace(header), "\n") {
		b.WriteString("# " + l + "\n")
	}
	b.WriteString("\n")
	for _, kv := range vars {
		fmt.Fprintf(&b, "%s=%q\n", kv[0], kv[1])
	}
	return os.WriteFile(path, []byte(b.String()), 0o600)
}
